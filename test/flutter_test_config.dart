import 'dart:async';

import 'package:flutter/widgets.dart';

/// Testlerin ekran görüntülerinde (belgelerde de kullanılır) DEBUG şeridi çıkmaz.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetsApp.debugAllowBannerOverride = false;
  await testMain();
}
