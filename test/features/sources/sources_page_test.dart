import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:redox_tv/core/content/source_receiver.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/platform/system_text_input.dart';
import 'package:redox_tv/features/settings/settings_page.dart';
import 'package:redox_tv/features/sources/add_source_tab.dart';
import 'package:redox_tv/features/sources/sources_page.dart';
import 'package:redox_tv/features/sources/widgets/phone_qr_dialog.dart';
import 'package:redox_tv/features/sources/widgets/source_form_dialog.dart';

import '../../support/render.dart';

/// Sunucu açmayan alıcı: QR'da sabit adres.
class _FakeReceiver extends SourceReceiver {
  _FakeReceiver(super.sources);

  bool stopped = false;

  @override
  Future<String?> start({String? host}) async => 'http://192.168.1.20:41234/?t=ornekanahtar';

  @override
  Future<void> stop() async => stopped = true;
}

String _m3u(int n) => [
  '#EXTM3U',
  for (var i = 1; i <= n; i++) ...['#EXTINF:-1 tvg-chno="$i" group-title="Spor",Kanal $i', 'http://ornek/$i.m3u8'],
].join('\n');

Future<UserSources> _sources(WidgetTester tester, {bool empty = false}) async {
  final s = (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('redox-kaynak-');
    addTearDown(() => dir.delete(recursive: true));
    final s = await UserSources.open(dir);
    if (!empty) {
      await s.addText('Spor listem', _m3u(3), origin: SourceOrigin.url, url: 'http://ornek/spor.m3u');
      await s.addText('Çocuk ve Aile', _m3u(2), origin: SourceOrigin.file);
      await s.addText('Telefon listesi', _m3u(5), origin: SourceOrigin.phone);
      await s.addText('Xtream hesabım', _m3u(240), origin: SourceOrigin.xtream);
    }
    return s;
  }))!;
  return s;
}

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Ayarlar > Kaynak ekle (ekleme yöntemleri).
Widget _app(FormFactor f, UserSources s, {GlobalKey? boundary, SourceReceiver? receiver}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: SettingsPage(
        sources: s,
        clock: '20:45',
        profileName: 'Profil 1',
        receiver: receiver ?? _FakeReceiver(s),
        initialSection: SettingsSection.addSource,
      ),
    ),
  ),
);

