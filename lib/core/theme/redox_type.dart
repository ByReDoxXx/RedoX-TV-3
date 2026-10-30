import 'dart:ui' show FontVariation;

/// Yazı tipi kararları. Kaynak: design/M3E-UX-UI.md §1.
abstract final class RedoxType {
  /// pubspec.yaml'daki değişken yazı tipi ailesi (Google Sans Flex, OFL).
  static const family = 'GoogleSansFlex';

  /// Marka anları için eğim (logo wordmark'ı italik). Eksen aralığı −10…0.
  /// Yalnızca başlık wordmark, ekran başlığı ve kanal numarasında kullanılır.
  static const brandSlant = [FontVariation('slnt', -10)];
}
