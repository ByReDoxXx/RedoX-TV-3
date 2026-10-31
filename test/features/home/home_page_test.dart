import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/home/home_page.dart';

import '../../support/render.dart';

Widget _app(Key boundary, {bool previewFocus = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: RedoxTheme.dark(),
  home: RepaintBoundary(
    key: boundary,
    child: HomePage(content: HomeContent.preview, previewFocus: previewFocus),
  ),
);

/// Anasayfa, Android TV tuvalinde (960×540 dp) çizilir.
/// REDOX_SNAPSHOT=1: build/home/anasayfa-4k.png (ilk ekran, 4x = 3840×2160)
/// ve build/home/anasayfa-tam.png (tüm sayfa, 2x).
void main() {
  testWidgets('TV ilk ekranı taşmasız çizilir (4K görüntü)', (tester) => withRealShadows(() async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(_app(key, previewFocus: true));
    await settleAssets(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Şampiyonlar Ligi — Çeyrek Final'), findsOneWidget);
    await maybeSnapshot(tester, key, 'build/home/anasayfa-4k.png', pixelRatio: 4);
  }));

  testWidgets('tüm sayfa taşmasız çizilir', (tester) => withRealShadows(() async {
    await loadSora(tester);
    // Kaydırmasız tam boy: TV genişliği, içerik yüksekliği kadar uzun görünüm.
    tester.view.physicalSize = const Size(960, 1560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(_app(key, previewFocus: true));
    await settleAssets(tester);

    expect(tester.takeException(), isNull);
    for (final title in ['Son izlenen kanallar', 'İzlemeye devam et', 'Son dinlenen radyolar', 'Son izlenen filmler']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    await maybeSnapshot(tester, key, 'build/home/anasayfa-tam.png', pixelRatio: 2);
  }));

  testWidgets('menü üstüne gelince açılır, ayrılınca kapanır', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GlobalKey()));
    await settleAssets(tester, rounds: 2);

    final rail = find.descendant(of: find.byType(RedoxNavRail), matching: find.byType(AnimatedContainer)).first;
    double railWidth() => tester.getSize(rail).width;
    expect(railWidth(), RedoxNavRail.collapsedWidth);

    // Sayfada sonsuz nabız animasyonu var: pumpAndSettle yerine açılış süresinden
    // uzun sabit adım (ray 400 ms).
    Future<void> settleRail() => tester.pump(const Duration(milliseconds: 600));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 300));
    await mouse.moveTo(const Offset(40, 270));
    await tester.pump();
    await settleRail();
    expect(railWidth(), RedoxNavRail.expandedWidth);

    await mouse.moveTo(const Offset(700, 300));
    await tester.pump();
    await settleRail();
    expect(railWidth(), RedoxNavRail.collapsedWidth);
  });
}
