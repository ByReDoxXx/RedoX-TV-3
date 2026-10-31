import 'package:flutter/painting.dart';

import 'redox_colors.dart';

// Derinlik: tonal kademe + odakta kromatik ışıma. Kaynak: DESIGN.md
// "Elevation & Depth". Gölge yerine yüzey parlaklığı kullanılır.

/// CSS box-shadow bulanıklık yarıçapını Flutter blurRadius'una çevirir.
/// CSS: sigma = blur / 2 (CSS Backgrounds 3). Flutter: sigma = r * 0.57735 + 0.5
/// (dart:ui Shadow.convertRadiusToSigma). Eşitlenip r'ye çözülür.
double cssBlur(double blur) => (blur / 2 - 0.5) / 0.57735;

abstract final class RedoxElevation {
  /// Odak halkası: 2px dış kontur, kızıl.
  static const double focusRingWidth = 2;

  /// Halka ile öğe arası boşluk (M3 odak göstergesi: 2 dp dış ofset).
  /// Spec ofset vermez; kızıl dolgulu öğede halka ancak bu boşlukla görünür.
  static const double focusRingOffset = 2;

  /// Odak büyümesi: masaüstü/tablet 1.04, TV 1.08 (RedoxMetrics seçer).
  static const double focusScaleDesktop = 1.04;
  static const double focusScaleTv = 1.08;

  /// Birincil düğme odakta 1.06.
  static const double focusScalePrimaryButton = 1.06;

  /// İkinci ve üçüncü kat ışıma (aura + ışıma). Odak gelince hemen açılır.
  static final List<BoxShadow> focusGlow = [
    BoxShadow(color: RedoxAccent.focusAura, offset: const Offset(0, 8), blurRadius: cssBlur(32)),
    BoxShadow(color: RedoxAccent.focusBloom, offset: const Offset(0, 16), blurRadius: cssBlur(64)),
  ];

  static const BorderSide focusRing = BorderSide(
    color: RedoxSeeds.crimson,
    width: focusRingWidth,
    strokeAlign: BorderSide.strokeAlignOutside,
  );

  /// Dinlenen kapların hayalet kenarı.
  static const BorderSide restingBorder = BorderSide(color: RedoxAccent.ghostBorder);
}
