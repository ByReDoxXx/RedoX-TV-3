import 'dart:ui' show Color;

/// Yeni logodan ölçülen marka renkleri. Kaynak: design/tokens.json
/// ("measured" = piksel ölçümü, "derived" = ölçülen zeminden türetildi).
abstract final class RedoxPalette {
  // Marka (measured)
  static const red = Color(0xFFE11D3C);
  static const redDeep = Color(0xFFB11229);
  static const redWine = Color(0xFF820E26);
  static const redDark = Color(0xFF6B0F26);
  static const coral = Color(0xFFF96D54);
  static const gold = Color(0xFFE5AF53);
  static const goldBright = Color(0xFFF8E286);
  static const goldMid = Color(0xFFE2B156);
  static const bronze = Color(0xFFC98234);

  // Zemin (measured)
  static const backgroundGlow = Color(0xFF1E3755);
  static const background = Color(0xFF0F1126);
  static const backgroundDeep = Color(0xFF060B1F);

  // Yüzey kademeleri (derived)
  static const surfaceLow = Color(0xFF151A2E);
  static const surface = Color(0xFF1A1F36);
  static const surfaceHigh = Color(0xFF232943);
  static const surfaceHighest = Color(0xFF2E3550);
  static const outline = Color(0xFF3A4262);

  // Metin (derived)
  static const textPrimary = Color(0xFFF5F4F2);
  static const textSecondary = Color(0xFFB9BDD0);
  static const textTertiary = Color(0xFF8F94AD);

  static const white = Color(0xFFFFFFFF);
}
