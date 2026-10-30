import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/theme/redox_palette.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_tonal.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  group('Tonal rol eşlemesi (tool/generate_tonal_palette.dart çıktısı)', () {
    final s = RedoxTheme.dark().colorScheme;

    test('marka çıpaları korunur', () {
      expect(s.primary, RedoxPalette.red);
      expect(s.tertiary, RedoxPalette.gold);
      expect(s.surface, RedoxPalette.background);
    });

    test('on* / zemin çiftleri koyu temada >= 4.5:1', () {
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (s.onPrimary, s.primary),
        'onPrimaryContainer/primaryContainer':
            (s.onPrimaryContainer, s.primaryContainer),
        'onSecondary/secondary': (s.onSecondary, s.secondary),
        'onSecondaryContainer/secondaryContainer':
            (s.onSecondaryContainer, s.secondaryContainer),
        'onTertiary/tertiary': (s.onTertiary, s.tertiary),
        'onTertiaryContainer/tertiaryContainer':
            (s.onTertiaryContainer, s.tertiaryContainer),
        'onError/error': (s.onError, s.error),
        'onErrorContainer/errorContainer': (s.onErrorContainer, s.errorContainer),
        'onSurface/surface': (s.onSurface, s.surface),
        'onSurface/surfaceContainerHighest':
            (s.onSurface, s.surfaceContainerHighest),
        'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
        'onSurfaceVariant/surfaceContainerHighest':
            (s.onSurfaceVariant, s.surfaceContainerHighest),
        'onInverseSurface/inverseSurface': (s.onInverseSurface, s.inverseSurface),
      };
      pairs.forEach((name, p) {
        expect(_contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: name);
      });
    });

    test('çerçeve (outline) zeminde >= 3:1 (metin dışı bileşen)', () {
      expect(_contrast(s.outline, s.surface), greaterThanOrEqualTo(3.0));
    });

    test('yüzey kademeleri açıktan koyuya tek yönlü sıralı', () {
      final order = [
        s.surfaceContainerLowest,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(_lum(order[i]), greaterThan(_lum(order[i - 1])));
      }
    });

    test('her paletin 0 tonu siyah, 100 tonu beyaza yakın', () {
      for (final p in [
        RedoxTonal.primary,
        RedoxTonal.secondary,
        RedoxTonal.tertiary,
        RedoxTonal.neutral,
        RedoxTonal.neutralVariant,
        RedoxTonal.error,
      ]) {
        expect(_lum(p[0]!), lessThan(0.001));
        expect(_lum(p[100]!), greaterThan(0.99));
      }
    });
  });
}
