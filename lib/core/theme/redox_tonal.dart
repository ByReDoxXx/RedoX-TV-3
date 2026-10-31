import 'package:material_color_utilities/material_color_utilities.dart';

import 'redox_colors.dart';

/// Tohumlardan hesaplanan M3 tonal paletleri (HCT). Rol değerleri bu
/// paletlerin tonlarıdır; eşleşmeyi test/core/theme/redox_roles_test.dart kilitler.
abstract final class RedoxTonal {
  static final _crimson = Hct.fromInt(RedoxSeeds.crimson.toARGB32());

  static final primary = TonalPalette.fromHct(_crimson);
  static final secondary = TonalPalette.fromHct(Hct.fromInt(RedoxSeeds.amber.toARGB32()));
  static final tertiary = TonalPalette.fromHct(Hct.fromInt(RedoxSeeds.gold.toARGB32()));
  static final neutral = TonalPalette.fromHct(Hct.fromInt(RedoxSeeds.obsidian.toARGB32()));

  /// Kızıl tonunda düşük renklilik (M3 içerik şeması: chroma / 8 + 4).
  static final neutralVariant = TonalPalette.of(_crimson.hue, _crimson.chroma / 8 + 4);

  /// M3 varsayılan hata paleti.
  static final error = TonalPalette.of(25, 84);

  /// Rehberde gösterilen tonlar.
  static const tones = [0, 4, 6, 10, 12, 17, 20, 22, 24, 30, 40, 50, 60, 70, 80, 87, 90, 92, 94, 95, 96, 98, 99, 100];
}
