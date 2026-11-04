import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/platform/system_text_input.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/favorites/favorites_page.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_radio_audio.dart';
import '../../support/render.dart';

final _channels = TvContent.preview.channels;
const _radios = [
  LiveChannel(name: 'Yıldız Pop', number: 1, category: 'Pop', streams: ['r1']),
  LiveChannel(name: 'Anadolu Türküleri', number: 2, category: 'Türkü & Halk', streams: ['r2']),
];

Finder _label(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(
  FormFactor f,
  Favorites fav, {
  ValueChanged<LiveChannel>? onWatch,
  Future<void> Function(List<LiveChannel>, int, SourceKind)? onWatchSource,
  GlobalKey? boundary,
}) {
  final radio = RadioController(stations: ValueNotifier(_radios), audio: FakeRadioAudio.new);
  addTearDown(radio.dispose);
  return RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: f),
      home: Scaffold(
        body: FavoritesPage(
          favorites: fav,
          channels: _channels,
          radio: radio,
          clock: '20:45',
          profileName: 'Profil 1',
          onWatch: onWatch,
          onWatchSource: onWatchSource,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('TV kanalları sırayla; yukarı/aşağı sırayı değiştirir, kaldır çıkarır; OK kanalı açar', (tester) async {
    await _size(tester, const Size(960, 540));
    final ids = [_channels[2].number, _channels[0].number, _channels[5].number];
    final fav = Favorites(channels: ids, radios: const [2]);
    LiveChannel? watched;
    await tester.pumpWidget(_app(FormFactor.tv, fav, onWatch: (c) => watched = c));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(_channels[2].name), findsOneWidget);

    await tester.tap(_label('Favorilerden çıkar').last);
    await tester.pump();
    expect(fav.channels, [ids[0], ids[1]]);
    expect(_label('Aşağı taşı'), findsNothing, reason: 'yalnız taşırken');

    await tester.tap(find.text(_channels[0].name));
    await tester.pump();
    expect(watched, _channels[0]);
  });

  testWidgets('A-Z sıralaması gösterimi değiştirir, kayıtlı sırayı değil; Radyo sekmesi', (tester) async {
    await _size(tester, const Size(960, 540));
    final fav = Favorites(channels: [_channels[3].number, _channels[1].number], radios: const [2, 1]);
    await tester.pumpWidget(_app(FormFactor.tv, fav));
    await tester.pump();
    await tester.tap(find.text('Sıram'));
    await tester.pump();
    expect(find.text('A-Z'), findsOneWidget);
    expect(fav.channels, [_channels[3].number, _channels[1].number]);

    await tester.tap(find.text('Radyo'));
    await tester.pump();
    expect(find.text('Anadolu Türküleri'), findsOneWidget);
    expect(find.text('Yıldız Pop'), findsOneWidget);
  });

  testWidgets('görüntüler: TV ve telefon; boş liste', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
      ]) {
        await _size(tester, size);
        final key = GlobalKey();
        final fav = Favorites(channels: [for (final c in _channels.take(6)) c.number]);
        await tester.pumpWidget(_app(f, fav, boundary: key));
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/favoriler/$name.png', pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(_app(f, Favorites(), boundary: key));
        await tester.pump();
        expect(find.textContaining('Favori kanal yok'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('TV: uzun OK taşıma kipini açar; aşağı/yukarı sırayı değiştirir, OK bitirir', (tester) async {
    await _size(tester, const Size(960, 540));
    final ids = [_channels[0].number, _channels[1].number, _channels[2].number];
    final fav = Favorites(channels: ids);
    await tester.pumpWidget(_app(FormFactor.tv, fav, onWatch: (_) => fail('taşırken açılmamalı')));
    await tester.pump();
    // Odak ilk satırda (autofocus); uzun OK.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.textContaining('OK ile bitirin'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(fav.channels, [ids[1], ids[2], ids[0]]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(fav.channels, [ids[1], ids[0], ids[2]]);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(find.textContaining('OK ile bitirin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('kaynak favorileri türüne göre', () {
    Favorites withSources() => Favorites(
      sources: const [
        FavoriteItem(name: 'Film A', url: 'f/a', kind: SourceKind.film),
        FavoriteItem(name: 'Kuzey S01E01', url: 'd/1', kind: SourceKind.series, sourceId: 'k1', category: 'Yerli'),
        FavoriteItem(name: 'Canlı Kanal', url: 't/1', kind: SourceKind.live, category: 'Haber'),
        FavoriteItem(name: 'Film B', url: 'f/b', kind: SourceKind.film),
        FavoriteItem(name: 'Kuzey S01E02', url: 'd/2', kind: SourceKind.series, sourceId: 'k1', category: 'Yerli'),
        FavoriteItem(name: 'Güney S01E01', url: 'd/3', kind: SourceKind.series, sourceId: 'k1', category: 'Yerli'),
      ],
    );

    testWidgets('Kaynaklar sekmesi yok; canlı TV Televizyon\'da, film Film\'de, dizi Dizi\'de', (tester) async {
      await _size(tester, const Size(960, 540));
      final fav = withSources();
      (List<LiveChannel>, int, SourceKind)? watched;
      await tester.pumpWidget(_app(FormFactor.tv, fav, onWatchSource: (l, i, k) async => watched = (l, i, k)));
      await tester.pump();
      expect(find.text('Kaynaklar'), findsNothing);
      expect(find.text('Klasörler'), findsNothing);

      expect(find.text('Canlı Kanal'), findsOneWidget);
      await tester.tap(find.text('Canlı Kanal'));
      await tester.pump();
      expect(watched!.$3, SourceKind.live);
      expect(watched!.$1.single.streams.single, 't/1');

      await tester.tap(find.text('Film'));
      await tester.pump();
      expect(find.text('Film A'), findsOneWidget);
      expect(find.text('Film B'), findsOneWidget);
      expect(find.text('Canlı Kanal'), findsNothing);
      await tester.tap(find.text('Film B'));
      await tester.pump();
      expect(watched!.$3, SourceKind.film);
      expect(watched!.$2, 1);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Dizi'));
      await tester.pump();
      expect(find.text('Kuzey'), findsOneWidget, reason: 'bölümler diziye göre toplanır');
      expect(find.text('Güney'), findsOneWidget);
      expect(find.text('2 bölüm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('afişin düğmesi onayla çıkarır; dizide bütün bölümler', (tester) async {
      await _size(tester, const Size(390, 844));
      final fav = withSources();
      await tester.pumpWidget(_app(FormFactor.phone, fav));
      await tester.pump();
      await tester.tap(find.text('Dizi'));
      await tester.pump();
      await tester.tap(_label('Favorilerden çıkar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkar'));
      await tester.pumpAndSettle();
      // A-Z değil eklenme sırası: Kuzey önce, Güney sonda.
      expect([for (final i in fav.sourcesOf(SourceKind.series)) i.url], ['d/1', 'd/2']);
      expect([for (final i in fav.sourcesOf(SourceKind.film)) i.url], ['f/a', 'f/b']);
    });

    testWidgets('telefonda Televizyon\'da sürükle-bırak sırayı değiştirir', (tester) async {
      await _size(tester, const Size(390, 844));
      final ids = [_channels[0].number, _channels[1].number, _channels[2].number];
      final fav = Favorites(channels: ids);
      await tester.pumpWidget(_app(FormFactor.phone, fav));
      await tester.pump();
      final handle = find.byType(ReorderableDragStartListener).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fav.channels, [ids[1], ids[2], ids[0]]);
    });

    for (final (f, size) in const [(FormFactor.phone, Size(390, 844)), (FormFactor.tablet, Size(1024, 768))]) {
      testWidgets('${f.name}: afiş basılı tutup sürüklenir; diziler bölümleriyle taşınır', (tester) async {
        await _size(tester, size);
        final fav = withSources();
        await tester.pumpWidget(_app(f, fav));
        await tester.pump();
        await tester.tap(find.text('Film'));
        await tester.pump();
        Future<void> drag(String from, String to) async {
          final gesture = await tester.startGesture(tester.getCenter(find.text(from)));
          await tester.pump(const Duration(milliseconds: 700));
          await gesture.moveTo(tester.getCenter(find.text(to).first));
          await tester.pump(const Duration(milliseconds: 100));
          await gesture.up();
          await tester.pumpAndSettle();
        }

        await drag('Film B', 'Film A');
        expect([for (final i in fav.sourcesOf(SourceKind.film)) i.url], ['f/b', 'f/a']);

        await tester.tap(find.text('Dizi'));
        await tester.pump();
        await drag('Güney', 'Kuzey');
        expect([for (final i in fav.sourcesOf(SourceKind.series)) i.url], ['d/3', 'd/1', 'd/2']);
        expect(fav.sources.map((i) => i.kind).toSet(), {SourceKind.film, SourceKind.series, SourceKind.live});
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('arama: yazdıkça süzer, sayılar değişir, Türkçe harfsiz bulur, sürükleme kapanır', (tester) async {
      await _size(tester, const Size(390, 844));
      final fav = withSources();
      await tester.pumpWidget(_app(FormFactor.phone, fav));
      await tester.pump();
      await tester.tap(find.text('Dizi'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'guney');
      await tester.pump();
      expect(find.text('Güney'), findsOneWidget);
      expect(find.text('Kuzey'), findsNothing);
      expect(find.byType(LongPressDraggable<Object>), findsNothing);

      await tester.tap(find.text('Film'));
      await tester.pump();
      expect(find.text('Bu sekmede sonuç yok'), findsOneWidget);
      await tester.tap(find.text('Aramayı temizle'));
      await tester.pump();
      expect(find.text('Film A'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TV: Ara düğmesi sistem kutusunu açar, sonuç süzülür; boş onay temizler', (tester) async {
      await _size(tester, const Size(960, 540));
      final fav = withSources();
      var answer = 'canli';
      SystemTextInput.debugOverride = (_, _, _) async => answer;
      addTearDown(() => SystemTextInput.debugOverride = null);
      await tester.pumpWidget(_app(FormFactor.tv, Favorites(channels: [_channels[0].number], sources: fav.sources)));
      await tester.pump();
      await tester.tap(find.text('Ara'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Canlı Kanal'), findsOneWidget);
      expect(find.text(_channels[0].name), findsNothing);
      answer = '';
      await tester.tap(find.text('canli'));
      await tester.pump();
      await tester.pump();
      expect(find.text(_channels[0].name), findsOneWidget);
    });

    testWidgets('görüntüler: yeni tasarım', (tester) async {
      await withRealShadows(() async {
        for (final (f, size, name) in const [
          (FormFactor.tv, Size(960, 540), 'tv'),
          (FormFactor.tablet, Size(1024, 768), 'tablet'),
          (FormFactor.phone, Size(390, 844), 'telefon'),
        ]) {
          await _size(tester, size);
          final key = GlobalKey();
          final fav = Favorites(
            channels: [for (final c in _channels.take(5)) c.number],
            sources: withSources().sources,
          );
          await tester.pumpWidget(_app(f, fav, boundary: key));
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/favoriler/$name-tv.png', pixelRatio: 2);
          await tester.tap(find.text('Film'));
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/favoriler/$name-film.png', pixelRatio: 2);
          await tester.tap(find.text('Dizi'));
          await settleAssets(tester, rounds: 2);
          await maybeSnapshot(tester, key, 'build/favoriler/$name-dizi.png', pixelRatio: 2);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    });
  });

  test('türü olmayan eski favori: kaynak bulunursa oradan, yoksa addan; kalıcı', () {
    final saved = <Favorites>[];
    final fav = Favorites(
      sources: const [
        FavoriteItem(name: 'Kanal', url: 'http://a/1.m3u8'),
        FavoriteItem(name: 'Dizi S01E02', url: 'http://a/2.m3u8'),
        FavoriteItem(name: 'Belgesel', url: 'http://a/movie/x/3.mp4'),
      ],
      onSave: (f) async => saved.add(f),
    );
    expect(fav.sourcesOf(SourceKind.series).single.name, 'Dizi S01E02');
    expect(fav.sourcesOf(SourceKind.film).single.name, 'Belgesel');
    expect(fav.unclassified, hasLength(3));

    fav.classify({'http://a/1.m3u8': (kind: SourceKind.film, sourceId: 'k', category: 'Grup')}, complete: false);
    expect(fav.sourcesOf(SourceKind.film).map((i) => i.name), ['Kanal', 'Belgesel']);
    expect(fav.unclassified, hasLength(2));

    fav.classify(const {}, complete: true);
    expect(fav.unclassified, isEmpty);
    expect(fav.sourcesOf(SourceKind.series).single.kind, SourceKind.series);
    expect(saved, isNotEmpty);
    expect(FavoriteItem.fromJson(fav.sources.first.toJson())!.kind, SourceKind.film);
    expect(FavoriteItem.fromJson(fav.sources.first.toJson())!.sourceId, 'k');
  });

  test('eski klasör favorileri Kaynaklar listesine aktarılır (ağaç sırasıyla, tekrarsız)', () {
    const json =
        '{"ad":"","klasorler":[{"ad":"Diziler","klasorler":[{"ad":"1.Sezon","kayitlar":['
        '{"ad":"Bölüm01","adres":"d11"},{"ad":"Bölüm02","adres":"d12","logo":"l.png"}]}],'
        '"kayitlar":[{"ad":"Fragman","adres":"d11"}]}],"kayitlar":[{"ad":"Film","adres":"f1"}]}';
    expect(
      [for (final i in Favorites.migrateFolders(json)) (i.name, i.url, i.logo)],
      [('Film', 'f1', null), ('Fragman', 'd11', null), ('Bölüm02', 'd12', 'l.png')],
    );
    expect(Favorites.migrateFolders(null), isEmpty);
    expect(Favorites.migrateFolders('bozuk'), isEmpty);
  });
}
