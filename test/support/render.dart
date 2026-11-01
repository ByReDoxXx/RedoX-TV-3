import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_type.dart';

/// Sora'yı test ortamına yükler (yüklenmezse metin Ahem kutularıyla çizilir).
Future<void> loadSora(WidgetTester tester) async {
  await tester.runAsync(() async {
    final loader = FontLoader(RedoxType.family)..addFont(rootBundle.load('assets/fonts/Sora-Variable.ttf'));
    await loader.load();
  });
}

/// SVG'ler eşzamansız yüklenir: gerçek zamanda bekleyip yeniden çizer.
Future<void> settleAssets(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

bool get _snapshotEnabled => Platform.environment['REDOX_SNAPSHOT'] == '1';

/// Flutter testleri gölgeleri bulanıksız düz blok çizer (debugDisableShadows,
/// golden kararlılığı için). Görüntü alınırken gerçek bulanıklık açılır ve
/// gövde bitince eski değer geri yüklenir (binding test sonunda bunu denetler).
Future<void> withRealShadows(Future<void> Function() body) async {
  final previous = debugDisableShadows;
  if (_snapshotEnabled) debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = previous;
  }
}

/// REDOX_SNAPSHOT=1 verilirse sınırın görüntüsünü PNG olarak yazar.
/// Görüntü platforma göre piksel farkı gösterebileceği için karşılaştırma yapılmaz.
Future<void> maybeSnapshot(WidgetTester tester, GlobalKey key, String path, {double pixelRatio = 1}) async {
  if (!_snapshotEnabled) return;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
