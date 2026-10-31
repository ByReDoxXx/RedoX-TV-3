import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_tonal.dart';

import '../../support/contrast.dart';

Color _tone(TonalPalette p, int t) => Color(p.get(t));

void main() {
  group('DESIGN.md rolleri tohumların M3 tonal paletlerinden türer', () {
    test('kızıl paleti: primary, on-primary, fixed ve inverse rolleri', () {
      final p = RedoxTonal.primary;
      expect(RedoxRoles.primary, _tone(p, 80));
      expect(RedoxRoles.onPrimary, _tone(p, 20));
      expect(RedoxRoles.inversePrimary, _tone(p, 40));
      expect(RedoxRoles.primaryFixed, _tone(p, 90));
      expect(RedoxRoles.primaryFixedDim, _tone(p, 80));
      expect(RedoxRoles.onPrimaryFixed, _tone(p, 10));
      expect(RedoxRoles.onPrimaryFixedVariant, _tone(p, 30));
      // Kap = tohumun kendisi (içerik/sadakat şeması).
      expect(RedoxRoles.primaryContainer, RedoxSeeds.crimson);
    });

    test('amber paleti: secondary rolleri', () {
      final p = RedoxTonal.secondary;
      expect(RedoxRoles.secondary, _tone(p, 80));
      expect(RedoxRoles.onSecondary, _tone(p, 20));
      expect(RedoxRoles.secondaryFixed, _tone(p, 90));
      expect(RedoxRoles.onSecondaryFixed, _tone(p, 10));
      expect(RedoxRoles.onSecondaryFixedVariant, _tone(p, 30));
    });

    test('altın paleti: tertiary rolleri', () {
      final p = RedoxTonal.tertiary;
      expect(RedoxRoles.tertiary, _tone(p, 80));
      expect(RedoxRoles.onTertiary, _tone(p, 20));
      expect(RedoxRoles.tertiaryContainer, _tone(p, 70));
      expect(RedoxRoles.tertiaryFixed, _tone(p, 90));
      expect(RedoxRoles.onTertiaryFixed, _tone(p, 10));
      expect(RedoxRoles.onTertiaryFixedVariant, _tone(p, 30));
    });

    test('obsidyen nötr paleti: YAML yüzey merdiveni (T4…T24) ve metin', () {
      final n = RedoxTonal.neutral;
      expect(RedoxRoles.surfaceContainerLowest, _tone(n, 4));
      expect(RedoxRoles.surface, _tone(n, 6));
      expect(RedoxRoles.surfaceContainerLow, _tone(n, 10));
      expect(RedoxRoles.surfaceContainer, _tone(n, 12));
      expect(RedoxRoles.surfaceContainerHigh, _tone(n, 17));
      expect(RedoxRoles.surfaceContainerHighest, _tone(n, 22));
      expect(RedoxRoles.surfaceBright, _tone(n, 24));
      expect(RedoxRoles.onSurface, _tone(n, 90));
      expect(RedoxRoles.inverseOnSurface, _tone(n, 20));
      // Tuval tohumu = en alt kap.
      expect(RedoxRoles.surfaceContainerLowest, RedoxSeeds.obsidian);
    });

    test('nötr varyant (kızıl tonu, chroma/8+4) ve hata paletleri', () {
      final v = RedoxTonal.neutralVariant;
      expect(RedoxRoles.onSurfaceVariant, _tone(v, 80));
      expect(RedoxRoles.outline, _tone(v, 60));
      expect(RedoxRoles.outlineVariant, _tone(v, 30));
      final e = RedoxTonal.error;
      expect(RedoxRoles.error, _tone(e, 80));
      expect(RedoxRoles.onError, _tone(e, 20));
      expect(RedoxRoles.errorContainer, _tone(e, 30));
      expect(RedoxRoles.onErrorContainer, _tone(e, 90));
    });
  });

  group('Tema', () {
    final theme = RedoxTheme.dark();
    final s = theme.colorScheme;

    test('tuval obsidyen, kart surface-container', () {
      expect(theme.scaffoldBackgroundColor, RedoxSeeds.obsidian);
      expect(theme.cardTheme.color, s.surfaceContainer);
    });

    test('on* / zemin çiftleri >= 4.5:1', () {
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (s.onPrimary, s.primary),
        'onPrimaryContainer/primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
        'onSecondary/secondary': (s.onSecondary, s.secondary),
        'onSecondaryContainer/secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
        'onTertiary/tertiary': (s.onTertiary, s.tertiary),
        'onTertiaryContainer/tertiaryContainer': (s.onTertiaryContainer, s.tertiaryContainer),
        'onError/error': (s.onError, s.error),
        'onErrorContainer/errorContainer': (s.onErrorContainer, s.errorContainer),
        'onInverseSurface/inverseSurface': (s.onInverseSurface, s.inverseSurface),
      };
      pairs.forEach((name, p) {
        expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: name);
      });
    });

    test('metin rolleri her yüzey kademesinde >= 4.5:1', () {
      for (final bg in [
        s.surfaceContainerLowest,
        s.surface,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
      ]) {
        for (final fg in [s.onSurface, s.onSurfaceVariant, s.primary, s.secondary, s.tertiary]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg / $bg');
        }
      }
    });

    test('çerçeve (outline) tuvalde ve kartta >= 3:1', () {
      expect(contrast(s.outline, s.surfaceContainerLowest), greaterThanOrEqualTo(3.0));
      expect(contrast(s.outline, s.surfaceContainer), greaterThanOrEqualTo(3.0));
    });

    test('yüzey kademeleri koyudan açığa tek yönlü', () {
      final order = [
        s.surfaceContainerLowest,
        s.surface,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
        s.surfaceBright,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(luminance(order[i]), greaterThan(luminance(order[i - 1])));
      }
    });
  });
}
