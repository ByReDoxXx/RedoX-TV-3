import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart' show SpringDescription;
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/m3e_tokens.dart';

/// Değerler androidx.compose.material3 token kaynağından okunmuştur.
void main() {
  test('şekil ölçeği (Expressive artışlı basamaklar dahil)', () {
    expect(
      [
        M3EShape.none,
        M3EShape.extraSmall,
        M3EShape.small,
        M3EShape.medium,
        M3EShape.large,
        M3EShape.largeIncreased,
        M3EShape.extraLarge,
        M3EShape.extraLargeIncreased,
        M3EShape.extraExtraLarge,
      ],
      [0, 4, 8, 12, 16, 20, 28, 32, 48],
    );
  });

  test('uzamsal yaylar hafif aşım yapar, etki yayları yapmaz', () {
    for (final s in [M3EMotion.spatialFast, M3EMotion.spatialDefault, M3EMotion.spatialSlow]) {
      expect(s.damping / (2 * _sqrt(s.mass * s.stiffness)), lessThan(1.0));
    }
    for (final s in [M3EMotion.effectsFast, M3EMotion.effectsDefault, M3EMotion.effectsSlow]) {
      expect(s.damping / (2 * _sqrt(s.mass * s.stiffness)), closeTo(1.0, 1e-9));
    }
  });

  test('yay sertlikleri ve sönümleme oranları resmi tokenlarla aynı', () {
    double ratio(SpringDescription s) =>
        s.damping / (2 * _sqrt(s.mass * s.stiffness));
    expect(M3EMotion.spatialDefault.stiffness, 380);
    expect(ratio(M3EMotion.spatialDefault), closeTo(0.8, 1e-9));
    expect(M3EMotion.spatialFast.stiffness, 800);
    expect(ratio(M3EMotion.spatialFast), closeTo(0.6, 1e-9));
    expect(M3EMotion.spatialSlow.stiffness, 200);
    expect(M3EMotion.effectsDefault.stiffness, 1600);
    expect(M3EMotion.effectsFast.stiffness, 3800);
    expect(M3EMotion.effectsSlow.stiffness, 800);
  });

  test('baz yazı ölçeği: örnek satırlar', () {
    final t = M3EType.baseline;
    expect(t.displayLarge!.fontSize, 57);
    expect(t.displayLarge!.height, closeTo(64 / 57, 1e-9));
    expect(t.titleMedium!.fontWeight, FontWeight.w500);
    expect(t.bodyLarge!.fontSize, 16);
    expect(t.labelSmall!.fontSize, 11);
  });

  test('vurgulu ölçek: aynı boyut, daha kalın ağırlık', () {
    final b = M3EType.baseline, e = M3EType.emphasized;
    expect(e.titleMedium!.fontSize, b.titleMedium!.fontSize);
    expect(e.titleMedium!.fontWeight, FontWeight.w700);
    expect(e.labelLarge!.fontWeight, FontWeight.w700);
    expect(e.bodyLarge!.fontWeight, FontWeight.w500);
    expect(e.displayLarge!.fontWeight, FontWeight.w500);
  });
}

double _sqrt(double x) => math.sqrt(x);
