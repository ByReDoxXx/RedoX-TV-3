import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

/// Cihaz biçimi. Ölçüler (yazı alt sınırı, odak büyümesi, kenar boşluğu)
/// buna göre seçilir; bkz. RedoxMetrics.
///
/// Android'de televizyon, tablet ve telefon ayrı APK'lardır; biçim derleme
/// anında flavor'dan gelir (`flutter build apk --flavor tv|tablet|phone`,
/// android/app/build.gradle.kts). Masaüstü derlemeleri flavor'sızdır.
enum FormFactor {
  phone,
  tablet,
  desktop,
  tv;

  /// Bu derlemenin biçimi.
  static FormFactor get current => resolve(appFlavor, defaultTargetPlatform);

  /// Flavor adı Android productFlavors adlarıyla aynıdır. Flavor yoksa
  /// masaüstü platformları masaüstü, diğerleri telefon sayılır.
  @visibleForTesting
  static FormFactor resolve(String? flavor, TargetPlatform platform) => switch (flavor) {
    'tv' => FormFactor.tv,
    'tablet' => FormFactor.tablet,
    'phone' => FormFactor.phone,
    _ => switch (platform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => FormFactor.desktop,
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => FormFactor.phone,
    },
  };
}
