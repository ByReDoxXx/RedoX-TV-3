import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/channel_folder.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/media_card.dart';
import 'package:redox_tv/features/library/library_page.dart';
import 'package:redox_tv/features/sources/sources_page.dart';

import '../../support/render.dart';

const _films = '''#EXTM3U
#EXTINF:-1 tvg-logo="http://ornek/a.jpg" group-title="Aksiyon",Film A
http://ornek/fa.mp4
#EXTINF:-1 group-title="Komedi",Film B
http://ornek/fb.mp4
''';

const _series = '''#EXTM3U
#EXTINF:-1 group-title="Diziler",Kuzey Güney S01E01
http://ornek/kg11.mp4
#EXTINF:-1 group-title="Diziler",Kuzey Güney S01E02
http://ornek/kg12.mp4
#EXTINF:-1 group-title="Diziler",Kuzey Güney S02E01
http://ornek/kg21.mp4
''';

const _live = '''#EXTM3U
#EXTINF:-1 tvg-chno="1",Canlı Kanal
http://ornek/c.m3u8
''';

Future<UserSources> _sources(WidgetTester tester, {bool empty = false}) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-kutuphane-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  if (!empty) {
    await s.addText('Filmlerim', _films, origin: SourceOrigin.file, kind: SourceKind.film);
    await s.addText('Dizilerim', _series, origin: SourceOrigin.file, kind: SourceKind.series);
    await s.addText('Canlı', _live, origin: SourceOrigin.file);
  }
  return s;
}))!;

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

Widget _app(FormFactor f, Widget page) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: f),
  home: Scaffold(body: page),
);

void main() {
  test('episodePath: S01E02 ve "1. Sezon 2. Bölüm"; yoksa null', () {
    expect(ChannelFolder.episodePath('Kuzey Güney S01E02'), ['Kuzey Güney', 'Sezon 1', 'Bölüm 2']);
    expect(ChannelFolder.episodePath('Kuzey.Guney.s2e10 - Final'), ['Kuzey.Guney', 'Sezon 2', 'Bölüm 10 Final']);
    expect(ChannelFolder.episodePath('Ezel 1. Sezon 3. Bölüm'), ['Ezel', 'Sezon 1', 'Bölüm 3']);
    expect(ChannelFolder.episodePath('Film A'), isNull);
    expect(ChannelFolder.episodePath('S01E01'), isNull);
  });

  test('kaynak türü kaydedilir; eski kayıt canlı sayılır', () {
    final s = UserSource(
      id: 'x',
      name: 'X',
      origin: SourceOrigin.file,
      count: 1,
      updated: DateTime(2026),
      kind: SourceKind.series,
    );
    expect(UserSource.fromJson(s.toJson()).kind, SourceKind.series);
    expect(UserSource.fromJson({...s.toJson()}..remove('kind')).kind, SourceKind.live);
  });

  for (final (f, size) in const [(FormFactor.tv, Size(960, 540)), (FormFactor.phone, Size(390, 844))]) {
    testWidgets('${f.name}: Film afiş ızgarası, kategori çipi süzer, film kategori listesiyle açılır', (tester) async {
      await _size(tester, size);
      final sources = await _sources(tester);
      (List<LiveChannel>, int)? watched;
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: _app(
            f,
            LibraryPage(
              kind: SourceKind.film,
              sources: sources,
              clock: '20:45',
              profileName: 'Profil 1',
              onWatch: (l, i) async => watched = (l, i),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(MediaCard), findsNWidgets(2));
      expect(find.text('Canlı Kanal'), findsNothing);
      await maybeSnapshot(tester, key, 'build/kutuphane/film-${f.name}.png', pixelRatio: 2);
      await tester.tap(find.text('Komedi'));
      await tester.pump();
      expect(find.byType(MediaCard), findsOneWidget);
      await tester.tap(find.byType(MediaCard));
      expect(watched!.$1.single.streams.single, 'http://ornek/fb.mp4');
    });
  }

  testWidgets('Dizi: dizi › sezon › bölüm klasörleri; bölüm sezonun listesiyle açılır', (tester) async {
    await _size(tester, const Size(960, 540));
    final sources = await _sources(tester);
    (List<LiveChannel>, int)? watched;
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        LibraryPage(
          kind: SourceKind.series,
          sources: sources,
          clock: '20:45',
          profileName: 'Profil 1',
          onWatch: (l, i) async => watched = (l, i),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Kuzey Güney'));
    await tester.pump();
    expect(find.text('Sezon 1'), findsOneWidget);
    expect(find.text('Sezon 2'), findsOneWidget);
    await tester.tap(find.text('Sezon 1'));
    await tester.pump();
    await tester.tap(find.text('Bölüm 2'));
    expect(watched!.$2, 1);
    expect([for (final c in watched!.$1) c.streams.single], ['http://ornek/kg11.mp4', 'http://ornek/kg12.mp4']);
  });

  testWidgets('kaynak yoksa yönerge ve "Kaynak ekle"; Kaynaklar yalnız canlı listeleri gösterir', (tester) async {
    await _size(tester, const Size(960, 540));
    var added = false;
    final empty = await _sources(tester, empty: true);
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        LibraryPage(
          kind: SourceKind.series,
          sources: empty,
          clock: '20:45',
          profileName: 'Profil 1',
          onAdd: () => added = true,
        ),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Dizi kaynağı yok'), findsOneWidget);
    await tester.tap(find.text('Kaynak ekle'));
    expect(added, isTrue);

    final sources = await _sources(tester);
    await tester.pumpWidget(
      _app(FormFactor.tv, SourcesPage(sources: sources, clock: '20:45', profileName: 'Profil 1')),
    );
    await _settle(tester);
    expect(find.text('Canlı'), findsOneWidget);
    expect(find.text('Filmlerim'), findsNothing);
    expect(find.text('Dizilerim'), findsNothing);
  });
}
