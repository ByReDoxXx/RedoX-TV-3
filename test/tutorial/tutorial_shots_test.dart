import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/core/ui/category_chip.dart';
import 'package:redox_tv/core/ui/channel_tile.dart';
import 'package:redox_tv/core/ui/header_search.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';
import 'package:redox_tv/features/home/widgets/live_board.dart';
import 'package:redox_tv/features/library/series_detail_page.dart';
import 'package:redox_tv/features/library/widgets/library_filter_bar.dart';
import 'package:redox_tv/features/radio/widgets/radio_dial.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/sources/add_source_tab.dart';
import 'package:redox_tv/features/sources/widgets/source_widgets.dart';
import 'package:redox_tv/features/tutorial/tutorial_stories.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../support/fake_engine.dart';
import '../support/fake_radio_audio.dart';
import '../support/render.dart';

// Öğretici hikâyelerin görüntüleri (Anasayfa halkaları): her cihaz biçiminde
// uygulamanın bölümleri açılır, ekran görüntüsü PNG olarak alınır ve
// vurgulanacak öğelerin dikdörtgenleri (0–1) manifest.json'a yazılır.
// Üretmek için: REDOX_TUTORIAL=1 flutter test test/tutorial/tutorial_shots_test.dart
// sonra: python tools/egitim/webp.py (PNG → WebP, assets/tutorial/).
// Ortam değişkeni yokken yalnız ekranların taşmasız açıldığı denetlenir.

bool get _write => Platform.environment['REDOX_TUTORIAL'] == '1';

const _devices = [
  (FormFactor.tv, Size(960, 540), 2.0),
  (FormFactor.tablet, Size(1280, 800), 1.5),
  (FormFactor.phone, Size(390, 844), 2.0),
];

final _stations = [
  for (var i = 1; i <= 12; i++)
    LiveChannel(
      name: ['Yıldız Pop', 'Anadolu Türküleri', 'Gündem Radyo', 'Kıyı Hit'][i % 4],
      number: i,
      category: ['Pop', 'Türk Halk', 'Haber'][i % 3],
      streams: ['s$i'],
    ),
];

String _m3u(List<(String, String)> items) => [
  '#EXTM3U',
  for (final (i, (name, group)) in items.indexed) '#EXTINF:-1 group-title="$group",$name\nhttp://o/$i.mkv',
].join('\n');

Future<UserSources> _sources(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-egitim-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  await s.addText(
    'Filmlerim',
    _m3u(const [
      ('Başlangıç (2010)', 'Bilim Kurgu'),
      ('Oppenheimer (2023)', 'Dram'),
      ('Dune (2021)', 'Bilim Kurgu'),
      ('Mad Max (2015)', 'Aksiyon'),
      ('Yüzüklerin Efendisi (2001)', 'Fantastik'),
      ('Gora (2004)', 'Komedi'),
      ('Babam ve Oğlum (2005)', 'Dram'),
      ('Joker (2019)', 'Gerilim'),
      ('Interstellar (2014)', 'Bilim Kurgu'),
      ('Kurtlar Vadisi (2006)', 'Aksiyon'),
    ]),
    origin: SourceOrigin.file,
    kind: SourceKind.film,
  );
  await s.addText(
    'Dizilerim',
    _m3u([
      for (final show in const ['Kuzey Güney', 'Arrow', 'Çukur', 'Behzat Ç.', 'Ezel'])
        for (var se = 1; se <= 3; se++)
          for (var e = 1; e <= 6; e++) ('$show S0${se}E0$e', 'Diziler'),
    ]),
    origin: SourceOrigin.file,
    kind: SourceKind.series,
  );
  await s.addText('Spor listem', _m3u(const [('Spor 1', 'Spor'), ('Spor 2', 'Spor')]), origin: SourceOrigin.url);
  return s;
}))!;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Bulunanların birleşik dikdörtgeni (ekranla kesişen kısmı); yoksa null.
Rect? _rect(WidgetTester tester, Finder f, Size screen) {
  final found = f.evaluate().toList();
  if (found.isEmpty) return null;
  Rect? all;
  for (final e in found) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize) continue;
    final r = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    all = all == null ? r : all.expandToInclude(r);
  }
  final clipped = all?.intersect(Offset.zero & screen);
  if (clipped == null || clipped.width <= 4 || clipped.height <= 4) return null;
  return clipped;
}

List<double> _norm(Rect r, Size s) => [
  for (final v in [r.left / s.width, r.top / s.height, r.right / s.width, r.bottom / s.height])
    double.parse(v.toStringAsFixed(4)),
];

