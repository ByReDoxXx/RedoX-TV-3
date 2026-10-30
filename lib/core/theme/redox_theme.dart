import 'package:flutter/material.dart';

import 'redox_tonal.dart';

/// Şekil ölçüleri (design/tokens.json -> m3e.shape).
abstract final class RedoxShapes {
  static const double card = 28;
  static const double item = 16;
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
    );
  }
}
