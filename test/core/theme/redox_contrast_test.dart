import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_palette.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';

/// WCAG 2.x göreli parlaklık ve kontrast oranı.
double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double contrast(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  final hi = math.max(x, y), lo = math.min(x, y);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Küçük metin >= 4.5:1 (design/PALET-VE-TASARIM.md)', () {
    test('ana, ikincil, üçüncül metin kart üzerinde', () {
      for (final t in [
        RedoxPalette.textPrimary,
        RedoxPalette.textSecondary,
        RedoxPalette.textTertiary,
      ]) {
        expect(contrast(t, RedoxPalette.surface), greaterThanOrEqualTo(4.5));
      }
    });

    test('beyaz yazı ana kızıl ve koyu kızıl dolguda', () {
      expect(contrast(RedoxPalette.white, RedoxPalette.red),
          greaterThanOrEqualTo(4.5));
      expect(contrast(RedoxPalette.white, RedoxPalette.redDeep),
          greaterThanOrEqualTo(4.5));
    });

    test('mercan küçük kırmızı yazı kartta', () {
      expect(contrast(RedoxPalette.coral, RedoxPalette.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('altın zeminde ve kartta', () {
      expect(contrast(RedoxPalette.gold, RedoxPalette.background),
          greaterThanOrEqualTo(4.5));
      expect(contrast(RedoxPalette.gold, RedoxPalette.surface),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('Bilinen sınırlar korunur (regresyon)', () {
    test('ana kızıl küçük metin olarak yetmez: yalnızca simge/büyük metin', () {
      expect(contrast(RedoxPalette.red, RedoxPalette.surface), lessThan(4.5));
      expect(contrast(RedoxPalette.red, RedoxPalette.background),
          greaterThanOrEqualTo(3.0)); // metin dışı bileşen eşiği
    });

    test('odak halkası kartta 3:1 üstü (metin dışı kural)', () {
      expect(contrast(RedoxPalette.goldBright, RedoxPalette.surface),
          greaterThanOrEqualTo(3.0));
    });

    test('tema ana rengi marka kızılı, düğme boyutu >= 48dp', () {
      final t = RedoxTheme.dark();
      expect(t.colorScheme.primary, RedoxPalette.red);
      expect(t.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
          greaterThanOrEqualTo(48));
    });
  });
}
