import 'dart:ui' show Color;

// Kaynak: design/DESIGN.md ("RedoX TV Expressive").
// Çelişki çözümleri ve gerekçeleri: design/DESIGN-KARARLAR.md.

/// Düzyazıda ("Palette Architecture") adı geçen dört tohum.
abstract final class RedoxSeeds {
  static const crimson = Color(0xFFE61638); // Crimson Flame, primary
  static const amber = Color(0xFFFF9E1B); // Molten Amber, secondary
  static const gold = Color(0xFFFFD54F); // Incandescent Gold, tertiary
  static const obsidian = Color(0xFF0D0E11); // Obsidian Void, nötr
}

/// YAML ön bilgisindeki M3 rolleri, birebir. Rollerin tohumların tonal
/// paletlerinden türediğini test/core/theme/redox_roles_test.dart kanıtlar.
/// YAML'daki background / on-background / surface-variant, surface /
/// on-surface / surface-container-highest ile aynıdır; Flutter'da kullanımdan
/// kalktıkları için ayrıca tanımlanmaz.
abstract final class RedoxRoles {
  static const surface = Color(0xFF121316);
  static const surfaceDim = Color(0xFF121316);
  static const surfaceBright = Color(0xFF38393C);
  static const surfaceContainerLowest = Color(0xFF0D0E11);
  static const surfaceContainerLow = Color(0xFF1B1B1F);
  static const surfaceContainer = Color(0xFF1F1F23);
  static const surfaceContainerHigh = Color(0xFF292A2D);
  static const surfaceContainerHighest = Color(0xFF343538);
  static const onSurface = Color(0xFFE3E2E6);
  static const onSurfaceVariant = Color(0xFFE7BCBB);
  static const inverseSurface = Color(0xFFE3E2E6);
  static const inverseOnSurface = Color(0xFF303034);
  static const outline = Color(0xFFAD8886);
  static const outlineVariant = Color(0xFF5D3F3E);
  static const surfaceTint = Color(0xFFFFB3B1);
  static const primary = Color(0xFFFFB3B1);
  static const onPrimary = Color(0xFF680012);
  static const primaryContainer = Color(0xFFE61638);
  static const onPrimaryContainer = Color(0xFFFFFCFF);
  static const inversePrimary = Color(0xFFBF0029);
  static const secondary = Color(0xFFFFB86C);
  static const onSecondary = Color(0xFF492900);
  static const secondaryContainer = Color(0xFFED9000);
  static const onSecondaryContainer = Color(0xFF583200);
  static const tertiary = Color(0xFFEBC23E);
  static const onTertiary = Color(0xFF3C2F00);
  static const tertiaryContainer = Color(0xFFCDA721);
  static const onTertiaryContainer = Color(0xFF4E3E00);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const primaryFixed = Color(0xFFFFDAD8);
  static const primaryFixedDim = Color(0xFFFFB3B1);
  static const onPrimaryFixed = Color(0xFF410007);
  static const onPrimaryFixedVariant = Color(0xFF92001D);
  static const secondaryFixed = Color(0xFFFFDCBC);
  static const secondaryFixedDim = Color(0xFFFFB86C);
  static const onSecondaryFixed = Color(0xFF2C1600);
  static const onSecondaryFixedVariant = Color(0xFF683C00);
  static const tertiaryFixed = Color(0xFFFFE087);
  static const tertiaryFixedDim = Color(0xFFEBC23E);
  static const onTertiaryFixed = Color(0xFF241A00);
  static const onTertiaryFixedVariant = Color(0xFF574500);
}

/// Düzyazının bileşen tariflerinde geçen, rol olmayan renkler.
abstract final class RedoxAccent {
  /// Odak aurası: 0 8px 32px rgba(230, 22, 56, 0.40).
  static const focusAura = Color.from(alpha: 0.40, red: 230 / 255, green: 22 / 255, blue: 56 / 255);

  /// Odak ışıması: 0 16px 64px rgba(255, 158, 27, 0.20).
  static const focusBloom = Color.from(alpha: 0.20, red: 1, green: 158 / 255, blue: 27 / 255);

  /// Dinlenen kap kenarı: 1px rgba(255, 255, 255, 0.08).
  static const ghostBorder = Color.from(alpha: 0.08, red: 1, green: 1, blue: 1);

  /// İkincil cam düğme: dolgu %10, kenar %15 beyaz.
  static const glassFill = Color.from(alpha: 0.10, red: 1, green: 1, blue: 1);
  static const glassBorder = Color.from(alpha: 0.15, red: 1, green: 1, blue: 1);

  /// Odaktaki giriş alanı yıkaması: rgba(255, 158, 27, 0.05).
  static const inputFocusWash = Color.from(alpha: 0.05, red: 1, green: 158 / 255, blue: 27 / 255);

  /// Medya kartı rampası: rgba(13, 14, 17, 0) → rgba(13, 14, 17, 0.95).
  static const rampStart = Color.from(alpha: 0, red: 13 / 255, green: 14 / 255, blue: 17 / 255);
  static const rampEnd = Color.from(alpha: 0.95, red: 13 / 255, green: 14 / 255, blue: 17 / 255);

  /// Seçili çip degradesinin ucu. Spec'teki #FF9E1B ucunda beyaz yazı 2,07:1
  /// kalır; bu renk amber tonal paletinin beyazla >= 4,5:1 veren en açık tonu
  /// (T49). Kanıt: test/core/theme/redox_contrast_test.dart.
  static const ember = Color(0xFFA86500);

  /// Isıl degrade (ilerleme çubuğu): kızıl → amber kabı → altın.
  static const thermal = [RedoxRoles.primaryContainer, RedoxRoles.secondaryContainer, RedoxRoles.tertiary];
}
