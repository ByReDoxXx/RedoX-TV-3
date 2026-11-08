import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/user_sources.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/content/watch_history.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/shell/desktop/desktop_now_playing.dart';
import 'package:redox_tv/features/shell/desktop/desktop_shell.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/fake_radio_audio.dart';
import '../../support/render.dart';

// Windows/Linux kabuğu: üst çubuk, kitaplık paneli, içerik paneli. Her
// bölüm yaygın pencere boyutlarında taşmasız açılır; görüntüler build/desktop/.

const _sizes = [('1440x900', Size(1440, 900)), ('1280x720', Size(1280, 720)), ('1920x1080', Size(1920, 1080))];

final _stations = [
  for (var i = 1; i <= 12; i++)
    LiveChannel(
      name: ['Yıldız Pop', 'Anadolu Türküleri', 'Gündem Radyo', 'Kıyı Hit'][i % 4],
      number: i,
      category: ['Pop', 'Türk Halk', 'Haber'][i % 3],
      streams: ['s$i'],
    ),
];

String _films() {
  final b = StringBuffer('#EXTM3U\n');
  for (final (i, (name, group)) in const [
    ('Başlangıç (2010)', 'Bilim Kurgu'),
    ('Oppenheimer (2023)', 'Dram'),
    ('Dune (2021)', 'Bilim Kurgu'),
    ('Mad Max (2015)', 'Aksiyon'),
    ('Yüzüklerin Efendisi (2001)', 'Fantastik'),
    ('Gora (2004)', 'Komedi'),
    ('Babam ve Oğlum (2005)', 'Dram'),
    ('Joker (2019)', 'Gerilim'),
  ].indexed) {
    b.write('#EXTINF:-1 group-title="$group",$name\nhttp://o/f$i.mkv\n');
  }
  return b.toString();
}

String _series() {
  final b = StringBuffer('#EXTM3U\n');
  for (final show in const ['Kuzey Güney', 'Arrow', 'Çukur', 'Behzat Ç.']) {
    for (var s = 1; s <= 2; s++) {
      for (var e = 1; e <= 4; e++) {
        b.write('#EXTINF:-1 group-title="Diziler",$show S0${s}E0$e\nhttp://o/$show$s$e.mkv\n');
      }
    }
  }
  return b.toString();
}

Future<UserSources> _sources(WidgetTester tester) async => (await tester.runAsync(() async {
  final dir = await Directory.systemTemp.createTemp('redox-desktop-');
  addTearDown(() => dir.delete(recursive: true));
  final s = await UserSources.open(dir);
  await s.addText('Filmlerim', _films(), origin: SourceOrigin.file, kind: SourceKind.film);
  await s.addText('Dizilerim', _series(), origin: SourceOrigin.file, kind: SourceKind.series);
  await s.addText(
    'Spor listem',
    '#EXTM3U\n#EXTINF:-1 group-title="Spor",Spor 1\nhttp://o/s1.m3u8\n#EXTINF:-1 group-title="Spor",Spor 2\nhttp://o/s2.m3u8\n',
    origin: SourceOrigin.url,
  );
  return s;
}))!;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Widget _app(GlobalKey key, Widget home) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    themeAnimationDuration: Duration.zero,
    theme: RedoxTheme.dark(formFactor: FormFactor.desktop),
    home: home,
  ),
);

