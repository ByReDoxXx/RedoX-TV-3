// Boşluk belirteçleri (dp). Kaynak: DESIGN.md "spacing".
// Dönüşüm: 1rem = 16px; CSS pikseli ve dp ikisi de yoğunluktan bağımsız
// referans birimdir, 1px = 1dp alınır (design/DESIGN-KARARLAR.md).

abstract final class RedoxSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  static const double gutter = 24;
  static const double gutterTv = 48;
  static const double margin = 24;
  static const double marginTv = 64;

  /// TV dikey güvenli kenar: Android TV %5 kuralı (540 dp × 0,05 ≈ 27 dp).
  /// Spec'in 64'ü 540 dp yükseklikte %24 eder; dikeyde platform kuralı uygulanır.
  static const double marginTvVertical = 27;
}
