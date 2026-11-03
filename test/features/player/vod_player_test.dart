import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/watch_progress.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/player/widgets/player_bar.dart';
import 'package:redox_tv/features/player/widgets/touch_controls.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

const _episodes = [
  LiveChannel(name: 'Adanalı S02E03 Kan Davası', number: 1, category: 'Diziler', streams: ['http://o/s2e3.mkv']),
  LiveChannel(name: 'Adanalı S02E04', number: 2, category: 'Diziler', streams: ['http://o/s2e4.mkv']),
];

Future<FakeEngine> _open(
  WidgetTester tester, {
  required FormFactor f,
  required Size size,
  required PlayerMode mode,
  WatchProgress? progress,
  List<LiveChannel> channels = _episodes,
  GlobalKey? boundary,
}) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = FakeEngine();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: f),
      builder: (context, child) => RepaintBoundary(key: boundary, child: child),
      home: PlayerPage(
        channels: channels,
        initialIndex: 0,
        clock: '20:45',
        engineFactory: () => e,
        mode: mode,
        progress: progress,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return e;
}

void main() {
  test('ilerleme: 30 sn altı ve biten saklanmaz/devam edilmez; dizinin yalnız son bölümü listelenir', () {
    final p = WatchProgress();
    const film = LiveChannel(name: 'Film', number: 1, category: 'X', streams: ['http://f']);
    p.record(film, position: const Duration(seconds: 10), duration: const Duration(minutes: 90), series: false);
    expect(p.of('http://f'), isNull);
    p.record(film, position: const Duration(minutes: 40), duration: const Duration(minutes: 90), series: false);
    expect(p.resumeAt('http://f'), const Duration(minutes: 40));
    p.record(_episodes[0], position: const Duration(minutes: 5), duration: const Duration(minutes: 45), series: true);
    p.record(_episodes[1], position: const Duration(minutes: 44), duration: const Duration(minutes: 45), series: true);
    expect(p.resumeAt('http://o/s2e4.mkv'), isNull, reason: 'bitti');
    expect([for (final e in p.recent) e.title], ['Adanalı S02E04', 'Film']);
    expect(p.recent.first.episode!.series, 'Adanalı');
  });

  for (final (f, size) in const [(FormFactor.phone, Size(844, 390)), (FormFactor.tablet, Size(1280, 800))]) {
    testWidgets('${f.name}: dizi oynatıcısı başlık, sezon/bölüm, sonraki bölüm; kaldığı yerden devam', (tester) async {
      final progress = WatchProgress()
        ..record(
          _episodes[0],
          position: const Duration(minutes: 12, seconds: 5),
          duration: const Duration(minutes: 45),
          series: true,
        );
      final key = GlobalKey();
      final e = await _open(tester, f: f, size: size, mode: PlayerMode.series, progress: progress, boundary: key);
      e.setDuration(const Duration(minutes: 45));
      await tester.pump();
      expect(e.seeks.last, const Duration(minutes: 12, seconds: 5));
      expect(find.text('Kaldığın yerden: 12:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VodTouchControls), findsOneWidget);
      expect(find.byType(TouchControls), findsNothing);
      expect(find.text('Adanalı'), findsOneWidget);
      expect(find.text('Sezon 2 · Bölüm 3 · Kan Davası'), findsOneWidget);
      expect(find.text('Sonraki: S2 · B4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/oynatici/dizi-${f.name}.png');
      await tester.tap(find.text('Sonraki: S2 · B4'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(e.opened.last, 'http://o/s2e4.mkv');
    });
  }

  testWidgets('TV: film çubuğu (VodBar), ▲▼ başka filme geçmez; çıkarken yer yazılır', (tester) async {
    final progress = WatchProgress();
    final key = GlobalKey();
    const films = [
      LiveChannel(name: '|MULTI| Başlangıç (2010) [4K]', number: 1, category: 'Bilim kurgu', streams: ['http://f/1']),
      LiveChannel(name: 'Başka film', number: 2, category: 'Bilim kurgu', streams: ['http://f/2']),
    ];
    final e = await _open(
      tester,
      f: FormFactor.tv,
      size: const Size(960, 540),
      mode: PlayerMode.film,
      progress: progress,
      channels: films,
      boundary: key,
    );
    e.setDuration(const Duration(minutes: 148), at: const Duration(minutes: 33));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(VodBar), findsOneWidget);
    expect(find.byType(PlayerBar), findsNothing);
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('2010 · Bilim kurgu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await maybeSnapshot(tester, key, 'build/oynatici/film-tv.png');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pump(const Duration(milliseconds: 400));
    expect(e.opened, ['http://f/1'], reason: 'filmde ▲▼ kanal değiştirmez');
    await tester.pumpWidget(const SizedBox());
    expect(progress.resumeAt('http://f/1'), const Duration(minutes: 33));
  });
}
