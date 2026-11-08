import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/player/widgets/channel_drawer.dart';
import 'package:redox_tv/features/player/widgets/desktop_live_controls.dart';
import 'package:redox_tv/features/player/widgets/touch_controls.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

// Masaüstü canlı yayın oynatıcısı: ince alt çubuk, sağda kanal listesi,
// klavye kısayolları. Görüntüler build/desktop/.

void main() {
  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    testWidgets('masaüstü canlı yayın ${size.width.toInt()}: ince çubuk, liste, ses', (tester) async {
      await withRealShadows(() async {
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
              channels: TvContent.preview.channels,
              initialIndex: 0,
              clock: '20:45',
              engineFactory: () => e,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await settleAssets(tester, rounds: 3);

        expect(find.byType(DesktopLiveControls), findsOneWidget);
        expect(find.byType(TouchControls), findsNothing, reason: 'masaüstünde dokunmatik denetim yok');
        final bar = tester.getRect(
          find.descendant(of: find.byType(DesktopLiveControls), matching: find.byType(Container)).last,
        );
        expect(bar.height, lessThanOrEqualTo(DesktopLiveControls.barHeight));
        expect(tester.takeException(), isNull);
        final w = size.width.toInt();
        await maybeSnapshot(tester, key, 'build/desktop/oynatici-canli-$w.png');

        // L: kanal listesi sağda açılır, çubuk görünür kalır.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump();
        await settleAssets(tester, rounds: 2);
        expect(find.byType(ChannelDrawer), findsOneWidget);
        expect(find.byType(DesktopLiveControls), findsOneWidget);
        expect(tester.getRect(find.byType(ChannelDrawer)).right, greaterThan(size.width / 2));
        expect(tester.takeException(), isNull);
        await maybeSnapshot(tester, key, 'build/desktop/oynatici-canli-liste-$w.png');
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump();
        expect(find.byType(ChannelDrawer), findsNothing);

        // M: sessiz; ses kaydırıcısı düzeyi değiştirir ve sesi açar.
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.pump();
        expect(e.audio.value.muted, isTrue);
        await tester.tap(find.byType(Slider));
        await tester.pump();
        expect(e.audio.value.muted, isFalse);
        expect(e.audio.value.level, closeTo(0.5, 0.1));

        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
