import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import 'redox_colors.dart';
import 'redox_elevation.dart';
import 'redox_metrics.dart';
import 'redox_shapes.dart';
import 'redox_spacing.dart';
import 'redox_type.dart';

/// "RedoX TV Expressive" koyu teması (DESIGN.md). Yalnızca koyu tema vardır.
abstract final class RedoxTheme {
  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: RedoxRoles.primary,
    onPrimary: RedoxRoles.onPrimary,
    primaryContainer: RedoxRoles.primaryContainer,
    onPrimaryContainer: RedoxRoles.onPrimaryContainer,
    primaryFixed: RedoxRoles.primaryFixed,
    primaryFixedDim: RedoxRoles.primaryFixedDim,
    onPrimaryFixed: RedoxRoles.onPrimaryFixed,
    onPrimaryFixedVariant: RedoxRoles.onPrimaryFixedVariant,
    secondary: RedoxRoles.secondary,
    onSecondary: RedoxRoles.onSecondary,
    secondaryContainer: RedoxRoles.secondaryContainer,
    onSecondaryContainer: RedoxRoles.onSecondaryContainer,
    secondaryFixed: RedoxRoles.secondaryFixed,
    secondaryFixedDim: RedoxRoles.secondaryFixedDim,
    onSecondaryFixed: RedoxRoles.onSecondaryFixed,
    onSecondaryFixedVariant: RedoxRoles.onSecondaryFixedVariant,
    tertiary: RedoxRoles.tertiary,
    onTertiary: RedoxRoles.onTertiary,
    tertiaryContainer: RedoxRoles.tertiaryContainer,
    onTertiaryContainer: RedoxRoles.onTertiaryContainer,
    tertiaryFixed: RedoxRoles.tertiaryFixed,
    tertiaryFixedDim: RedoxRoles.tertiaryFixedDim,
    onTertiaryFixed: RedoxRoles.onTertiaryFixed,
    onTertiaryFixedVariant: RedoxRoles.onTertiaryFixedVariant,
    error: RedoxRoles.error,
    onError: RedoxRoles.onError,
    errorContainer: RedoxRoles.errorContainer,
    onErrorContainer: RedoxRoles.onErrorContainer,
    surface: RedoxRoles.surface,
    onSurface: RedoxRoles.onSurface,
    onSurfaceVariant: RedoxRoles.onSurfaceVariant,
    surfaceDim: RedoxRoles.surfaceDim,
    surfaceBright: RedoxRoles.surfaceBright,
    surfaceContainerLowest: RedoxRoles.surfaceContainerLowest,
    surfaceContainerLow: RedoxRoles.surfaceContainerLow,
    surfaceContainer: RedoxRoles.surfaceContainer,
    surfaceContainerHigh: RedoxRoles.surfaceContainerHigh,
    surfaceContainerHighest: RedoxRoles.surfaceContainerHighest,
    surfaceTint: RedoxRoles.surfaceTint,
    outline: RedoxRoles.outline,
    outlineVariant: RedoxRoles.outlineVariant,
    inverseSurface: RedoxRoles.inverseSurface,
    onInverseSurface: RedoxRoles.inverseOnSurface,
    inversePrimary: RedoxRoles.inversePrimary,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static bool _focusLike(Set<WidgetState> s) => s.contains(WidgetState.focused) || s.contains(WidgetState.hovered);

  static ThemeData dark({FormFactor formFactor = FormFactor.tv}) {
    final text = RedoxType.textTheme(formFactor);
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      fontFamily: RedoxType.family,
      textTheme: text,
      // Taban seviye (0dp) tuval = nötr tohum (Obsidian Void, logonun siyahı).
      // M3'ün surface-container-lowest'ı (T4) bir kademe üstte kalır.
      scaffoldBackgroundColor: RedoxSeeds.obsidian,
      extensions: [RedoxMetrics.of(formFactor)],
      cardTheme: CardThemeData(
        color: RedoxRoles.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedoxRadius.lg),
          side: RedoxElevation.restingBorder,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: RedoxRoles.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.lg)),
      ),
      // Birincil "Combustive" düğme: hap, kızıl dolgu, label-lg beyaz.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: RedoxRoles.primaryContainer,
          foregroundColor: RedoxRoles.onPrimaryContainer,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
          // 40 dp kap (kullanıcı isteği: düğmeler küçülsün). Compose TV
          // Material ButtonDefaults ve M3 ortak düğme yüksekliği 40 dp;
          // dokunmatikte isabet alanı 48 dp kalır (MaterialTapTargetSize.padded).
          minimumSize: const Size(64, RedoxButtonSize.height),
          padding: const EdgeInsets.symmetric(horizontal: RedoxButtonSize.paddingX),
        ),
      ),
      // İkincil "Glass" düğme: %10 beyaz dolgu + %15 kenar; odakta amber, koyu yazı.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _focusLike(s) ? RedoxSeeds.amber : RedoxAccent.glassFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => _focusLike(s) ? RedoxSeeds.obsidian : RedoxRoles.onSurface,
          ),
          iconColor: WidgetStateProperty.resolveWith((s) => _focusLike(s) ? RedoxSeeds.obsidian : RedoxRoles.secondary),
          side: WidgetStateProperty.resolveWith(
            (s) => _focusLike(s) ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll(Size(64, RedoxButtonSize.height)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: RedoxButtonSize.paddingX)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xs)),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? RedoxRoles.primaryContainer : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: RedoxRoles.onSurfaceVariant, width: 2),
      ),
      // Seçili: amber halka, obsidyen iç zemin (DESIGN.md "Radio Buttons").
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? RedoxSeeds.amber : RedoxRoles.onSurfaceVariant,
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? RedoxSeeds.obsidian : Colors.transparent,
        ),
      ),
      // Giriş alanı: en yüksek kap dolgusu + hayalet kenar; odakta 2px amber ve amber yıkama.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.focused)
              ? Color.alphaBlend(RedoxAccent.inputFocusWash, RedoxRoles.surfaceContainerHighest)
              : RedoxRoles.surfaceContainerHighest,
        ),
        hoverColor: Colors.transparent,
        floatingLabelStyle: text.labelMedium,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedoxRadius.sm),
          borderSide: RedoxElevation.restingBorder,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedoxRadius.sm),
          borderSide: RedoxElevation.restingBorder,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedoxRadius.sm),
          borderSide: const BorderSide(color: RedoxSeeds.amber, width: 2),
        ),
      ),
    );
  }
}
