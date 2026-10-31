import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';
import 'package:redox_tv/features/style_guide/style_guide_page.dart';

import '../../support/render.dart';

/// Stil rehberini cihazsız, TV ölçeğinde (960 dp genişlik) çizer.
/// REDOX_SNAPSHOT=1: build/style_guide/stil-rehberi.png (2x, 1920 px genişlik).
void main() {
  testWidgets('stil rehberi hatasız çizilir', (tester) => withRealShadows(() async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RedoxTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(key: boundaryKey, child: const StyleGuideContent()),
          ),
        ),
      ),
    );
    await settleAssets(tester);

    expect(tester.takeException(), isNull);
    for (final title in ['Renk', 'Yazı', 'İkon', 'Şekil, boşluk, derinlik', 'Kontroller', 'Kartlar ve gezinme', 'Logo']) {
      expect(find.textContaining(title), findsWidgets, reason: title);
    }
    // Her ikon için boşta, seçili ve odakta kopya.
    expect(find.byType(RedoxIcon), findsAtLeastNWidgets(RedoxIcons.values.length * 3));

    await maybeSnapshot(tester, boundaryKey, 'build/style_guide/stil-rehberi.png', pixelRatio: 2);
  }));
}
