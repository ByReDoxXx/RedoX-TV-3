import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/channel_folder.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/sources/source_channels_page.dart';

import '../../support/render.dart';

const _m3u = '''#EXTM3U
#EXTINF:-1 group-title="Dizi İsmi/1.Sezon",Bölüm01
http://ornek/d11.m3u8
#EXTINF:-1 group-title="Dizi İsmi/1.Sezon",Bölüm02
http://ornek/d12.m3u8
#EXTINF:-1 group-title="Dizi İsmi/2.Sezon",Bölüm01
http://ornek/d21.m3u8
#EXTINF:-1,Film A
http://ornek/fa.m3u8
''';

Future<(UserSources, UserSource)> _source(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-kaynak-ic-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  final src = await s.addText('Dizilerim', _m3u, origin: SourceOrigin.file);
  return (s, src);
}))!;

Finder _label(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  test('ChannelFolder.build: grup ve "/" iç içe klasör; kayıt adı son parça, akışlar korunur', () {
    final tree = ChannelFolder.build(const [
      LiveChannel(name: 'Bölüm01', number: 1, category: 'Dizi/1.Sezon', streams: ['a', 'b']),
      LiveChannel(name: 'Dizi/2.Sezon/Bölüm01', number: 2, category: 'Diğer', streams: ['c']),
      LiveChannel(name: 'Film', number: 3, category: 'Diğer', streams: ['d']),
    ]);
    expect(tree.items.map((c) => c.name), ['Film']);
    expect(tree.at(['Dizi'])!.folders.map((f) => f.name), ['1.Sezon', '2.Sezon']);
    expect(tree.at(['Dizi', '1.Sezon'])!.items.single.streams, ['a', 'b']);
    expect(tree.at(['Dizi', '2.Sezon'])!.items.single.name, 'Bölüm01');
    expect(tree.total, 3);
    expect(tree.at(['Yok']), isNull);
  });

  for (final (f, size) in const [(FormFactor.tv, Size(960, 540)), (FormFactor.phone, Size(390, 844))]) {
    testWidgets(
      '${f.name}: klasör görünümünde iç içe gezinir, kayıt klasörün listesiyle açılır, Yukarı ve Geri döner',
      (tester) async {
        await _size(tester, size);
        final (sources, src) = await _source(tester);
        (List<LiveChannel>, int)? watched;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: RedoxTheme.dark(formFactor: f),
              home: SourceChannelsPage(sources: sources, source: src, onWatch: (l, i) async => watched = (l, i)),
            ),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Dizi İsmi'), findsOneWidget);
        expect(find.text('Film A'), findsOneWidget);

        await tester.tap(find.text('Dizi İsmi'));
        await tester.pump();
        await tester.tap(find.text('1.Sezon'));
        await tester.pump();
        expect(find.text('Dizilerim › Dizi İsmi › 1.Sezon'), findsOneWidget);
        await maybeSnapshot(tester, key, 'build/kaynaklar/klasor-${f.name}.png', pixelRatio: 2);
        await tester.tap(find.text('Bölüm02'));
        expect(watched!.$2, 1);
        expect([for (final c in watched!.$1) c.streams.single], ['http://ornek/d11.m3u8', 'http://ornek/d12.m3u8']);

        await tester.tap(find.text('Yukarı'));
        await tester.pump();
        expect(find.text('2.Sezon'), findsOneWidget);
        // Geri bir üst klasöre çıkar, sayfa kapanmaz.
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Dizi İsmi'), findsOneWidget);
        expect(find.byType(SourceChannelsPage), findsOneWidget);
      },
    );
  }

  testWidgets('liste görünümü düz liste; yıldız Favoriler › Kaynaklar\'a ekler ve çıkarır', (tester) async {
    await _size(tester, const Size(960, 540));
    final (sources, src) = await _source(tester);
    final fav = Favorites();
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: SourceChannelsPage(sources: sources, source: src, favorites: fav),
      ),
    );
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Liste görünümü'));
    await tester.pump();
    expect(find.text('Dizi İsmi'), findsNothing);
    expect(find.text('Film A'), findsOneWidget);
    await tester.tap(_label('Favorilere ekle').last);
    await tester.pump();
    expect(fav.sources.map((i) => (i.name, i.url)), [('Film A', 'http://ornek/fa.m3u8')]);
    expect(_label('Favorilerden çıkar'), findsOneWidget);
    await tester.tap(_label('Favorilerden çıkar'));
    await tester.pump();
    expect(fav.sources, isEmpty);
  });
}
