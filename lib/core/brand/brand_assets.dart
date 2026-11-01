/// Uygulama içinde kullanılan logo varyasyonları (SVG). Platform simgeleri
/// (Android, Windows) bunlardan değil, aynı kaynaktan üretilir:
/// design/logo/logo_varyasyonlari.py.
abstract final class BrandAssets {
  /// Tam logo: karo, boğa, halka ve "RedoX TV" yazısı. Büyük alanlar için.
  static const logo = 'assets/brand/redox-logo.svg';

  /// Arayüzdeki bitmap işaret (192 px, yuvarlak köşe): başlık. SVG ~2300
  /// yollu izlemedir ve Impeller'da her karede yeniden çizilir; bitmap tek
  /// dokudur (zayıf TV GPU'su).
  static const markPng = 'assets/brand/redox-mark.png';

  /// Zeminsiz tam logo (bitmap, 607 × 720): boğa, halka ve "REDOX TV" yazısı;
  /// lacivert karo yok. Koyu zeminli büyük alanlar için (profil seçimi).
  static const logoTransparent = 'assets/brand/redox-logo-saydam.png';

  /// İşaret: yazısız karo (boğa ve halka). 64 dp ve altı için; yazı bu
  /// boyutta okunmaz.
  static const mark = 'assets/brand/redox-mark.svg';
}
