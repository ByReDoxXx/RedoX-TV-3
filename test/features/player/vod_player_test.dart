import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/tmdb.dart';
import 'package:redox_tv/core/content/watch_progress.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/player/next_episode.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/player/widgets/player_bar.dart';
import 'package:redox_tv/features/player/widgets/seek_bar.dart';
import 'package:redox_tv/features/player/widgets/touch_controls.dart';
import 'package:redox_tv/features/player/widgets/vod_touch_panels.dart';
import 'package:redox_tv/features/player/widgets/vod_tv.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Tmdb? tmdb,
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
        tmdb: tmdb,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return e;
}

/// Dokunmatik dizi: bilgi kaybolmuş, çubuk kapalı; bölümün ortasında.
final _shots = GlobalKey();

Future<FakeEngine> _series(
  WidgetTester tester, {
  FormFactor f = FormFactor.phone,
  Size size = const Size(844, 390),
}) async {
  final e = await _open(tester, f: f, size: size, mode: PlayerMode.series, boundary: _shots);
  e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
  await tester.pump(PlayerPage.announceDuration);
  await tester.pump(const Duration(milliseconds: 400));
  return e;
}

Future<void> _tapCenter(WidgetTester tester, Size size) async {
  await tester.tapAt(size.center(Offset.zero));
  await tester.pump(const Duration(milliseconds: 400));
}

const _seasons = [
  LiveChannel(name: 'Adanalı S01E01', number: 1, category: 'Diziler', streams: ['http://o/s1e1.mkv']),
  LiveChannel(name: 'Adanalı S02E03 Kan Davası', number: 2, category: 'Diziler', streams: ['http://o/s2e3.mkv']),
  LiveChannel(name: 'Adanalı S02E04', number: 3, category: 'Diziler', streams: ['http://o/s2e4.mkv']),
];

