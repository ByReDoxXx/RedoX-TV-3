import 'package:flutter/animation.dart' show Cubic;
import 'package:flutter/physics.dart' show SpringDescription;

// Material 3 Expressive hareket belirteçleri.
// Kaynak: androidx.compose.material3 tokens (MotionTokens, ExpressiveMotionTokens).
// Değerler kaynaktan okundu; test/core/theme/m3e_motion_test.dart kilitler.
// Şekil ve yazı ölçeği DESIGN.md'den gelir (redox_shapes.dart, redox_type.dart).

/// Uzamsal (spatial) yaylar hafif aşım yapar, etki (effects) yayları yapmaz.
/// Compose yayı kütle=1 varsayar; Flutter'a mass: 1 ile birebir eşlenir.
abstract final class M3EMotion {
  static final spatialFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);
  static final spatialDefault = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.8);
  static final spatialSlow = SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);
  static final effectsFast = SpringDescription.withDampingRatio(mass: 1, stiffness: 3800);
  static final effectsDefault = SpringDescription.withDampingRatio(mass: 1, stiffness: 1600);
  static final effectsSlow = SpringDescription.withDampingRatio(mass: 1, stiffness: 800);

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

  // Eğriler. DESIGN.md ray açılışı için cubic-bezier(0.2, 0, 0, 1) verir = standard.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
}
