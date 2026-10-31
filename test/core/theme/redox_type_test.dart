import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_elevation.dart';
import 'package:redox_tv/core/theme/redox_metrics.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_type.dart';

void main() {
  group('Yazı ölçeği DESIGN.md ile aynı', () {
    // ad: [boyut, satır, ağırlık, izleme em]
    const spec = <String, List<num>>{
      'display-lg': [56, 64, 800, -0.02],
      'display-lg-mobile': [36, 44, 800, -0.02],
      'headline-lg': [32, 40, 700, -0.01],
      'headline-lg-mobile': [26, 32, 700, -0.01],
      'headline-md': [24, 30, 600, 0],
      'headline-sm': [20, 26, 600, 0],
      'title-lg': [18, 24, 600, 0.01],
      'title-md': [16, 22, 600, 0.01],
      'body-lg': [16, 24, 400, 0.01],
      'body-md': [14, 20, 400, 0.015],
      'body-sm': [12, 16, 400, 0.02],
      'label-lg': [14, 20, 600, 0.05],
      'label-md': [12, 16, 600, 0.04],
      'label-sm': [10, 14, 700, 0.06],
    };

    test('14 belirteç, hepsi Sora', () {
      expect(RedoxType.tokens.keys, spec.keys);
      for (final s in RedoxType.tokens.values) {
        expect(s.fontFamily, 'Sora');
      }
    });

    spec.forEach((name, v) {
      test(name, () {
        final s = RedoxType.tokens[name]!;
        expect(s.fontSize, v[0]);
        expect(s.fontSize! * s.height!, closeTo(v[1].toDouble(), 1e-9));
        expect(s.fontWeight!.value, v[2]);
        expect(s.letterSpacing, closeTo(v[3] * v[0], 1e-9));
      });
    });
  });

  group('Cihaz biçimi', () {
    test('TV: hiçbir tema yazısı 16 altında değil', () {
      final t = RedoxType.textTheme(FormFactor.tv);
      for (final s in [
        t.displayLarge, t.headlineLarge, t.headlineMedium, t.headlineSmall, t.titleLarge,
        t.titleMedium, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall,
      ]) {
        expect(s!.fontSize, greaterThanOrEqualTo(RedoxType.tvMinSize));
      }
      // Ağırlık ve em izleme korunur.
      expect(t.labelSmall!.fontWeight, FontWeight.w700);
      expect(t.labelSmall!.letterSpacing! / t.labelSmall!.fontSize!, closeTo(0.06, 1e-9));
    });

    test('telefon: -mobile belirteçleri', () {
      final t = RedoxType.textTheme(FormFactor.phone);
      expect(t.displayLarge, RedoxType.displayLgMobile);
      expect(t.headlineLarge, RedoxType.headlineLgMobile);
      expect(t.bodySmall!.fontSize, 12);
    });

    // TV: ikon düğmesi 40 (Compose TV IconButton), oluk 16 (kullanıcı isteği).
    test('ölçüler: TV odak 1.08, ikon düğmesi 40, oluk 16; masaüstü 1.04, 48, 24', () {
      final tv = RedoxTheme.dark().extension<RedoxMetrics>()!;
      expect([tv.focusScale, tv.iconButtonSize, tv.gutter, tv.margin.left], [1.08, 40, 16, 64]);
      final desk = RedoxTheme.dark(formFactor: FormFactor.desktop).extension<RedoxMetrics>()!;
      expect([desk.focusScale, desk.iconButtonSize, desk.gutter, desk.margin.left], [1.04, 48, 24, 40]);
    });
  });

  test('CSS bulanıklığı Flutter sigma\'sına doğru çevrilir (sigma = blur / 2)', () {
    for (final css in [32.0, 64.0]) {
      expect(Shadow.convertRadiusToSigma(cssBlur(css)), closeTo(css / 2, 1e-9));
    }
  });
}
