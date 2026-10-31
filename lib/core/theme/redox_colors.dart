import 'dart:ui' show Color;

// Kaynak: design/DESIGN.md ("RedoX TV Expressive").
// Çelişki çözümleri ve gerekçeleri: design/DESIGN-KARARLAR.md.

/// Dört tohum, kullanıcının logosundan (Logo-2) ölçüldü. Ölçüm yöntemi ve
/// kısıtlar: design/DESIGN-KARARLAR.md "Palet: Logo-2'den türetme".
abstract final class RedoxSeeds {
  static const crimson = Color(0xFFD82131); // Crimson Flame, primary: boğa kızılı
  static const amber = Color(0xFFED9650); // Molten Amber, secondary: kıvılcım turuncusu
  static const gold = Color(0xFFF6BD58); // Incandescent Gold, tertiary: halka altını
  static const obsidian = Color(0xFF000000); // Obsidian Void, nötr: logonun siyah zemini
}

/// DESIGN.md YAML'ındaki M3 rolleri, birebir. Değerler, dört tohumdan M3
/// sadakat (fidelity) şemasıyla hesaplanır (Stitch'in yöntemi;
/// RedoxTonal.scheme). Eşleşmeyi test/core/theme/redox_roles_test.dart kanıtlar.
/// YAML'daki background / on-background / surface-variant, surface /
/// on-surface / surface-container-highest ile aynıdır; Flutter'da kullanımdan
/// kalktıkları için ayrıca tanımlanmaz.
abstract final class RedoxRoles {
  static const surface = Color(0xFF131313);
  static const surfaceDim = Color(0xFF131313);
  static const surfaceBright = Color(0xFF393939);
  static const surfaceContainerLowest = Color(0xFF0E0E0E);
  static const surfaceContainerLow = Color(0xFF1B1B1B);
  static const surfaceContainer = Color(0xFF1F1F1F);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceContainerHighest = Color(0xFF353535);
  static const onSurface = Color(0xFFE2E2E2);
  static const onSurfaceVariant = Color(0xFFE5BDBA);
  static const inverseSurface = Color(0xFFE2E2E2);
  static const inverseOnSurface = Color(0xFF303030);
  static const outline = Color(0xFFAC8886);
  static const outlineVariant = Color(0xFF5C3F3E);
  static const surfaceTint = Color(0xFFFFB3AF);
  static const primary = Color(0xFFFFB3AF);
  static const onPrimary = Color(0xFF68000E);
  static const primaryContainer = Color(0xFFD82131);
  static const onPrimaryContainer = Color(0xFFFFF0EF);
  static const inversePrimary = Color(0xFFBF0323);
  static const secondary = Color(0xFFFFB781);
  static const onSecondary = Color(0xFF4E2500);
  static const secondaryContainer = Color(0xFF884500);
  static const onSecondaryContainer = Color(0xFFFFC093);
  static const tertiary = Color(0xFFF6BD58);
  static const onTertiary = Color(0xFF422C00);
  static const tertiaryContainer = Color(0xFF936700);
  static const onTertiaryContainer = Color(0xFFFFF2E2);
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);
  static const onErrorContainer = Color(0xFFFFDAD6);
  static const primaryFixed = Color(0xFFFFDAD7);
  static const primaryFixedDim = Color(0xFFFFB3AF);
  static const onPrimaryFixed = Color(0xFF410005);
  static const onPrimaryFixedVariant = Color(0xFF930018);
  static const secondaryFixed = Color(0xFFFFDCC4);
  static const secondaryFixedDim = Color(0xFFFFB781);
  static const onSecondaryFixed = Color(0xFF2F1400);
  static const onSecondaryFixedVariant = Color(0xFF703800);
  static const tertiaryFixed = Color(0xFFFFDEAB);
  static const tertiaryFixedDim = Color(0xFFF6BD58);
  static const onTertiaryFixed = Color(0xFF271900);
  static const onTertiaryFixedVariant = Color(0xFF5F4100);
}

/// Düzyazının bileşen tariflerinde geçen, rol olmayan renkler.
abstract final class RedoxAccent {
  /// Odak aurası: 0 8px 32px, kızıl tohum %40.
  static const focusAura = Color.from(alpha: 0.40, red: 216 / 255, green: 33 / 255, blue: 49 / 255);

  /// Odak ışıması: 0 16px 64px, amber tohum %20.
  static const focusBloom = Color.from(alpha: 0.20, red: 237 / 255, green: 150 / 255, blue: 80 / 255);

  /// Dinlenen kap kenarı: 1px rgba(255, 255, 255, 0.08).
  static const ghostBorder = Color.from(alpha: 0.08, red: 1, green: 1, blue: 1);

  /// İkincil cam düğme: dolgu %10, kenar %15 beyaz.
  static const glassFill = Color.from(alpha: 0.10, red: 1, green: 1, blue: 1);
  static const glassBorder = Color.from(alpha: 0.15, red: 1, green: 1, blue: 1);

  /// Odaktaki giriş alanı yıkaması: amber tohum %5.
  static const inputFocusWash = Color.from(alpha: 0.05, red: 237 / 255, green: 150 / 255, blue: 80 / 255);

  /// Medya kartı rampası: tuval rengi %0 → %95.
  static const rampStart = Color.from(alpha: 0, red: 0, green: 0, blue: 0);
  static const rampEnd = Color.from(alpha: 0.95, red: 0, green: 0, blue: 0);

  /// Seçili çip degradesinin ucu. Amber tohumda beyaz yazı 2,31:1 kalır; bu
  /// renk amber tonal paletinin beyazla >= 4,5:1 veren en açık tonu (T49).
  /// Kanıt: test/core/theme/redox_contrast_test.dart.
  static const ember = Color(0xFFAC6220);

  /// Isıl degrade (ilerleme çubuğu): kızıl → amber → altın tohumları.
  /// Sadakat şemasında amber kabı koyu (#884500) çıkar ve siyah izde 3:1'i
  /// tutmaz; bu yüzden ortada tohumun kendisi kullanılır.
  static const thermal = [RedoxSeeds.crimson, RedoxSeeds.amber, RedoxSeeds.gold];
}
