import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
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
  void Function(List<LiveChannel>, int)? onWatchList,
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
          onWatchList: onWatchList,
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

    await tester.tap(find.bySemanticsLabel('Aşağı taşı').first);
    await tester.pump();
    expect(fav.channels, [ids[1], ids[0], ids[2]]);

    await tester.tap(find.bySemanticsLabel('Favorilerden çıkar').last);
    await tester.pump();
    expect(fav.channels, [ids[1], ids[0]]);

    await tester.tap(find.text(_channels[0].name));
    await tester.pump();
    expect(watched, _channels[0]);
  });

  testWidgets('A-Z sıralaması gösterimi değiştirir, kayıtlı sırayı değil; Radyo sekmesi', (tester) async {
    await _size(tester, const Size(960, 540));
    final fav = Favorites(channels: [_channels[3].number, _channels[1].number], radios: const [2, 1]);
    await tester.pumpWidget(_app(FormFactor.tv, fav));
    await tester.pump();
    await tester.tap(find.text('A-Z'));
    await tester.pump();
    expect(fav.channels, [_channels[3].number, _channels[1].number]);
    expect(find.bySemanticsLabel('Yukarı taşı'), findsWidgets);

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

  group('Kaynaklar sekmesi (eski Klasörler yerine)', () {
    Favorites withSources() => Favorites(
      sources: const [
        FavoriteItem(name: 'Film A', url: 'f/a'),
        FavoriteItem(name: 'Bölüm 1', url: 'd/1'),
        FavoriteItem(name: 'Bölüm 2', url: 'd/2'),
      ],
    );

    testWidgets('Klasörler sekmesi yok; Kaynaklar kayıtları listeler ve listeyle açar, kaldır çıkarır', (tester) async {
      await _size(tester, const Size(960, 540));
      final fav = withSources();
      (List<LiveChannel>, int)? watched;
      await tester.pumpWidget(_app(FormFactor.tv, fav, onWatchList: (l, i) => watched = (l, i)));
      await tester.pump();
      expect(find.text('Klasörler'), findsNothing);
      await tester.tap(find.text('Kaynaklar'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bölüm 1'));
      expect(watched!.$2, 1);
      expect([for (final c in watched!.$1) c.streams.single], ['f/a', 'd/1', 'd/2']);
      await tester.tap(find.bySemanticsLabel('Favorilerden çıkar').first);
      await tester.pump();
      expect(fav.sources.map((i) => i.url), ['d/1', 'd/2']);
    });

    testWidgets('telefonda "Sıram"da sürükle-bırak sırayı değiştirir', (tester) async {
      await _size(tester, const Size(390, 844));
      final fav = withSources();
      await tester.pumpWidget(_app(FormFactor.phone, fav));
      await tester.pump();
      await tester.tap(find.text('Kaynaklar'));
      await tester.pump();
      final handle = find.byType(ReorderableDragStartListener).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fav.sources.map((i) => i.url), ['d/1', 'd/2', 'f/a']);
    });
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
