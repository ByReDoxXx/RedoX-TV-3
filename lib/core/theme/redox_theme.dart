import 'package:flutter/material.dart';

import 'redox_palette.dart';

/// Şekil ölçüleri (design/tokens.json -> m3e.shape).
abstract final class RedoxShapes {
  static const double card = 28;
  static const double item = 16;
  static const double focusRingWidth = 3;
}

/// Koyu "Kızıl Halka" teması. Rol kuralları: design/PALET-VE-TASARIM.md
abstract final class RedoxTheme {
  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: RedoxPalette.red,
    onPrimary: RedoxPalette.white,
    primaryContainer: RedoxPalette.redDeep,
    onPrimaryContainer: RedoxPalette.white,
    secondary: RedoxPalette.redWine,
    onSecondary: RedoxPalette.white,
    tertiary: RedoxPalette.gold,
    onTertiary: RedoxPalette.background,
    error: RedoxPalette.coral,
    onError: RedoxPalette.background,
    surface: RedoxPalette.background,
    onSurface: RedoxPalette.textPrimary,
    onSurfaceVariant: RedoxPalette.textSecondary,
    surfaceContainerLowest: RedoxPalette.backgroundDeep,
    surfaceContainerLow: RedoxPalette.surfaceLow,
    surfaceContainer: RedoxPalette.surface,
    surfaceContainerHigh: RedoxPalette.surfaceHigh,
    surfaceContainerHighest: RedoxPalette.surfaceHighest,
    outline: RedoxPalette.textTertiary,
    outlineVariant: RedoxPalette.outline,
  );

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: RedoxPalette.background,
      cardTheme: CardThemeData(
        color: RedoxPalette.surface,
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
