import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_type.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';
import 'package:redox_tv/features/style_guide/style_guide_page.dart';

/// Stil rehberini cihazsız çizer.
/// REDOX_SNAPSHOT=1 verilirse build/style_guide/stil-rehberi.png dosyasını yazar
/// (görüntü platforma göre piksel farkı gösterebileceği için karşılaştırma yapılmaz).
void main() {
  testWidgets('stil rehberi hatasız çizilir', (tester) async {
    await tester.runAsync(() async {
      final loader = FontLoader(RedoxType.family)
        ..addFont(rootBundle.load('assets/fonts/GoogleSansFlex.ttf'));
      await loader.load();
    });
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RedoxTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: boundaryKey,
              child: const StyleGuideContent(),
            ),
          ),
        ),
      ),
    );

    // SVG'ler eşzamansız yüklenir: gerçek zamanda bekleyip yeniden çiz.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    for (final title in ['Renk paleti', 'Yazı tipi', 'İkon seti', 'Şekil', 'Bileşenler', 'Logo']) {
      expect(find.textContaining(title), findsWidgets, reason: title);
    }
    // Her ikon için boş ve iki dolu kopya.
    expect(find.byType(RedoxIcon), findsAtLeastNWidgets(RedoxIcons.values.length * 3));

    if (Platform.environment['REDOX_SNAPSHOT'] == '1') {
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/style_guide/stil-rehberi.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
