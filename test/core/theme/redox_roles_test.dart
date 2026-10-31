import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/theme/redox_tonal.dart';

import '../../support/contrast.dart';

Color _tone(TonalPalette p, int t) => Color(p.get(t));

void main() {
  group('DESIGN.md rolleri tohumlardan M3 sadakat şemasıyla türer', () {
    final s = RedoxTonal.scheme;
    final roles = <String, (Color, DynamicColor)>{
      'surface': (RedoxRoles.surface, MaterialDynamicColors.surface),
      'surfaceDim': (RedoxRoles.surfaceDim, MaterialDynamicColors.surfaceDim),
      'surfaceBright': (RedoxRoles.surfaceBright, MaterialDynamicColors.surfaceBright),
      'surfaceContainerLowest': (RedoxRoles.surfaceContainerLowest, MaterialDynamicColors.surfaceContainerLowest),
      'surfaceContainerLow': (RedoxRoles.surfaceContainerLow, MaterialDynamicColors.surfaceContainerLow),
      'surfaceContainer': (RedoxRoles.surfaceContainer, MaterialDynamicColors.surfaceContainer),
      'surfaceContainerHigh': (RedoxRoles.surfaceContainerHigh, MaterialDynamicColors.surfaceContainerHigh),
      'surfaceContainerHighest': (RedoxRoles.surfaceContainerHighest, MaterialDynamicColors.surfaceContainerHighest),
      'onSurface': (RedoxRoles.onSurface, MaterialDynamicColors.onSurface),
      'onSurfaceVariant': (RedoxRoles.onSurfaceVariant, MaterialDynamicColors.onSurfaceVariant),
      'inverseSurface': (RedoxRoles.inverseSurface, MaterialDynamicColors.inverseSurface),
      'inverseOnSurface': (RedoxRoles.inverseOnSurface, MaterialDynamicColors.inverseOnSurface),
      'outline': (RedoxRoles.outline, MaterialDynamicColors.outline),
      'outlineVariant': (RedoxRoles.outlineVariant, MaterialDynamicColors.outlineVariant),
      'surfaceTint': (RedoxRoles.surfaceTint, MaterialDynamicColors.surfaceTint),
      'primary': (RedoxRoles.primary, MaterialDynamicColors.primary),
      'onPrimary': (RedoxRoles.onPrimary, MaterialDynamicColors.onPrimary),
      'primaryContainer': (RedoxRoles.primaryContainer, MaterialDynamicColors.primaryContainer),
      'onPrimaryContainer': (RedoxRoles.onPrimaryContainer, MaterialDynamicColors.onPrimaryContainer),
      'inversePrimary': (RedoxRoles.inversePrimary, MaterialDynamicColors.inversePrimary),
      'secondary': (RedoxRoles.secondary, MaterialDynamicColors.secondary),
      'onSecondary': (RedoxRoles.onSecondary, MaterialDynamicColors.onSecondary),
      'secondaryContainer': (RedoxRoles.secondaryContainer, MaterialDynamicColors.secondaryContainer),
      'onSecondaryContainer': (RedoxRoles.onSecondaryContainer, MaterialDynamicColors.onSecondaryContainer),
      'tertiary': (RedoxRoles.tertiary, MaterialDynamicColors.tertiary),
      'onTertiary': (RedoxRoles.onTertiary, MaterialDynamicColors.onTertiary),
      'tertiaryContainer': (RedoxRoles.tertiaryContainer, MaterialDynamicColors.tertiaryContainer),
      'onTertiaryContainer': (RedoxRoles.onTertiaryContainer, MaterialDynamicColors.onTertiaryContainer),
      'error': (RedoxRoles.error, MaterialDynamicColors.error),
      'onError': (RedoxRoles.onError, MaterialDynamicColors.onError),
      'errorContainer': (RedoxRoles.errorContainer, MaterialDynamicColors.errorContainer),
      'onErrorContainer': (RedoxRoles.onErrorContainer, MaterialDynamicColors.onErrorContainer),
      'primaryFixed': (RedoxRoles.primaryFixed, MaterialDynamicColors.primaryFixed),
      'primaryFixedDim': (RedoxRoles.primaryFixedDim, MaterialDynamicColors.primaryFixedDim),
      'onPrimaryFixed': (RedoxRoles.onPrimaryFixed, MaterialDynamicColors.onPrimaryFixed),
      'onPrimaryFixedVariant': (RedoxRoles.onPrimaryFixedVariant, MaterialDynamicColors.onPrimaryFixedVariant),
      'secondaryFixed': (RedoxRoles.secondaryFixed, MaterialDynamicColors.secondaryFixed),
      'secondaryFixedDim': (RedoxRoles.secondaryFixedDim, MaterialDynamicColors.secondaryFixedDim),
      'onSecondaryFixed': (RedoxRoles.onSecondaryFixed, MaterialDynamicColors.onSecondaryFixed),
      'onSecondaryFixedVariant': (RedoxRoles.onSecondaryFixedVariant, MaterialDynamicColors.onSecondaryFixedVariant),
      'tertiaryFixed': (RedoxRoles.tertiaryFixed, MaterialDynamicColors.tertiaryFixed),
      'tertiaryFixedDim': (RedoxRoles.tertiaryFixedDim, MaterialDynamicColors.tertiaryFixedDim),
      'onTertiaryFixed': (RedoxRoles.onTertiaryFixed, MaterialDynamicColors.onTertiaryFixed),
      'onTertiaryFixedVariant': (RedoxRoles.onTertiaryFixedVariant, MaterialDynamicColors.onTertiaryFixedVariant),
    };

    test('44 rolün hepsi şemanın değeri', () {
      expect(roles, hasLength(44));
      roles.forEach((name, r) => expect(r.$1, Color(r.$2.getArgb(s)), reason: name));
    });

    test('kap = tohum; yüzey merdiveni nötr paletin T4…T24 tonları', () {
      expect(RedoxRoles.primaryContainer, RedoxSeeds.crimson);
      final n = RedoxTonal.neutral;
      expect(RedoxRoles.surfaceContainerLowest, _tone(n, 4));
      expect(RedoxRoles.surface, _tone(n, 6));
      expect(RedoxRoles.surfaceContainerLow, _tone(n, 10));
      expect(RedoxRoles.surfaceContainer, _tone(n, 12));
      expect(RedoxRoles.surfaceContainerHigh, _tone(n, 17));
      expect(RedoxRoles.surfaceContainerHighest, _tone(n, 22));
      expect(RedoxRoles.surfaceBright, _tone(n, 24));
      // Nötr tohum logonun saf siyahı: paletin T0'ı.
      expect(RedoxSeeds.obsidian, _tone(n, 0));
    });
  });

  group('Tema', () {
    final theme = RedoxTheme.dark();
    final s = theme.colorScheme;

    test('tuval nötr tohum (saf siyah), kart surface-container', () {
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

    test('metin rolleri tuvalde ve her yüzey kademesinde >= 4.5:1', () {
      for (final bg in [
        RedoxSeeds.obsidian,
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
      expect(contrast(s.outline, RedoxSeeds.obsidian), greaterThanOrEqualTo(3.0));
      expect(contrast(s.outline, s.surfaceContainer), greaterThanOrEqualTo(3.0));
    });

    test('yüzey kademeleri koyudan açığa tek yönlü', () {
      final order = [
        RedoxSeeds.obsidian,
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
