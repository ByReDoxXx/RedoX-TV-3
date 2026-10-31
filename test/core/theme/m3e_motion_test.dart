import 'dart:math' as math;

import 'package:flutter/physics.dart' show SpringDescription;
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/m3e_motion.dart';

/// Değerler androidx.compose.material3 token kaynağından okunmuştur.
void main() {
  double ratio(SpringDescription s) => s.damping / (2 * math.sqrt(s.mass * s.stiffness));

  test('uzamsal yaylar hafif aşım yapar, etki yayları yapmaz', () {
    for (final s in [M3EMotion.spatialFast, M3EMotion.spatialDefault, M3EMotion.spatialSlow]) {
      expect(ratio(s), lessThan(1.0));
    }
    for (final s in [M3EMotion.effectsFast, M3EMotion.effectsDefault, M3EMotion.effectsSlow]) {
      expect(ratio(s), closeTo(1.0, 1e-9));
    }
  });

  test('yay sertlikleri ve sönümleme oranları resmi tokenlarla aynı', () {
    expect(M3EMotion.spatialDefault.stiffness, 380);
    expect(ratio(M3EMotion.spatialDefault), closeTo(0.8, 1e-9));
    expect(M3EMotion.spatialFast.stiffness, 800);
    expect(ratio(M3EMotion.spatialFast), closeTo(0.6, 1e-9));
    expect(M3EMotion.spatialSlow.stiffness, 200);
    expect(M3EMotion.effectsDefault.stiffness, 1600);
    expect(M3EMotion.effectsFast.stiffness, 3800);
    expect(M3EMotion.effectsSlow.stiffness, 800);
  });

  test('ray açılış eğrisi DESIGN.md: cubic-bezier(0.2, 0, 0, 1)', () {
    const c = M3EMotion.standard;
    expect([c.a, c.b, c.c, c.d], [0.2, 0.0, 0.0, 1.0]);
  });
}