void main() {
  test('bitiş saati kalan süre ve hızdan', () {
    final now = DateTime(2026, 11, 6, 20, 45);
    expect(EndTimeLabel.format(now, const Duration(minutes: 95), 1), '22:20');
    expect(EndTimeLabel.format(now, const Duration(minutes: 30), 1.5), '21:05');
  });

  testWidgets('TV film: bitiş saati, hız, ses paneli; duraklatınca Baştan başla', (tester) async {
    final key = GlobalKey();
    final e = await _open(tester, f: FormFactor.tv, size: const Size(960, 540), mode: PlayerMode.film, boundary: key);
    e.setDuration(const Duration(minutes: 90), at: const Duration(minutes: 33));
    await tester.pump(PlayerPage.announceDuration);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Bitiş '), findsOneWidget);
    expect(find.text('Bölümler'), findsNothing);
    expect(find.text('Baştan başla'), findsNothing);
    await maybeSnapshot(tester, key, 'build/oynatici/tv-film.png', pixelRatio: 2);
    await tester.tap(find.text('Hız 1x'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('1,5x'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(e.rates, [1.5]);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Baştan başla'), findsOneWidget);
    await maybeSnapshot(tester, key, 'build/oynatici/tv-film-duraklat.png', pixelRatio: 2);
    await tester.tap(find.text('Baştan başla'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(e.seeks.last, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('TV dizi: sezon sekmeleri bölümleri süzer; Bölümler düğmesi şeridi açar', (tester) async {
    final key = GlobalKey();
    final e = await _open(
      tester,
      f: FormFactor.tv,
      size: const Size(960, 540),
      mode: PlayerMode.series,
      channels: _seasons,
      boundary: key,
    );
    e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
    await tester.pump(PlayerPage.announceDuration);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Bölümler'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sezon 1'), findsOneWidget);
    expect(find.text('Sezon 2'), findsOneWidget);
    expect(find.text('B1 · oynatılıyor'), findsOneWidget);
    expect(find.text('B3'), findsNothing, reason: 'açılışta oynayanın sezonu: S1');
    await tester.tap(find.text('Sezon 2'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('B1 · oynatılıyor'), findsNothing);
    expect(find.text('B3'), findsOneWidget);
    await maybeSnapshot(tester, key, 'build/oynatici/tv-dizi-serit.png', pixelRatio: 2);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('TV dizi: sonraki bölüm kartı odakta gelir, Geri iptal eder, oynatıcıyı kapatmaz', (tester) async {
    final key = GlobalKey();
    final e = await _open(tester, f: FormFactor.tv, size: const Size(960, 540), mode: PlayerMode.series, boundary: key);
    e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
    await tester.pump(PlayerPage.announceDuration);
    await tester.pump(const Duration(milliseconds: 400));
    await e.seek(const Duration(minutes: 44, seconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NextEpisodeCard), findsOneWidget);
    await maybeSnapshot(tester, key, 'build/oynatici/tv-sonraki.png', pixelRatio: 2);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NextEpisodeCard), findsNothing);
    expect(find.byType(PlayerPage), findsOneWidget);

    await e.seek(const Duration(minutes: 30));
    await tester.pump();
    await e.seek(const Duration(minutes: 44, seconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(e.opened.last, 'http://o/s2e4.mkv', reason: 'OK: Şimdi oynat');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 10));
  });

  test('sonraki bölüm sayacı: son saniyeler, iptal, geri sarma, önceki bölümden taşma', () {
    final c = NextEpisodeCountdown();
    expect(
      c.update(const Duration(seconds: 5)),
      isNull,
      reason: 'bölüm sonundan açılmış: önce sınırın gerisi görülmeli',
    );
    expect(c.update(const Duration(seconds: 16)), isNull);
    expect(c.update(const Duration(seconds: 15)), 12);
    expect(c.update(const Duration(seconds: 3)), 0);
    c.cancel();
    expect(c.update(const Duration(seconds: 10)), isNull);
    expect(c.update(const Duration(minutes: 1)), isNull);
    expect(c.update(const Duration(seconds: 10)), 7, reason: 'geri sarınca iptal kalkar');
    c.reset();
    expect(c.update(const Duration(seconds: 10)), isNull);
  });

  group('dokunmatik film/dizi', () {
    const phone = Size(844, 390);

    testWidgets('dizide yatay kaydırma bölüm atlamaz, gidilecek zamanı gösterip sarar', (tester) async {
      final e = await _series(tester);
      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveBy(Offset(phone.width / 2, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(find.textContaining('+1:0'), findsOneWidget);
      expect(find.textContaining('21:0'), findsOneWidget);
      expect(e.seeks, isEmpty, reason: 'bırakınca sarar');
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(e.seeks.single.inSeconds, inInclusiveRange(20 * 60 + 60, 20 * 60 + 62));
      expect(e.opened, ['http://o/s2e3.mkv']);
    });

    testWidgets('Ses ve altyazı tek panelde; seçince panel açık kalır', (tester) async {
      final e = await _series(tester);
      await _tapCenter(tester, phone);
      await tester.tap(find.bySemanticsLabel('Ses ve altyazı'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChoicePanel), findsOneWidget);
      await maybeSnapshot(tester, _shots, 'build/oynatici/ses-altyazi.png');
      await tester.tap(find.text('English'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(e.audioSelections, ['2']);
      await tester.tap(find.text('Türkçe').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(e.subtitleSelections, ['1']);
      expect(find.byType(ChoicePanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(ChoicePanel), findsOneWidget, reason: 'panel açıkken katman kapanmaz');
    });

    for (final (f, size) in const [(FormFactor.phone, Size(844, 390)), (FormFactor.tablet, Size(1280, 800))]) {
      testWidgets('${f.name}: Bölümler panelinden bölüm açılır', (tester) async {
        final e = await _series(tester, f: f, size: size);
        await _tapCenter(tester, size);
        await tester.tap(find.text('Bölümler'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(EpisodePanel), findsOneWidget);
        expect(find.text('B3 · oynatılıyor'), findsOneWidget);
        expect(find.text('−25:00'), findsOneWidget, reason: 'sağda kalan süre');
        await maybeSnapshot(tester, _shots, 'build/oynatici/bolumler-${f.name}.png');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('B4'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(EpisodePanel), findsNothing);
        expect(e.opened.last, 'http://o/s2e4.mkv');
      });
    }

    testWidgets('filmde Bölümler yok; hız seçilir', (tester) async {
      final e = await _open(tester, f: FormFactor.phone, size: phone, mode: PlayerMode.film);
      e.setDuration(const Duration(minutes: 90));
      await tester.pump(PlayerPage.announceDuration);
      await tester.pump(const Duration(milliseconds: 400));
      await _tapCenter(tester, phone);
      expect(find.text('Bölümler'), findsNothing);
      await tester.tap(find.text('Hız 1x'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('1,25x'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(e.rates, [1.25]);
      expect(find.text('Hız 1,25x'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kilit: dokunma ve kaydırma işlemez, Geri çıkmaz, Kilidi aç açar', (tester) async {
      final e = await _series(tester);
      await _tapCenter(tester, phone);
      await tester.tap(find.text('Kilit'));
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(VodTouchControls), findsNothing);
      expect(find.text('Kilidi aç'), findsNothing);

      final gesture = await tester.startGesture(const Offset(200, 200));
      await gesture.moveBy(const Offset(400, 0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(e.seeks, isEmpty);
      expect(find.byType(VodTouchControls), findsNothing);

      await tester.tapAt(const Offset(400, 200));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kilidi aç'), findsOneWidget);
      await tester.tap(find.text('Kilidi aç'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VodTouchControls), findsOneWidget);
    });

    testWidgets('bölüm biterken kart: geri sayım, İptal, süresi dolunca sonraki bölüm', (tester) async {
      final e = await _series(tester);
      expect(find.byType(NextEpisodeCard), findsNothing);
      await e.seek(const Duration(minutes: 44, seconds: 50));
      await tester.pump();
      expect(find.text('7 sn sonra'), findsOneWidget);
      await maybeSnapshot(tester, _shots, 'build/oynatici/sonraki-kart.png');
      await tester.tap(find.text('İptal'));
      await tester.pump();
      expect(find.byType(NextEpisodeCard), findsNothing);
      await e.seek(const Duration(minutes: 44, seconds: 55));
      await tester.pump();
      expect(find.byType(NextEpisodeCard), findsNothing, reason: 'iptal edildi');

      await e.seek(const Duration(minutes: 30));
      await tester.pump();
      await e.seek(const Duration(minutes: 44, seconds: 50));
      await tester.pump();
      expect(find.byType(NextEpisodeCard), findsOneWidget);
      await e.seek(const Duration(minutes: 44, seconds: 58));
      await tester.pump(const Duration(milliseconds: 400));
      expect(e.opened.last, 'http://o/s2e4.mkv');
      expect(find.byType(NextEpisodeCard), findsNothing);
    });

    testWidgets('filmde ve son bölümde sonraki bölüm kartı yok', (tester) async {
      final e = await _open(
        tester,
        f: FormFactor.phone,
        size: phone,
        mode: PlayerMode.series,
        channels: [_episodes.first],
      );
      e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
      await tester.pump();
      await e.seek(const Duration(minutes: 44, seconds: 50));
      await tester.pump();
      expect(find.byType(NextEpisodeCard), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('duraklatınca afiş ve özet; dar ekranda çıkmaz', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tmdb = Tmdb(
        token: 'x',
        fetch: (uri, _) async => utf8.encode(
          jsonEncode({
            'results': [
              {'id': 7, 'name': 'Adanalı', 'overview': 'Bir dedektif dizisi.', 'vote_average': 7.6},
            ],
          }),
        ),
      );
      final e = await _open(tester, f: FormFactor.phone, size: phone, mode: PlayerMode.series, tmdb: tmdb);
      e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
      await tester.pump(PlayerPage.announceDuration);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Bir dedektif dizisi.'), findsNothing);
      await e.playOrPause();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Bir dedektif dizisi.'), findsOneWidget);
      expect(find.text('7.6 TMDB'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.text('Bir dedektif dizisi.'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });
  });

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

  testWidgets('masaüstü: çubuk açıkken ok tuşları sarar, Enter ve Boşluk duraklatır', (tester) async {
    final e = await _open(tester, f: FormFactor.desktop, size: const Size(1280, 720), mode: PlayerMode.film);
    e.showVideo();
    e.setDuration(const Duration(minutes: 90));
    await tester.pump();
    expect(find.byType(VodTouchControls), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(e.seeks, isNotEmpty);
    final playing = e.state.value.playing;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(e.state.value.playing, !playing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(e.state.value.playing, playing);
    await tester.pump(const Duration(seconds: 10));
  });

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
    // Oynat'tan sağa: 10 sn ileri, Ses ve altyazı, Hız, Seçenekler (odak köke kaçmaz).
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Uyku zamanlayıcı'), findsWidgets, reason: 'Seçenekler paneli açıldı');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await tester.pump(const Duration(milliseconds: 400));
    expect(e.opened, ['http://f/1'], reason: 'filmde ▲▼ kanal değiştirmez');
    await tester.pumpWidget(const SizedBox());
    expect(progress.resumeAt('http://f/1'), const Duration(minutes: 33));
  });

  testWidgets('TV dizi: ▲ bölüm şeridi (odak sıradakinde), OK bölümü açar, ▼ kapatır; duraklatınca afiş ve özet', (
    tester,
  ) async {
    final progress = WatchProgress()
      ..record(
        _episodes[0],
        position: const Duration(minutes: 20),
        duration: const Duration(minutes: 45),
        series: true,
      );
    final key = GlobalKey();
    SharedPreferences.setMockInitialValues({});
    final tmdb = Tmdb(
      token: 'x',
      fetch: (uri, _) async => utf8.encode(
        jsonEncode({
          'results': [
            {'id': 7, 'name': 'Adanalı', 'overview': 'Bir dedektif dizisi.', 'vote_average': 7.6},
          ],
        }),
      ),
    );
    final e = await _open(
      tester,
      f: FormFactor.tv,
      size: const Size(960, 540),
      mode: PlayerMode.series,
      progress: progress,
      boundary: key,
      tmdb: tmdb,
    );
    e.setDuration(const Duration(minutes: 45), at: const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 5));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EpisodeStrip), findsOneWidget);
    expect(find.byType(VodBar), findsOneWidget);
    expect(find.text('B3 · oynatılıyor'), findsOneWidget);
    expect(e.opened, ['http://o/s2e3.mkv'], reason: '▲ bölüm değiştirmez, şeridi açar');
    expect(tester.takeException(), isNull);
    await maybeSnapshot(tester, key, 'build/oynatici/dizi-serit-tv.png');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EpisodeStrip), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EpisodeStrip), findsNothing);
    expect(e.opened.last, 'http://o/s2e4.mkv');

    // Duraklat: solda afiş, ad, puan ve özet.
    await tester.pump(PlayerPage.announceDuration);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(VodInfo), findsNothing, reason: 'oynarken çubuk kapalıyken bilgi yok');
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(VodInfo), findsOneWidget);
    expect(find.text('Bir dedektif dizisi.'), findsOneWidget);
    expect(find.textContaining('7.6 TMDB', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await maybeSnapshot(tester, key, 'build/oynatici/dizi-duraklat-tv.png');
    await tester.pump(const Duration(seconds: 20));
  });
}
