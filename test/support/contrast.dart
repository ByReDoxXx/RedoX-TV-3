import 'dart:math' as math;
import 'dart:ui' show Color;

/// WCAG 2.x göreli parlaklık (sRGB kanalları 0…1).
double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG kontrast oranı (1…21). Yarı saydam renkler önce zemine karıştırılmalıdır.
double contrast(Color a, Color b) {
  final x = luminance(a), y = luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}
