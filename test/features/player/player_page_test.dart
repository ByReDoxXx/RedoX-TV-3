import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/content/app_settings.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/platform/device_controls.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/playback/playback_session.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/player/widgets/channel_drawer.dart';
import 'package:redox_tv/features/player/widgets/player_bar.dart';
import 'package:redox_tv/features/player/widgets/player_options.dart';
import 'package:redox_tv/features/player/widgets/touch_controls.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

final _channels = TvContent.preview.channels;

/// Oynatıcı, boş bir sayfanın üstüne açılır (Geri ile çıkış sınansın diye).
Future<FakeEngine> _open(
  WidgetTester tester, {
  int index = 0,
  FakeEngine? engine,
  Key? boundary,
  FormFactor formFactor = FormFactor.tv,
  Size size = const Size(960, 540),
}) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final e = engine ?? FakeEngine();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: formFactor),
      // Görüntü sınırı gezgini sarar: oynatıcı üstüne açılan ayrı bir sayfadır.
      builder: (context, child) => RepaintBoundary(key: boundary, child: child),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PlayerPage(channels: _channels, initialIndex: index, clock: '20:45', engineFactory: () => e),
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await _settle(tester);
  return e;
}

// Nabız animasyonu sonsuz: pumpAndSettle yerine sabit adımlar; ilk kare
// ayrı (yeni rota ilk karede sahne dışıdır).
Future<void> _settle(WidgetTester tester, [Duration d = const Duration(milliseconds: 400)]) async {
  await tester.pump();
  await tester.pump(d);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

PlayerBar _bar(WidgetTester tester) => tester.widget<PlayerBar>(find.byType(PlayerBar));

void main() {
  testWidgets('açılış: ilk akış oynar; çubuk ve ipuçları 3,8 sn görünür, sonra kapanır', (tester) async {
    final e = await _open(tester);
    expect(e.opened, [_channels.first.streams.first]);
    expect(find.byType(PlayerHints), findsOneWidget);
    expect(_bar(tester).channel, _channels.first);
    expect(_bar(tester).resolution, '720p');
    expect(find.text('20:45'), findsOneWidget);

    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    expect(find.byType(PlayerBar), findsNothing);
  });

  testWidgets('akış hata verirse sıradakine geçer; hepsi açılmazsa "Tekrar dene"', (tester) async {
    final e = FakeEngine()..failing.addAll(_channels.first.streams);
    await _open(tester, engine: e);
    expect(e.opened, _channels.first.streams);
    // Yedek akışa geçişten hemen sonraki hatalar eski akışın sayılır; yeni
    // akışı açılış süresi yakalar.
    expect(find.text('Tekrar dene'), findsNothing);
    await tester.pump(PlaybackSession.defaultStartupTimeout);
    await _settle(tester);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.textContaining('açılamadı'), findsOneWidget);

    // Açılamadı durumunda da ▲ kanal değiştirir.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _settle(tester);
    expect(_bar(tester).channel, _channels[1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await _settle(tester);
    await tester.pump(PlaybackSession.defaultStartupTimeout);
    await _settle(tester);

    e.failing.clear();
    await tester.tap(find.text('Tekrar dene'));
    await _settle(tester);
    expect(e.opened.last, _channels.first.streams.first);
    expect(find.text('Tekrar dene'), findsNothing);
  });

  testWidgets('bozuk ilk akışın geç gelen ikinci hatası yedek akışı düşürmez (emülatörde görülen)', (tester) async {
    final ulusal2 = _channels.indexWhere((c) => c.number == 2);
    final e = FakeEngine()..failing.add(_channels[ulusal2].streams.first);
    await _open(tester, index: ulusal2, engine: e);
    expect(e.opened, _channels[ulusal2].streams);
    expect(_bar(tester).streamIndex, 1);
    expect(find.text('Tekrar dene'), findsNothing);
    expect(_bar(tester).resolution, '720p');
    await tester.pump(PlaybackSession.defaultStartupTimeout);
  });

  testWidgets('görüntü süresinde gelmezse yedek akışa geçilir', (tester) async {
    final e = FakeEngine()..autoVideo = false;
    await _open(tester, engine: e);
    expect(e.opened.length, 1);
    await tester.pump(PlaybackSession.defaultStartupTimeout);
    await _settle(tester);
    expect(e.opened, _channels.first.streams);
    expect(_bar(tester).streamIndex, 1);
    e.showVideo();
    await _settle(tester);
    expect(find.text('Tekrar dene'), findsNothing);
    await tester.pump(PlaybackSession.defaultStartupTimeout);
  });

  testWidgets('▲▼ kanal değiştirir, ► sonraki akış, ◄ kanal listesi', (tester) async {
    final e = await _open(tester);
    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);

    await _key(tester, LogicalKeyboardKey.arrowUp);
    expect(_bar(tester).channel, _channels[1]);
    expect(e.opened.last, _channels[1].streams.first);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_bar(tester).channel, _channels.last, reason: 'baştan geri: sona döner');

    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_bar(tester).streamIndex, 1);
    expect(e.opened.last, _channels.last.streams[1]);

    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.byType(ChannelDrawer), findsOneWidget);
    await tester.tap(find.text(_channels[3].name));
    await _settle(tester);
    expect(find.byType(ChannelDrawer), findsNothing);
    expect(_bar(tester).channel, _channels[3]);
  });

  testWidgets('rakamlar kanal numarası; tek 0 önceki kanal; olmayan numara uyarı', (tester) async {
    final e = await _open(tester);
    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);

    for (final k in [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit0, LogicalKeyboardKey.digit4]) {
      await _key(tester, k);
    }
    expect(find.text('104'), findsOneWidget);
    await tester.pump(PlayerPage.digitTimeout);
    await _settle(tester);
    expect(_bar(tester).channel.number, 104);
    expect(e.opened.last, _channels.firstWhere((c) => c.number == 104).streams.first);

    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.digit0);
    expect(_bar(tester).channel, _channels.first);

    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    await _key(tester, LogicalKeyboardKey.digit9);
    await tester.pump(PlayerPage.digitTimeout);
    await _settle(tester);
    expect(find.text('9 numaralı kanal yok'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("Menü tuşu Seçenekler'i açar", (tester) async {
    await _open(tester);
    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);
    expect(find.byType(PlayerOptions), findsNothing);
    await _key(tester, LogicalKeyboardKey.contextMenu);
    expect(find.byType(PlayerOptions), findsOneWidget);
  });

  testWidgets('OK çubuğu açar (odak oynat/duraklatta); Geri katmanları sırayla kapatır, sonra çıkar', (tester) async {
    final e = await _open(tester);
    await tester.pump(PlayerPage.announceDuration);
    await _settle(tester);

    await _key(tester, LogicalKeyboardKey.select);
    expect(find.byType(PlayerBar), findsOneWidget);
    expect(find.byType(PlayerHints), findsNothing);
    expect(find.text('Duraklat'), findsOneWidget, reason: 'odaktaki düğmenin adı');
    await _key(tester, LogicalKeyboardKey.select);
    expect(e.state.value.playing, isFalse);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(PlayerBar), findsNothing);
    expect(find.byType(PlayerPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    // Sayfa kapanış geçişi 400 ms'den uzun.
    await _settle(tester, const Duration(seconds: 1));
    expect(find.byType(PlayerPage), findsNothing);
    expect(e.disposed, isTrue);
  });

  testWidgets(
    'Seçenekler: kalite, ses, altyazı, ölçek seçilir; Geri alt listeden ana listeye (4K görüntü)',
    (tester) => withRealShadows(() async {
      final key = GlobalKey();
      final e = await _open(tester, boundary: key);
      await maybeSnapshot(tester, key, 'build/player/oynatici-cubuk-4k.png', pixelRatio: 4);

      await tester.tap(find.bySemanticsLabel('Seçenekler'));
      await _settle(tester);
      expect(find.byType(PlayerOptions), findsOneWidget);
      expect(find.text('1280×720 · Akış 1/2'), findsOneWidget);
      await maybeSnapshot(tester, key, 'build/player/oynatici-secenekler-4k.png', pixelRatio: 4);

      await tester.tap(find.text('Kalite'));
      await _settle(tester);
      await tester.tap(find.text('720p'));
      await _settle(tester);
      expect(e.videoSelections, ['2']);

      await tester.tap(find.text('Ses'));
      await _settle(tester);
      await tester.tap(find.text('English'));
      await _settle(tester);
      expect(e.audioSelections, ['2']);

      await tester.tap(find.text('Altyazı'));
      await _settle(tester);
      await tester.tap(find.text('Türkçe'));
      await _settle(tester);
      expect(e.subtitleSelections, ['1']);

      await tester.tap(find.text('Ölçek'));
      await _settle(tester);
      await tester.tap(find.text('Ekranı doldur'));
      await _settle(tester);
      expect(find.text('Ekranı doldur'), findsOneWidget, reason: 'ana listede değer');

      await tester.tap(find.text('Kalite'));
      await _settle(tester);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('Oynatıcıdan çık'), findsOneWidget, reason: 'Geri: ana listeye');
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.byType(PlayerOptions), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(PlayerPage.barTimeout);
    }),
  );

  testWidgets(
    'kanal listesi 4K görüntü',
    (tester) => withRealShadows(() async {
      final key = GlobalKey();
      await _open(tester, index: 2, boundary: key);
      await tester.pump(PlayerPage.announceDuration);
      await _settle(tester);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/player/oynatici-kanal-listesi-4k.png', pixelRatio: 4);
    }),
  );

  group('dokunmatik (telefon, tablet)', () {
    setUp(() => DeviceControls.debugValues = {'ses': 0.5, 'parlaklik': 0.5});
    tearDown(() => DeviceControls.debugValues = null);

    Offset center(WidgetTester tester, String label) => tester.getCenter(find.bySemanticsLabel(label));

    testWidgets('kumanda çubuğu yok; düğmeler ortada, tuş ipucu yok', (tester) async {
      await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      expect(find.byType(PlayerBar), findsNothing);
      expect(find.byType(PlayerHints), findsNothing);
      expect(find.byType(TouchControls), findsOneWidget);
      final play = center(tester, 'Duraklat');
      expect(play.dx, closeTo(422, 1));
      expect(play.dy, closeTo(195, 40));
      expect(center(tester, 'Önceki kanal').dx, lessThan(play.dx));
      expect(center(tester, 'Sonraki kanal').dx, greaterThan(play.dx));
      expect(center(tester, 'Önceki kanal').dy, closeTo(play.dy, 1));
    });

    testWidgets('oynat/duraklat kızıl, koyu kırmızı 4 dp kenarlı', (tester) async {
      await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      final material = tester.widget<Material>(
        find.descendant(of: find.bySemanticsLabel('Duraklat'), matching: find.byType(Material)).first,
      );
      expect(material.color, RedoxRoles.primaryContainer);
      final side = (material.shape! as CircleBorder).side;
      expect((side.color, side.width), (RedoxRoles.onPrimaryFixedVariant, 4));
    });

    testWidgets('Seçenekler "Kapat" satırıyla ve dışına dokununca kapanır', (tester) async {
      await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      await tester.tap(find.bySemanticsLabel('Seçenekler'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlayerOptions), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(PlayerOptions), matching: find.text('Kapat')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlayerOptions), findsNothing);

      await tester.tap(find.bySemanticsLabel('Seçenekler'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(const Offset(60, 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PlayerOptions), findsNothing);
    });

    testWidgets('dokunma katmanı kapar/açar; yatay kaydırma kanal değiştirir', (tester) async {
      final e = await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      await tester.pump(PlayerPage.announceDuration);
      await _settle(tester);
      expect(find.byType(TouchControls), findsNothing);

      // Sola kaydırma: sonraki kanal.
      await tester.dragFrom(const Offset(600, 200), const Offset(-200, 0));
      await _settle(tester);
      expect(e.opened.last, _channels[1].streams.first);
      // Sağa: önceki (ortadaki durum kartının dışından).
      final before = e.opened.length;
      await tester.dragFrom(const Offset(300, 30), const Offset(200, 0));
      await _settle(tester);
      expect(e.opened.skip(before), contains(_channels[0].streams.first));
    });

    testWidgets('sağda dikey kaydırma ses, solda parlaklık; çift dokunma ekranı doldurur', (tester) async {
      await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      // Yukarı: artar (ekran yüksekliğinin %80'i tam aralık).
      await tester.dragFrom(const Offset(700, 300), const Offset(0, -156));
      await tester.pump();
      expect(DeviceControls.debugValues!['ses'], closeTo(1, 0.1));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.dragFrom(const Offset(150, 100), const Offset(0, 156));
      await tester.pump();
      expect(DeviceControls.debugValues!['parlaklik'], closeTo(0, 0.1));
      await tester.pump(const Duration(seconds: 1));

      await tester.tapAt(const Offset(250, 250));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(250, 250));
      await _settle(tester);
      expect(find.text(VideoScale.fill.label), findsWidgets);
    });

    testWidgets('Ayarlar › Dokunma hareketleri kapalı: kaydırma ses ve kanal değiştirmez', (tester) async {
      final previous = AppSettings.instance;
      AppSettings.instance = AppSettings(gestures: false);
      addTearDown(() => AppSettings.instance = previous);
      final before = Map.of(DeviceControls.debugValues!);
      final e = await _open(tester, formFactor: FormFactor.phone, size: const Size(844, 390));
      await tester.dragFrom(const Offset(700, 300), const Offset(0, -156));
      await tester.pump();
      expect(DeviceControls.debugValues!['ses'], before['ses']);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final opened = e.opened.length;
      await tester.dragFrom(const Offset(600, 200), const Offset(-300, 0));
      await _settle(tester);
      expect(e.opened.length, opened, reason: 'kanal değişmedi');
    });

    testWidgets('görüntü: telefon yatay ve açık Fold', (tester) async {
      await withRealShadows(() async {
        for (final (name, f, size) in [
          ('telefon', FormFactor.phone, const Size(844, 390)),
          ('fold', FormFactor.tablet, const Size(840, 800)),
        ]) {
          final key = GlobalKey();
          await _open(tester, formFactor: f, size: size, boundary: key);
          expect(tester.takeException(), isNull);
          await maybeSnapshot(tester, key, 'build/oynatici/dokunmatik-$name.png', pixelRatio: 2);
          await tester.pumpWidget(const SizedBox());
        }
      });
    });
  });
}
