import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/player/widgets/desktop_vod_controls.dart';
import 'package:redox_tv/features/player/widgets/touch_controls.dart';
import 'package:redox_tv/features/player/widgets/vod_tv.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

// Masaüstü film ve dizi oynatıcısı: sinema düzeni, dizide bölüm şeridi.
// Görüntüler build/desktop/.

const _film = [
  LiveChannel(name: 'Başlangıç (2010)', number: 1, category: 'Bilim Kurgu', streams: ['http://o/f.mkv']),
];

final _episodes = [
  for (var s = 1; s <= 2; s++)
    for (var e = 1; e <= 6; e++)
      LiveChannel(
        name: 'Kuzey Güney S0${s}E0$e',
        number: s * 10 + e,
        category: 'Diziler',
        streams: ['http://o/kg$s$e.mkv'],
      ),
];

Future<(FakeEngine, GlobalKey)> _open(WidgetTester tester, Size size, PlayerMode mode, List<LiveChannel> list) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = FakeEngine();
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: FormFactor.desktop),
      builder: (context, child) => RepaintBoundary(key: key, child: child),
      home: PlayerPage(
        channels: list,
        initialIndex: mode == PlayerMode.series ? 8 : 0,
        clock: '20:45',
        engineFactory: () => e,
        mode: mode,
      ),
    ),
  );
  await tester.pump();
  e.setDuration(const Duration(hours: 2, minutes: 28), at: const Duration(hours: 1, minutes: 12));
  await tester.pump(const Duration(milliseconds: 400));
  await settleAssets(tester, rounds: 3);
  return (e, key);
}

void main() {
  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    final w = size.width.toInt();

    testWidgets('masaüstü film $w: sinema düzeni', (tester) async {
      await withRealShadows(() async {
        final (e, key) = await _open(tester, size, PlayerMode.film, _film);
        expect(find.byType(DesktopVodControls), findsOneWidget);
        expect(find.byType(VodTouchControls), findsNothing, reason: 'masaüstünde dokunmatik denetim yok');
        expect(find.text('FİLM'), findsOneWidget);
        expect(find.text('Baştan başla'), findsOneWidget);
        expect(find.text('Bölümler'), findsNothing);
        expect(tester.takeException(), isNull);
        await maybeSnapshot(tester, key, 'build/desktop/oynatici-film-$w.png');

        await tester.tap(find.byTooltip('10 sn ileri (→)'));
        await tester.pump();
        expect(e.position.value, const Duration(hours: 1, minutes: 12, seconds: 10));
        await tester.pumpWidget(const SizedBox());
      });
    });

    testWidgets('masaüstü dizi $w: bölüm şeridi ve sonraki bölüm', (tester) async {
      await withRealShadows(() async {
        final (e, key) = await _open(tester, size, PlayerMode.series, _episodes);
        expect(find.text('DİZİ'), findsOneWidget);
        expect(find.text('Sonraki bölüm'), findsOneWidget);
        await tester.tap(find.text('Bölümler'));
        await tester.pump();
        await settleAssets(tester, rounds: 2);
        expect(find.byType(EpisodeStrip), findsOneWidget);
        expect(tester.takeException(), isNull);
        await maybeSnapshot(tester, key, 'build/desktop/oynatici-dizi-$w.png');

        await tester.tap(find.text('Bölümler'));
        await tester.pump();
        expect(find.byType(EpisodeStrip), findsNothing);

        await tester.tap(find.text('Sonraki bölüm'));
        await tester.pump();
        expect(e.opened.last, 'http://o/kg24.mkv');
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
