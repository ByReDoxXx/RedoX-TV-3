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
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/fake_radio_audio.dart';
import '../../support/render.dart';

// Tablet sürümü (kullanıcının tableti yok): uygulamanın her bölümü yaygın
// tablet boyutlarında (dp) taşmasız açılır; görüntüler build/tablet/.

const _sizes = [('10-yatay', Size(1280, 800)), ('10-dikey', Size(800, 1280)), ('kucuk-yatay', Size(1024, 768))];

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
  final dir = await Directory.systemTemp.createTemp('redox-tablet-');
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

void main() {
  for (final (name, size) in _sizes) {
    testWidgets('tablet $name: bütün bölümler taşmasız, sol ray', (tester) async {
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
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                themeAnimationDuration: Duration.zero,
                theme: RedoxTheme.dark(formFactor: FormFactor.tablet),
                home: RootShell(
                  // Her bölüm ayrı kabukla açılır.
                  key: ValueKey(section),
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
          expect(tester.takeException(), isNull, reason: '$name ${section.name}');
          expect(find.byType(RedoxNavRail), findsOneWidget, reason: '$name ${section.name}');
          await maybeSnapshot(tester, key, 'build/tablet/$name-${section.index}-${section.name}.png');
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
