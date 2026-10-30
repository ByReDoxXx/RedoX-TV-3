import 'package:flutter/material.dart';

import 'm3e_tokens.dart';
import 'redox_palette.dart';
import 'redox_tonal.dart';
import 'redox_type.dart';

/// Şekil ölçüleri (design/tokens.json -> m3e.shape).
abstract final class RedoxShapes {
  static const double card = M3EShape.extraLarge;
  static const double item = M3EShape.large;
  static const double focusRingWidth = 3;
}

/// Koyu "Kızıl Halka" teması. Rol kuralları: design/PALET-VE-TASARIM.md
abstract final class RedoxTheme {
  /// Roller tool/generate_tonal_palette.dart tarafından üretilir (HCT tonal palet).
  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: RedoxDarkRoles.primary,
    onPrimary: RedoxDarkRoles.onPrimary,
    primaryContainer: RedoxDarkRoles.primaryContainer,
    onPrimaryContainer: RedoxDarkRoles.onPrimaryContainer,
    secondary: RedoxDarkRoles.secondary,
    onSecondary: RedoxDarkRoles.onSecondary,
    secondaryContainer: RedoxDarkRoles.secondaryContainer,
    onSecondaryContainer: RedoxDarkRoles.onSecondaryContainer,
    tertiary: RedoxDarkRoles.tertiary,
    onTertiary: RedoxDarkRoles.onTertiary,
    tertiaryContainer: RedoxDarkRoles.tertiaryContainer,
    onTertiaryContainer: RedoxDarkRoles.onTertiaryContainer,
    error: RedoxDarkRoles.error,
    onError: RedoxDarkRoles.onError,
    errorContainer: RedoxDarkRoles.errorContainer,
    onErrorContainer: RedoxDarkRoles.onErrorContainer,
    surface: RedoxDarkRoles.surface,
    onSurface: RedoxDarkRoles.onSurface,
    onSurfaceVariant: RedoxDarkRoles.onSurfaceVariant,
    outline: RedoxDarkRoles.outline,
    outlineVariant: RedoxDarkRoles.outlineVariant,
    shadow: RedoxDarkRoles.shadow,
    scrim: RedoxDarkRoles.scrim,
    inverseSurface: RedoxDarkRoles.inverseSurface,
    onInverseSurface: RedoxDarkRoles.onInverseSurface,
    inversePrimary: RedoxDarkRoles.inversePrimary,
    surfaceDim: RedoxDarkRoles.surfaceDim,
    surfaceBright: RedoxDarkRoles.surfaceBright,
    surfaceContainerLowest: RedoxDarkRoles.surfaceContainerLowest,
    surfaceContainerLow: RedoxDarkRoles.surfaceContainerLow,
    surfaceContainer: RedoxDarkRoles.surfaceContainer,
    surfaceContainerHigh: RedoxDarkRoles.surfaceContainerHigh,
    surfaceContainerHighest: RedoxDarkRoles.surfaceContainerHighest,
  );

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      fontFamily: RedoxType.family,
      textTheme: M3EType.baseline.apply(fontFamily: RedoxType.family),
      scaffoldBackgroundColor: _scheme.surface,
      cardTheme: CardThemeData(
        color: _scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedoxShapes.card),
        ),
      ),
      // Beyaz yazı / ana kızıl 4,73:1 (küçük metin için yeterli).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      ),
      // M3 varsayılanı bu düğmelerin yazısını primary (kızıl) yapar; kızıl küçük
      // yazıda yetmez (kartta 3,44:1). Kural: küçük kırmızı yazı = mercan.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RedoxPalette.coral,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RedoxPalette.coral,
          minimumSize: const Size(64, 48),
        ),
      ),
    );
  }
}