void main() {
  for (final (f, size, ratio) in _devices) {
    final folder = TutorialStories.folder(f);
    testWidgets('öğretici görüntüleri: $folder', (tester) async {
      await withRealShadows(() async {
        await loadSora(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final sources = await _sources(tester);
        final audio = FakeRadioAudio();
        final radio = RadioController(stations: ValueNotifier(_stations), audio: () => audio);
        addTearDown(radio.dispose);
        final manifest = <String, Map<String, Object?>>{};
        final out = 'build/egitim/$folder';

        Future<void> open(AppSection section, GlobalKey key) async {
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                themeAnimationDuration: Duration.zero,
                theme: RedoxTheme.dark(formFactor: f),
                home: RootShell(
                  key: UniqueKey(),
                  tv: TvContent.preview,
                  initial: section,
                  radio: radio,
                  sources: sources,
                  favorites: Favorites(channels: const [1, 2, 3], radios: const [1, 2]),
                  engineFactory: FakeEngine.new,
                ),
              ),
            ),
          );
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
        }

        Future<void> shot(String id, GlobalKey key, Map<String, Finder> highlights) async {
          expect(tester.takeException(), isNull, reason: '$folder $id');
          manifest[id] = {
            for (final MapEntry(:key, :value) in highlights.entries)
              if (_rect(tester, value, size) case final r?) key: _norm(r, size),
          };
          if (!_write) return;
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: ratio);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$id.png')
              ..createSync(recursive: true)
              ..writeAsBytesSync(png!.buffer.asUint8List());
          });
        }

        final nav = f == FormFactor.phone ? find.byType(RedoxBottomBar) : find.byType(RedoxNavRail);
        final chips = find.byType(CategoryChip);

        var key = GlobalKey();
        await open(AppSection.home, key);
        await shot('home', key, {
          'home.board': find.byType(LiveBoard),
          'home.nav': nav,
          'home.search': find.byType(HeaderSearch),
        });

        key = GlobalKey();
        await open(AppSection.tv, key);
        await shot('tv', key, {
          'tv.chips': chips,
          'tv.card': find.byType(ChannelTile).first,
          // TV/tablette yazılı düğme, telefonda yalnız ikon.
          'tv.guide': find.byWidgetPredicate(
            (w) => (w is Text && w.data == 'EPG çizelgesi') || (w is RedoxIcon && w.icon == RedoxIcons.epg),
          ),
        });
        // Oynatıcı: ilk kanal açılır, çubuk gösterilir. TV/tablette ilk
        // dokunma önizlemedir, aynı kanala ikinci dokunma tam ekran açar.
        await tester.tap(find.byType(ChannelTile).first);
        await _settle(tester);
        if (f != FormFactor.phone) {
          await tester.tap(find.byType(ChannelTile).first);
          await _settle(tester);
        }
        if (f == FormFactor.tv) {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
        } else {
          await tester.tapAt(size.center(Offset.zero));
        }
        await _settle(tester);
        await shot('player', key, const {});

        key = GlobalKey();
        await open(AppSection.radio, key);
        await shot('radio', key, {'radio.list': find.byType(ListView).first});
        await tester.tap(find.text(_stations.first.name).first);
        await _settle(tester);
        await shot('radio-dial', key, {'radio.dial': find.byType(RadioDial)});

        key = GlobalKey();
        await open(AppSection.film, key);
        await shot('film', key, {
          'film.grid': find.byType(GridView),
          'film.filter': find.byWidgetPredicate((w) => w is LibraryFilterBar),
        });

        key = GlobalKey();
        await open(AppSection.series, key);
        await shot('series', key, {'series.grid': find.byType(GridView)});
        await tester.tap(find.text('Arrow').first);
        await _settle(tester);
        await shot('series-detail', key, {
          'series.seasons': find.descendant(of: find.byType(SeriesDetailPage), matching: chips),
        });

        key = GlobalKey();
        await open(AppSection.favorites, key);
        await shot('favorites', key, {'favorites.tabs': chips});

        key = GlobalKey();
        await open(AppSection.splitScreen, key);
        final tile = find.text('Kanal ekle').first;
        await shot('split', key, {'split.tile': find.ancestor(of: tile, matching: find.byType(InkWell)).first});

        key = GlobalKey();
        await open(AppSection.sources, key);
        await shot('sources', key, {
          'sources.add': find.byType(AddSourceCard),
          'sources.card': find.byType(FolderCard).first,
        });

        key = GlobalKey();
        await open(AppSection.settings, key);
        await shot('settings', key, {
          // Telefonda Ayarlar önce listeyle açılır: "Kaynak ekle" satırı.
          'settings.steps': f == FormFactor.phone
              ? find.ancestor(of: find.text('Kaynak ekle').first, matching: find.byType(InkWell)).first
              : find.byType(AddSourceTab),
          'settings.menu': find.ancestor(of: find.text('Oynatıcı').first, matching: find.byType(InkWell)).first,
        });

        await tester.pumpWidget(const SizedBox());
        expect(manifest.keys.toSet(), TutorialStories.shots, reason: 'her hikâye görüntüsü üretildi');
        if (_write) {
          File('$out/manifest.json')
            ..createSync(recursive: true)
            ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
        }
      });
    });
  }
}
