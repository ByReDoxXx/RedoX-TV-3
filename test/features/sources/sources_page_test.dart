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

import '../../support/render.dart';

/// Sunucu açmayan alıcı: QR'da sabit adres.
class _FakeReceiver extends SourceReceiver {
  _FakeReceiver(super.sources);

  @override
  Future<String?> start({String? host}) async => 'http://192.168.1.20:41234/?t=ornekanahtar';

  @override
  Future<void> stop() async {}
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

Widget _app(FormFactor f, UserSources s, {GlobalKey? boundary}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: SourcesPage(sources: s, clock: '20:45', profileName: 'Profil 1', receiver: _FakeReceiver(s)),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('TV: klasörler ve ekleme paneli (QR) taşmasız', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Spor listem'), findsOneWidget);
    expect(find.text('5 kanal · Telefon'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Telefonla ekle'), findsOneWidget);
  });

  testWidgets('TV: adresle ekle penceresi uygulamanın klavyesiyle; adres alanında semboller', (tester) async {
    await _size(tester, const Size(960, 540));
    final s = await _sources(tester, empty: true);
    await tester.pumpWidget(_app(FormFactor.tv, s));
    await _settle(tester);
    expect(find.textContaining('Henüz liste yok'), findsOneWidget);
    await tester.tap(find.text('Adresle'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TvKeyboard), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('https://'));
    await tester.tap(find.bySemanticsLabel('a'));
    await tester.tap(find.bySemanticsLabel('.m3u'));
    await tester.pump();
    expect(find.text('https://a.m3u|'), findsOneWidget, reason: 'adreste kendiliğinden büyük harf yok');
  });

  testWidgets('telefon: QR yok, klasörler alt alta', (tester) async {
    await _size(tester, const Size(390, 844));
    final s = await _sources(tester);
    await tester.pumpWidget(_app(FormFactor.phone, s));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Çocuk ve Aile'), findsOneWidget);
  });

  testWidgets('görüntüler: TV, telefon, adres penceresi', (tester) async {
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
        await tester.tap(find.text('Adresle'));
        await _settle(tester);
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/kaynaklar/$name-2-adres.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
