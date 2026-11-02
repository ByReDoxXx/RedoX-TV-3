import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/ui/animated_brand_logo.dart';

import '../../support/render.dart';

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(size: const Size(960, 540), disableAnimations: still),
    child: Scaffold(
      backgroundColor: const Color(0xFF0B0B20),
      body: Center(child: child),
    ),
  ),
);

double _opacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.descendant(of: find.byType(AnimatedBrandLogo), matching: find.byType(Opacity))).opacity;

void main() {
  testWidgets('giriş: yayla belirir; sonra nefes ve kıvılcımlar döngüde sürer', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: _app(const AnimatedBrandLogo(height: 360))));
    await tester.runAsync(
      () => precacheImage(const AssetImage('assets/brand/redox-logo-saydam.png'), key.currentContext!),
    );
    expect(_opacity(tester), lessThan(0.2));
    for (final (ms, name) in const [(120, '1-giris'), (500, '2-giris'), (2000, '3-nefes'), (2000, '4-nefes')]) {
      await tester.pump(Duration(milliseconds: ms));
      await maybeSnapshot(tester, key, 'build/logo/$name.png');
    }
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'döngü sürer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('hareketi azalt açıksa durağan logo', (tester) async {
    await tester.pumpWidget(_app(const AnimatedBrandLogo(height: 200), still: true));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });
}
