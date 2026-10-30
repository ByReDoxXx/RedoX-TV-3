import 'dart:ui' show Color;

/// Logodan ölçülen marka renkleri. Kaynak: design/tokens.json
/// ("measured" = piksel ölçümü, "derived" = ölçülen zeminden türetildi).
abstract final class RedoxPalette {
  // Marka (measured)
  static const red = Color(0xFFF22144);
  static const redDeep = Color(0xFFC41536);
  static const redWine = Color(0xFF95122B);
  static const redDark = Color(0xFF440A21);
  static const coral = Color(0xFFF25F61);
  static const gold = Color(0xFFF0BE5E);
  static const goldBright = Color(0xFFF7D574);
  static const goldDeep = Color(0xFFDFA747);
  static const bronze = Color(0xFFCF9038);

  // Zemin (measured)
  static const backgroundGlow = Color(0xFF293143);
  static const background = Color(0xFF0A0D1C);
  static const backgroundDeep = Color(0xFF010413);

  // Yüzey kademeleri (derived)
  static const surfaceLow = Color(0xFF0F1325);
  static const surface = Color(0xFF141829);
  static const surfaceHigh = Color(0xFF1C2136);
  static const surfaceHighest = Color(0xFF262C44);
  static const outline = Color(0xFF2E3550);

  // Metin (derived)
  static const textPrimary = Color(0xFFF5F4F2);
  static const textSecondary = Color(0xFFB9BDD0);
  static const textTertiary = Color(0xFF8F94AD);

  static const white = Color(0xFFFFFFFF);
}