void main() {
  for (final (name, size) in _sizes) {
    testWidgets('masaüstü $name: bütün bölümler taşmasız, kitaplık paneli', (tester) async {
      await withRealShadows(() async {
        await loadSora(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final sources = await _sources(tester);
        final audio = FakeRadioAudio();
        final radio = RadioController(stations: ValueNotifier(_stations), audio: () => audio);
        addTearDown(radio.dispose);
        for (final section in AppSection.values.where((s) => s != AppSection.remote)) {
          final key = GlobalKey();
          await tester.pumpWidget(
            _app(
              key,
              RootShell(
                key: ValueKey(section),
                desktop: true,
                tv: TvContent.preview,
                initial: section,
                radio: radio,
                sources: sources,
                history: WatchHistory(const [1, 2, 3, 4]),
                favorites: Favorites(channels: const [1, 2, 3], radios: const [1, 2]),
                engineFactory: FakeEngine.new,
              ),
            ),
          );
          await _settle(tester);
          await settleAssets(tester, rounds: 2);
          expect(tester.takeException(), isNull, reason: '$name ${section.name}');
          expect(find.byType(DesktopLibraryPanel), findsOneWidget);
          expect(find.byType(RedoxNavRail), findsNothing);
          await maybeSnapshot(tester, key, 'build/desktop/$name-${section.index}-${section.name}.png');
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }

  testWidgets('masaüstü: panelden bölüm, geri/ileri, panel daraltma', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(_app(key, RootShell(desktop: true, tv: TvContent.preview, engineFactory: FakeEngine.new)));
    await tester.pump();
    final panel = find.byType(DesktopLibraryPanel);
    AppSection selected() => tester.widget<DesktopLibraryPanel>(panel).selected;
    expect(selected(), AppSection.home);
    IconButton nav(String tip) =>
        tester.widget<IconButton>(find.ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton)).first);
    expect(nav('Geri').onPressed, isNull);

    await tester.tap(find.descendant(of: panel, matching: find.text('Televizyon')));
    await tester.pump();
    expect(selected(), AppSection.tv);

    await tester.tap(find.byTooltip('Geri'));
    await tester.pump();
    expect(selected(), AppSection.home);

    await tester.tap(find.byTooltip('İleri'));
    await tester.pump();
    expect(selected(), AppSection.tv);

    await tester.tap(find.byTooltip('Paneli daralt'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSize(panel).width, DesktopLibraryPanel.collapsedWidth);
    expect(find.descendant(of: panel, matching: find.text('Televizyon')), findsNothing);
    await maybeSnapshot(tester, key, 'build/desktop/daralmis-panel.png');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('masaüstü: canlı kanal altta çalar, gezinirken sürer, tam ekran aynı oturum', (tester) async {
    await withRealShadows(() async {
      await loadSora(tester);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engines = <FakeEngine>[];
      final history = WatchHistory();
      final key = GlobalKey();
      await tester.pumpWidget(
        _app(
          key,
          RootShell(
            desktop: true,
            tv: TvContent.preview,
            history: history,
            engineFactory: () {
              final e = FakeEngine();
              engines.add(e);
              return e;
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(DesktopNowPlayingBar), findsNothing);

      await tester.tap(find.text('Canlı yayına gir'));
      await _settle(tester);
      expect(find.byType(DesktopNowPlayingBar), findsOneWidget);
      expect(find.byType(DesktopNowPlayingPanel), findsOneWidget);
      expect(find.byType(PlayerPage), findsNothing, reason: 'tam ekran açılmaz');
      expect(engines, hasLength(1));
      expect(history.value.first, 1, reason: 'görüntü gelince geçmişe yazılır');
      await settleAssets(tester, rounds: 2);
      await maybeSnapshot(tester, key, 'build/desktop/mini-oynatici-anasayfa.png');

      // Gezinirken çalmaya devam eder.
      await tester.tap(find.descendant(of: find.byType(DesktopLibraryPanel), matching: find.text('Film')));
      await _settle(tester);
      expect(find.byType(DesktopNowPlayingBar), findsOneWidget);

      // Sonraki kanal: aynı motor.
      await tester.tap(find.byTooltip('Sonraki kanal'));
      await _settle(tester);
      expect(engines, hasLength(1));
      expect(engines.single.opened, hasLength(2));
      await settleAssets(tester, rounds: 2);
      await maybeSnapshot(tester, key, 'build/desktop/oynatma-cubugu.png');

      // Tam ekran: yayın yeniden açılmaz, çıkınca çalmaya devam eder.
      await tester.tap(find.byTooltip('Tam ekran').first);
      await _settle(tester);
      expect(find.byType(PlayerPage), findsOneWidget);
      expect(engines, hasLength(1));
      expect(engines.single.opened, hasLength(2));
      Navigator.of(tester.element(find.byType(PlayerPage))).pop();
      await _settle(tester);
      expect(find.byType(PlayerPage), findsNothing);
      expect(find.byType(DesktopNowPlayingBar), findsOneWidget);
      expect(engines.single.disposed, isFalse);

      // Panel kapanır, çubuk kalır.
      await tester.tap(find.byTooltip('Paneli kapat'));
      await _settle(tester);
      expect(find.byType(DesktopNowPlayingPanel), findsNothing);
      expect(find.byType(DesktopNowPlayingBar), findsOneWidget);

      // Durdur: motor kapanır, çubuk gizlenir.
      await tester.tap(find.byTooltip('Oynatmayı durdur'));
      await _settle(tester);
      expect(find.byType(DesktopNowPlayingBar), findsNothing);
      expect(engines.single.disposed, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
