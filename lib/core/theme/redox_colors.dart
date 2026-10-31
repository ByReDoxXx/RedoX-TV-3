import 'dart:ui' show Color;

// Kaynak: design/DESIGN.md ("RedoX TV Expressive").
// Çelişki çözümleri ve gerekçeleri: design/DESIGN-KARARLAR.md.

/// Dört tohum, kullanıcının logosundan (Logo-3, alevli boğa) ölçüldü. Ölçüm
/// yöntemi ve kısıtlar: design/DESIGN-KARARLAR.md "Palet: Logo-3'ten türetme".
abstract final class RedoxSeeds {
  static const crimson = Color(0xFFD7232C); // Crimson Flame, primary: boğa kızılı
  static const amber = Color(0xFFFC7422); // Molten Amber, secondary: alev turuncusu
  static const gold = Color(0xFFFBBE4D); // Incandescent Gold, tertiary: halka altını
  static const obsidian = Color(0xFF0B0B20); // Obsidian Void, nötr: logonun gece laciverti
}

/// DESIGN.md YAML'ındaki M3 rolleri, birebir. Değerler, dört tohumdan M3
/// sadakat (fidelity) şemasıyla hesaplanır (Stitch'in yöntemi;
/// RedoxTonal.scheme). Eşleşmeyi test/core/theme/redox_roles_test.dart kanıtlar.
/// YAML'daki background / on-background / surface-variant, surface /
/// on-surface / surface-container-highest ile aynıdır; Flutter'da kullanımdan
/// kalktıkları için ayrıca tanımlanmaz.
abstract final class RedoxRoles {
  static const surface = Color(0xFF111126);
  static const surfaceDim = Color(0xFF111126);
  static const surfaceBright = Color(0xFF37374E);
  static const surfaceContainerLowest = Color(0xFF0C0C21);
  static const surfaceContainerLow = Color(0xFF19192F);
  static const surfaceContainer = Color(0xFF1D1D33);
  static const surfaceContainerHigh = Color(0xFF28283E);
  static const surfaceContainerHighest = Color(0xFF333349);
  static const onSurface = Color(0xFFE2DFFD);
  static const onSurfaceVariant = Color(0xFFE5BDBA);
  static const inverseSurface = Color(0xFFE2DFFD);
  static const inverseOnSurface = Color(0xFF2E2E45);
  static const outline = Color(0xFFAC8885);
  static const outlineVariant = Color(0xFF5C403D);
  static const surfaceTint = Color(0xFFFFB3AD);
  static const primary = Color(0xFFFFB3AD);
  static const onPrimary = Color(0xFF68000A);
  static const primaryContainer = Color(0xFFD7232C);
  static const onPrimaryContainer = Color(0xFFFFF0EE);
  static const inversePrimary = Color(0xFFBE081E);
  static const secondary = Color(0xFFFFB693);
  static const onSecondary = Color(0xFF562000);
  static const secondaryContainer = Color(0xFFED6915);
  static const onSecondaryContainer = Color(0xFF351100);
  static const tertiary = Color(0xFFF9BC4B);
  static const onTertiary = Color(0xFF422C00);
  static const tertiaryContainer = Color(0xFF936700);
  static const onTertiaryContainer = Color(0xFFFFF2E2);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const primaryFixed = Color(0xFFFFDAD7);
  static const primaryFixedDim = Color(0xFFFFB3AD);
  static const onPrimaryFixed = Color(0xFF410004);
  static const onPrimaryFixedVariant = Color(0xFF930013);
  static const secondaryFixed = Color(0xFFFFDBCB);
  static const secondaryFixedDim = Color(0xFFFFB693);
  static const onSecondaryFixed = Color(0xFF341000);
  static const onSecondaryFixedVariant = Color(0xFF7A3000);
  static const tertiaryFixed = Color(0xFFFFDEAA);
  static const tertiaryFixedDim = Color(0xFFF9BC4B);
  static const onTertiaryFixed = Color(0xFF271900);
  static const onTertiaryFixedVariant = Color(0xFF5F4100);
}

/// Düzyazının bileşen tariflerinde geçen, rol olmayan renkler.
abstract final class RedoxAccent {
  /// Odak aurası: 0 8px 32px, kızıl tohum %40.
  static const focusAura = Color.from(alpha: 0.40, red: 215 / 255, green: 35 / 255, blue: 44 / 255);

  /// Odak ışıması: 0 16px 64px, amber tohum %20.
  static const focusBloom = Color.from(alpha: 0.20, red: 252 / 255, green: 116 / 255, blue: 34 / 255);

  /// Dinlenen kap kenarı: 1px rgba(255, 255, 255, 0.08).
  static const ghostBorder = Color.from(alpha: 0.08, red: 1, green: 1, blue: 1);

  /// İkincil cam düğme: dolgu %10, kenar %15 beyaz.
  static const glassFill = Color.from(alpha: 0.10, red: 1, green: 1, blue: 1);
  static const glassBorder = Color.from(alpha: 0.15, red: 1, green: 1, blue: 1);

  /// Odaktaki giriş alanı yıkaması: amber tohum %5.
  static const inputFocusWash = Color.from(alpha: 0.05, red: 252 / 255, green: 116 / 255, blue: 34 / 255);

  /// Medya kartı rampası: tuval rengi %0 → %95.
  static const rampStart = Color.from(alpha: 0, red: 0, green: 0, blue: 0);
  static const rampEnd = Color.from(alpha: 0.95, red: 0, green: 0, blue: 0);

  /// Seçili çip degradesinin ucu. Amber tohumda beyaz yazı 4,5:1'i tutmaz; bu
  /// renk amber tonal paletinin beyazla >= 4,5:1 veren en açık tonu (T50).
  /// Kanıt: test/core/theme/redox_contrast_test.dart.
  static const ember = Color(0xFFC75300);

  /// Isıl degrade (ilerleme çubuğu): kızıl → amber → altın tohumları (logodaki
  /// alevin renkleri).
  static const thermal = [RedoxSeeds.crimson, RedoxSeeds.amber, RedoxSeeds.gold];
}