/// Kaynaklar bölümü (eklenen listeler).
Widget _list(FormFactor f, UserSources s, {GlobalKey? boundary, VoidCallback? onAdd}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: SourcesPage(sources: s, clock: '20:45', profileName: 'Profil 1', onAdd: onAdd ?? () {}),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('Ayarlar > Kaynak ekle: ekleme yöntemleri taşmasız; QR sayfada değil, klasörler burada değil', (
    tester,
  ) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text(SettingsSection.addSource.label), findsOneWidget);
    for (final m in AddMethod.values) {
      expect(find.text(m.title), findsOneWidget, reason: m.title);
    }
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Spor listem'), findsNothing);
  });

  testWidgets("Kaynaklar: klasörler ve toplam; 'Kaynak ekle' Ayarlar'a götürür; boşken yönerge", (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester);
    var asked = 0;
    await tester.pumpWidget(_list(FormFactor.tv, s, onAdd: () => asked++));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Spor listem'), findsOneWidget);
    expect(find.text('4 liste · 250 kayıt'), findsOneWidget);
    expect(find.text(AddMethod.xtream.title), findsNothing);
    await tester.tap(find.text('Kaynak ekle'));
    expect(asked, 1);

    final empty = await _sources(tester, empty: true);
    await tester.pumpWidget(_list(FormFactor.tv, empty));
    await _settle(tester);
    expect(find.textContaining('Ayarlar > Kaynak ekle'), findsOneWidget);
  });

  testWidgets('Telefondan: QR penceresi açılır, kapanınca sunucu durur', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    final receiver = _FakeReceiver(s);
    await tester.pumpWidget(_app(FormFactor.tv, s, receiver: receiver));
    await _settle(tester);
    await tester.ensureVisible(find.text(AddMethod.phone.title));
    await tester.tap(find.text(AddMethod.phone.title));
    await _settle(tester);
    expect(find.byType(PhoneQrDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kapat'));
    await _settle(tester);
    expect(receiver.stopped, isTrue);
  });

  testWidgets('Xtream formu (TV): alan OK ile sistem klavyesini açar; şifre noktalı görünür', (tester) async {
    await _size(tester, const Size(960, 540));
    final asked = <(String, TextKind)>[];
    SystemTextInput.debugOverride = (title, value, kind) async {
      asked.add((title, kind));
      return 'abc';
    };
    addTearDown(() => SystemTextInput.debugOverride = null);
    final s = await _sources(tester, empty: true);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    await tester.tap(find.text(AddMethod.xtream.title));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing, reason: 'TV: Flutter metin alanı yok');

    await tester.tap(find.text('Şifre'));
    await tester.pump();
    expect(asked.single, ('Şifre', TextKind.secret));
    expect(find.text('•••'), findsOneWidget);
    await tester.tap(find.text('Sunucu'));
    await tester.pump();
    expect(asked.last.$2, TextKind.url);
  });

  testWidgets('form (telefon): adres alanında otomatik düzeltme yok; klavyenin eklediği boşluklar silinir', (
    tester,
  ) async {
    await _size(tester, const Size(390, 844));
    Map<String, String>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.phone),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showSourceForm(
              context,
              title: 'M3U',
              description: 'Adres',
              fields: const [
                FormFieldSpec('url', 'Adres', kind: FieldKind.url),
                FormFieldSpec('mac', 'MAC', kind: FieldKind.mac),
                FormFieldSpec('name', 'Ad', required: false),
              ],
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await _settle(tester);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect([for (final f in fields) f.autocorrect], [false, false, true]);
    expect([for (final f in fields) f.enableSuggestions], [false, false, true]);

    await tester.enterText(find.byType(TextField).at(0), 'https://iptv-org.github. io/iptv/tr. m3u ');
    await tester.enterText(find.byType(TextField).at(1), '00:1a:79 :12:34:56');
    await tester.enterText(find.byType(TextField).at(2), ' Spor listem ');
    await tester.tap(find.text('Ekle'));
    await _settle(tester);
    expect(result, {
      'url': 'https://iptv-org.github.io/iptv/tr.m3u',
      'mac': '00:1A:79:12:34:56',
      'name': 'Spor listem',
    });
  });

  testWidgets('MediaHub: biçim eklenene kadar açıklama', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    await tester.ensureVisible(find.text(AddMethod.mediaHub.title));
    await tester.tap(find.text(AddMethod.mediaHub.title));
    await _settle(tester);
    expect(find.textContaining('henüz eklenmedi'), findsOneWidget);
  });

  testWidgets('telefon: "Telefondan" kutusu yok', (tester) async {
    await _size(tester, const Size(390, 844));
    final s = await _sources(tester);
    await tester.pumpWidget(_app(FormFactor.phone, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(AddMethod.phone.title), findsNothing);
    await tester.pumpWidget(_list(FormFactor.phone, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Çocuk ve Aile'), findsOneWidget);
  });

  testWidgets('görüntüler: TV, telefon, formlar, QR', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
      ]) {
        await _size(tester, size);
        final s = await _sources(tester);
        final key = GlobalKey();
        await tester.pumpWidget(_app(f, s, boundary: key));
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/kaynaklar/$name-1-ekle.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        for (final (m, file) in [(AddMethod.xtream, '2-xtream'), (AddMethod.portal, '3-portal')]) {
          await tester.ensureVisible(find.text(m.title));
          await tester.tap(find.text(m.title));
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/kaynaklar/$name-$file.png', pixelRatio: 2);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Vazgeç'));
          await _settle(tester);
        }
        if (f == FormFactor.tv) {
          await tester.ensureVisible(find.text(AddMethod.phone.title));
          await tester.tap(find.text(AddMethod.phone.title));
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/kaynaklar/$name-4-qr.png', pixelRatio: 2);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Kapat'));
          await _settle(tester);
        }
        await tester.pumpWidget(_list(f, s, boundary: key));
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/kaynaklar/$name-0-listeler.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
