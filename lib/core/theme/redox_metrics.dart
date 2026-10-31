import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import 'redox_elevation.dart';
import 'redox_spacing.dart';

/// Cihaz biçimine bağlı ölçüler. Bileşenler bu değerleri temadan okur:
/// `Theme.of(context).extension<RedoxMetrics>()!`.
@immutable
class RedoxMetrics extends ThemeExtension<RedoxMetrics> {
  const RedoxMetrics._({
    required this.formFactor,
    required this.focusScale,
    required this.iconButtonSize,
    required this.margin,
    required this.gutter,
  });

  factory RedoxMetrics.of(FormFactor formFactor) => switch (formFactor) {
    FormFactor.tv => const RedoxMetrics._(
      formFactor: FormFactor.tv,
      focusScale: RedoxElevation.focusScaleTv,
      iconButtonSize: 56,
      margin: EdgeInsets.symmetric(horizontal: RedoxSpace.marginTv, vertical: RedoxSpace.marginTvVertical),
      gutter: RedoxSpace.gutterTv,
    ),
    FormFactor.tablet || FormFactor.desktop => RedoxMetrics._(
      formFactor: formFactor,
      focusScale: RedoxElevation.focusScaleDesktop,
      iconButtonSize: 48,
      margin: const EdgeInsets.all(RedoxSpace.xl),
      gutter: RedoxSpace.gutter,
    ),
    FormFactor.phone => const RedoxMetrics._(
      formFactor: FormFactor.phone,
      focusScale: RedoxElevation.focusScaleDesktop,
      iconButtonSize: 48,
      margin: EdgeInsets.all(RedoxSpace.margin),
      gutter: RedoxSpace.gutter,
    ),
  };

  final FormFactor formFactor;

  /// Odakta büyüme oranı (kartlar ve genel öğeler).
  final double focusScale;

  /// Dairesel ikon düğmesi çapı: dokunma/işaretçi 48, TV 56.
  final double iconButtonSize;

  /// Dış kenar boşluğu (TV'de taşma güvenli alan).
  final EdgeInsets margin;

  /// Kartlar arası oluk.
  final double gutter;

  @override
  RedoxMetrics copyWith({FormFactor? formFactor}) =>
      formFactor == null ? this : RedoxMetrics.of(formFactor);

  /// Biçimler arası ara değer anlamsızdır; yarı noktada geçilir.
  @override
  RedoxMetrics lerp(RedoxMetrics? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
