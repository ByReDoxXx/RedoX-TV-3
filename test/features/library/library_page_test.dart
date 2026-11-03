import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:redox_tv/core/content/channel_folder.dart';
import 'package:redox_tv/core/content/content_locks.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/series_catalog.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/media_card.dart';
import 'package:redox_tv/features/library/film_detail_page.dart';
import 'package:redox_tv/features/locks/lock_scope.dart';
import 'package:redox_tv/features/library/library_page.dart';
import 'package:redox_tv/features/library/series_detail_page.dart';
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

/// TMDB: "Film B" ve "Kuzey Güney" bulunur.
Tmdb _tmdb() => Tmdb(
  token: 'anahtar',
  fetch: (uri, _) async {
    // Komik Film'in benzerleri: biri listede yok, biri özgün adıyla "Film A".
    if (uri.path == '/3/movie/1/recommendations') {
      return utf8.encode(
        jsonEncode({
          'results': [
            {'id': 9, 'title': 'Olmayan Film'},
            {'id': 10, 'title': 'Aksiyon Filmi', 'original_title': 'Film A'},
          ],
        }),
      );
    }
    final q = uri.queryParameters['query'];
    final hit = switch (q) {
      'Film B' => {
        'id': 1,
        'title': 'Komik Film',
        'overview': 'Gülmekten kırılacaksınız.',
        'release_date': '2021-05-01',
        'vote_average': 7.25,
      },
      'Kuzey Güney' => {
        'id': 2,
        'name': 'Kuzey Güney',
        'overview': 'İki kardeşin hikâyesi.',
        'first_air_date': '2011-09-07',
        'vote_average': 7.5,
      },
      _ => null,
    };
    return utf8.encode(
      jsonEncode({
        'results': [?hit],
      }),
    );
  },
);

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

  testWidgets('TV: odaktaki afiş büyüyünce ızgaranın içinde kalır (kesilmez)', (tester) async {
    await _size(tester, const Size(960, 540));
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('redox-odak-')))!;
    addTearDown(() => dir.delete(recursive: true));
    final sources = (await tester.runAsync(() async {
      final s = await UserSources.open(dir);
      final m3u = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 40; i++) {
        m3u.write('#EXTINF:-1 group-title="${i.isEven ? 'Aksiyon' : 'Komedi'}",Film $i\nhttp://ornek/f$i.mp4\n');
      }
      await s.addText('Filmlerim', m3u.toString(), origin: SourceOrigin.file, kind: SourceKind.film);
      return s;
    }))!;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          FormFactor.tv,
          LibraryPage(
            kind: SourceKind.film,
            sources: sources,
            clock: '20:45',
            profileName: 'Profil 1',
            onWatch: (_, _) async {},
          ),
        ),
      ),
    );
    await _settle(tester);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    final grid = tester.getRect(find.byType(GridView));
    Future<void> check(String name) async {
      // Kaydırma ve büyüme yayları biter.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final focused = FocusManager.instance.primaryFocus!.context!;
      final card = tester.getRect(
        find.ancestor(of: find.byWidget(focused.widget), matching: find.byType(MediaCard)).first,
      );
      // Büyüme (1.08: her kenarda %4) ve halka (2 dp ofset + 2 dp) dahil kart
      // ızgaranın görünür alanında kalmalı.
      final grown = Rect.fromCenter(center: card.center, width: card.width * 1.08 + 9, height: card.height * 1.08 + 9);
      expect(grid.contains(grown.topLeft) && grid.contains(grown.bottomRight), isTrue, reason: '$name $card / $grid');
      await maybeSnapshot(tester, key, 'build/kutuphane/odak-$name.png', pixelRatio: 2);
    }

    // İlk kart odakta (kartın yazısının en yakın odak düğümü: InkWell).
    Focus.of(tester.element(find.descendant(of: find.byType(MediaCard).first, matching: find.byType(Text)).first))
        .requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus!.context!.findAncestorWidgetOfExactType<MediaCard>(), isNotNull);
    await check('ilk');
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await check('asagi');
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await check('sag');
  });

  for (final (f, size) in const [(FormFactor.tv, Size(960, 540)), (FormFactor.phone, Size(412, 915))]) {
    testWidgets('${f.name}: Dizi afiş ızgarası; dizi sayfası sezonlar ve bölümlerle, bölüm sezonun listesiyle açılır', (
      tester,
    ) async {
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
              kind: SourceKind.series,
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
      expect(find.byType(MediaCard), findsOneWidget, reason: 'bir dizi, bir kart');
      expect(find.text('2 sezon'), findsOneWidget);
      await maybeSnapshot(tester, key, 'build/kutuphane/dizi-${f.name}.png', pixelRatio: 2);
      await tester.tap(find.byType(MediaCard));
      await tester.pumpAndSettle();
      expect(find.byType(SeriesDetailPage), findsOneWidget);
      expect(find.text('Sezon 1'), findsOneWidget);
      expect(find.text('Sezon 2'), findsOneWidget);
      expect(find.text('Bölüm 1'), findsOneWidget);
      expect(find.text('Bölüm 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/kutuphane/dizi-sayfa-${f.name}.png', pixelRatio: 2);
      await tester.tap(find.text('Bölüm 2'));
      expect(watched!.$2, 1);
      expect([for (final c in watched!.$1) c.streams.single], ['http://ornek/kg11.mp4', 'http://ornek/kg12.mp4']);
      await tester.tap(find.text('Sezon 2'));
      await tester.pump();
      expect(find.text('Bölüm 2'), findsNothing);
      await tester.tap(find.text('Bölüm 1'));
      expect(watched!.$1.single.streams.single, 'http://ornek/kg21.mp4');
      await tester.tap(find.textContaining('İzle'));
      expect(watched!.$1.first.streams.single, 'http://ornek/kg11.mp4', reason: 'İzle: ilk sezonun ilk bölümü');
    });
  }

  test('dizi kataloğu: adlardan sezon/bölüm; adsızlar grup adıyla tek sezon; listeler birleşir', () {
    LiveChannel c(String name, String group, String url) =>
        LiveChannel(name: name, number: 0, category: group, streams: [url]);
    final catalog = SeriesCatalog.build([
      ('a', [c('Ezel S01E02 Kaçış', 'Yerli', 'u2'), c('Ezel S01E01', 'Yerli', 'u1'), c('Belgesel X', 'Doğa', 'b1')]),
      ('b', [c('ezel S02E01', 'Yerli', 'u3'), c('Belgesel Y', 'Doğa', 'b2')]),
    ]);
    expect([for (final s in catalog) s.name], ['Doğa', 'Ezel']);
    final ezel = catalog.last;
    expect(ezel.seasons, [1, 2]);
    expect([for (final e in ezel.episodes(1)) e.label], ['Bölüm 1', 'Bölüm 2 · Kaçış']);
    expect(ezel.summary, '2 sezon · 3 bölüm');
    final doga = catalog.first;
    expect([for (final e in doga.episodes(1)) (e.number, e.title)], [(1, 'Belgesel X'), (1, 'Belgesel Y')]);
  });

  testWidgets('kaynak yoksa yönerge ve "Kaynak ekle"; Kaynaklar bütün listeleri türüyle gösterir', (tester) async {
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
    expect(find.text('Filmlerim'), findsOneWidget);
    expect(find.text('2 film · Film · Dosya'), findsOneWidget);
    expect(find.text('3 bölüm · Dizi · Dosya'), findsOneWidget);
  });

  testWidgets("Kaynaklar'dan silinen dizi Dizi bölümünden, favorilerden ve kilitlerden de kalkar", (tester) async {
    SharedPreferences.setMockInitialValues({
      // Açılmamış başka profilin favorisi de temizlenir.
      'favori_kaynak_baska': [
        jsonEncode({'ad': 'KG 1', 'adres': 'http://ornek/kg11.mp4'}),
      ],
    });
    await _size(tester, const Size(960, 540));
    final sources = await _sources(tester);
    final favorites = Favorites(
      sources: [const FavoriteItem(name: 'KG 2', url: 'http://ornek/kg12.mp4')],
    );
    final dizi = sources.of(SourceKind.series).single;
    final locks = ContentLocks({
      ContentLocks.folder(dizi.id, ['Kuzey Güney']),
      ContentLocks.item('http://ornek/kg21.mp4'),
      'kanal:1',
    });
    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        LockScope(
          locks: locks,
          profiles: null,
          child: SourcesPage(sources: sources, favorites: favorites, clock: '20:45', profileName: 'Profil 1'),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Dizilerim'));
    await _settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dizi bölümündeki kayıtları'), findsOneWidget);
    await tester.tap(find.text('Sil').last);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(sources.of(SourceKind.series), isEmpty);
    expect(find.text('Dizilerim'), findsNothing);
    expect(favorites.sources, isEmpty);
    expect(locks.isLocked(ContentLocks.folder(dizi.id, ['Kuzey Güney'])), isFalse);
    expect(locks.isLocked(ContentLocks.item('http://ornek/kg21.mp4')), isFalse);
    expect(locks.isLocked('kanal:1'), isTrue, reason: 'başka kilitler kalır');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favori_kaynak_baska'), isEmpty);

    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        LibraryPage(kind: SourceKind.series, sources: sources, clock: '20:45', profileName: 'Profil 1'),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Dizi kaynağı yok'), findsOneWidget);
  });

  testWidgets('TMDB: film ayrıntısı (ad, yıl, puan, özet), İzle oynatır; dizi klasöründe özet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _size(tester, const Size(960, 540));
    final sources = await _sources(tester);
    final tmdb = _tmdb();
    (List<LiveChannel>, int)? watched;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          FormFactor.tv,
          LibraryPage(
            kind: SourceKind.film,
            sources: sources,
            tmdb: tmdb,
            clock: '20:45',
            profileName: 'Profil 1',
            onWatch: (l, i) async => watched = (l, i),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Komedi'));
    await tester.pump();
    await tester.tap(find.byType(MediaCard));
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(FilmDetailPage), findsOneWidget);
    expect(watched, isNull, reason: 'önce ayrıntı');
    expect(find.text('Komik Film'), findsOneWidget);
    expect(find.text('Film B'), findsOneWidget, reason: 'listedeki ad altta');
    expect(find.textContaining('2021', findRichText: true), findsOneWidget);
    expect(find.textContaining('7.3 TMDB', findRichText: true), findsOneWidget);
    expect(find.text('Gülmekten kırılacaksınız.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await maybeSnapshot(tester, key, 'build/kutuphane/film-ayrinti-tv.png', pixelRatio: 2);
    await tester.tap(find.text('İzle'));
    await tester.pumpAndSettle();
    expect(watched!.$1[watched!.$2].streams.single, 'http://ornek/fb.mp4');
    expect(find.byType(FilmDetailPage), findsOneWidget, reason: 'oynatıcıdan Geri film sayfasına döner');

    // Benzerleri: yalnız listede olan öneri (Komedi süzgecinden bağımsız);
    // seçilen film aynı sayfanın yerine açılır, Geri listeye döner.
    expect(find.text('Benzerleri'), findsOneWidget);
    expect(find.text('Olmayan Film'), findsNothing);
    await tester.tap(find.text('Aksiyon Filmi'));
    await tester.pumpAndSettle();
    expect(find.byType(FilmDetailPage), findsOneWidget);
    expect(find.text('Film A'), findsWidgets);
    expect(find.text('Komik Film'), findsNothing);
    await tester.tap(find.text('İzle'));
    await tester.pumpAndSettle();
    expect(watched!.$1[watched!.$2].name, 'Film A');
    Navigator.of(tester.element(find.byType(FilmDetailPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(FilmDetailPage), findsNothing);

    await tester.pumpWidget(
      _app(
        FormFactor.tv,
        LibraryPage(kind: SourceKind.series, sources: sources, tmdb: tmdb, clock: '20:45', profileName: 'Profil 1'),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byType(MediaCard));
    await _settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('İki kardeşin hikâyesi.'), findsOneWidget);
    expect(find.textContaining('7.5 TMDB', findRichText: true), findsOneWidget);
    expect(find.text('Sezon 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
