/// Uygulama içinde kullanılan logo varyasyonları (SVG). Platform simgeleri
/// (Android, Windows) bunlardan değil, aynı kaynaktan üretilir:
/// design/logo/logo_varyasyonlari.py.
abstract final class BrandAssets {
  /// Tam logo: karo, boğa, halka ve "RedoX TV" yazısı. Büyük alanlar için.
  static const logo = 'assets/brand/redox-logo.svg';

  /// İşaret: yazısız karo (boğa ve halka). 64 dp ve altı için; yazı bu
  /// boyutta okunmaz.
  static const mark = 'assets/brand/redox-mark.svg';
}
