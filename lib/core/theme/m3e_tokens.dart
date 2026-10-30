import 'package:flutter/animation.dart' show Cubic;
import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart' show SpringDescription;

// Material 3 Expressive belirteçleri.
// Kaynak: androidx.compose.material3 tokens (ShapeTokens, MotionTokens,
// ExpressiveMotionTokens, TypeScaleTokens). Değerler kaynaktan okundu;
// test/core/theme/m3e_tokens_test.dart bu değerleri kilitler.

/// Köşe yarıçapı ölçeği (dp / mantıksal piksel).
abstract final class M3EShape {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double largeIncreased = 20; // Expressive
  static const double extraLarge = 28;
  static const double extraLargeIncreased = 32; // Expressive
  static const double extraExtraLarge = 48; // Expressive

  /// "Full" (tam yuvarlak): yüksekliğin yarısından büyük herhangi bir değer.
  static const double full = 999;
}

/// Hareket: uzamsal (spatial) yaylar hafif aşım yapar, etki (effects) yayları yapmaz.
/// Compose yayı kütle=1 varsayar; Flutter'a mass: 1 ile birebir eşlenir.
abstract final class M3EMotion {
  static final spatialFast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );
  static final spatialDefault = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );
  static final spatialSlow = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 200,
    ratio: 0.8,
  );
  static final effectsFast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 3800,
  );
  static final effectsDefault = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1600,
  );
  static final effectsSlow = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
  );

  // Süre belirteçleri (ms).
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
  static const long3 = Duration(milliseconds: 550);
  static const long4 = Duration(milliseconds: 600);
  static const extraLong1 = Duration(milliseconds: 700);

  // Eğriler.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
}

TextStyle _t(double size, double line, double tracking, FontWeight w) =>
    TextStyle(
      fontSize: size,
      height: line / size,
      letterSpacing: tracking,
      fontWeight: w,
    );

/// Yazı ölçeği. Yazı tipi ailesi burada verilmez: tema, ailesini yazı tipi
/// pakete eklenince (Google Sans Flex) tek yerden uygular.
abstract final class M3EType {
  static const _r = FontWeight.w400;
  static const _m = FontWeight.w500;
  static const _b = FontWeight.w700;

  /// Baz ölçek (boyut / satır yüksekliği / izleme / ağırlık).
  static final TextTheme baseline = TextTheme(
    displayLarge: _t(57, 64, -0.2, _r),
    displayMedium: _t(45, 52, 0, _r),
    displaySmall: _t(36, 44, 0, _r),
    headlineLarge: _t(32, 40, 0, _r),
    headlineMedium: _t(28, 36, 0, _r),
    headlineSmall: _t(24, 32, 0, _r),
    titleLarge: _t(22, 28, 0, _r),
    titleMedium: _t(16, 24, 0.2, _m),
    titleSmall: _t(14, 20, 0.1, _m),
    labelLarge: _t(14, 20, 0.1, _m),
    labelMedium: _t(12, 16, 0.5, _m),
    labelSmall: _t(11, 16, 0.5, _m),
    bodyLarge: _t(16, 24, 0.5, _r),
    bodyMedium: _t(14, 20, 0.2, _r),
    bodySmall: _t(12, 16, 0.4, _r),
  );

  /// Vurgulu (emphasized) stiller: aynı boyutlar, daha kalın ağırlık.
  static final TextTheme emphasized = TextTheme(
    displayLarge: _t(57, 64, 0, _m),
    displayMedium: _t(45, 52, 0, _m),
    displaySmall: _t(36, 44, 0, _m),
    headlineLarge: _t(32, 40, 0, _m),
    headlineMedium: _t(28, 36, 0, _m),
    headlineSmall: _t(24, 32, 0, _m),
    titleLarge: _t(22, 28, 0, _m),
    titleMedium: _t(16, 24, 0.15, _b),
    titleSmall: _t(14, 20, 0.1, _b),
    labelLarge: _t(14, 20, 0.1, _b),
    labelMedium: _t(12, 16, 0.5, _b),
    labelSmall: _t(11, 16, 0.5, _b),
    bodyLarge: _t(16, 24, 0.15, _m),
    bodyMedium: _t(14, 20, 0.25, _m),
    bodySmall: _t(12, 16, 0.4, _m),
  );

  /// Sabit genişlikli rakam: kanal numarası, saat, EPG saatleri (yazı tipinin `tnum`'u).
  static const tabularFigures = [FontFeature.tabularFigures()];
}
