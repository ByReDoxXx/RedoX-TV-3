import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:redox_tv/core/content/source_receiver.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/tv_keyboard.dart';
import 'package:redox_tv/features/sources/sources_page.dart';
import 'package:redox_tv/features/sources/widgets/phone_qr_dialog.dart';

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

Widget _app(FormFactor f, UserSources s, {GlobalKey? boundary, SourceReceiver? receiver}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: SourcesPage(sources: s, clock: '20:45', profileName: 'Profil 1', receiver: receiver ?? _FakeReceiver(s)),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('TV: ekleme yöntemleri ve klasörler taşmasız; QR sayfada değil', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    for (final m in AddMethod.values) {
      expect(find.text(m.title), findsOneWidget, reason: m.title);
    }
    expect(find.text('Spor listem'), findsOneWidget);
    expect(find.text('4 liste · 250 kanal'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('Telefondan: QR penceresi açılır, kapanınca sunucu durur', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    final receiver = _FakeReceiver(s);
    await tester.pumpWidget(_app(FormFactor.tv, s, receiver: receiver));
    await _settle(tester);
    await tester.tap(find.text(AddMethod.phone.title));
    await _settle(tester);
    expect(find.byType(PhoneQrDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kapat'));
    await _settle(tester);
    expect(receiver.stopped, isTrue);
  });

  testWidgets('Xtream formu: uygulamanın klavyesi, şifre noktalı; Ekle zorunlu alanlar dolunca', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    await tester.tap(find.text(AddMethod.xtream.title));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TvKeyboard), findsOneWidget);

    await tester.tap(find.text('Şifre'));
    await tester.pump();
    for (final k in ['a', 'b', 'c']) {
      await tester.tap(find.bySemanticsLabel(k));
    }
    await tester.pump();
    expect(find.text('•••|'), findsOneWidget);
  });

  testWidgets('MediaHub: biçim eklenene kadar açıklama', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
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
        await maybeSnapshot(tester, key, 'build/kaynaklar/$name-1.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        for (final (m, file) in [(AddMethod.xtream, '2-xtream'), (AddMethod.portal, '3-portal')]) {
          await tester.tap(find.text(m.title));
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/kaynaklar/$name-$file.png', pixelRatio: 2);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Vazgeç'));
          await _settle(tester);
        }
        if (f == FormFactor.tv) {
          await tester.tap(find.text(AddMethod.phone.title));
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/kaynaklar/$name-4-qr.png', pixelRatio: 2);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
