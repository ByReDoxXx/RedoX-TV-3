import '../ui/nav_rail.dart';
import '../ui/redox_icon.dart';

/// Uygulamanın ana bölümleri (rayın sırası). Kumanda eşleme bir telefon/tablet
/// özelliğidir (telefonda alt menüde); TV'de Ayarlar altından QR ile açılır. İkonlar M3 Expressive
/// rayında tek renktir (onSurfaceVariant); seçili öğe göstergeyle ayrılır.
abstract final class AppDestinations {
  static const main = [
    NavRailItem(RedoxIcons.home, 'Anasayfa'),
    NavRailItem(RedoxIcons.television, 'Televizyon'),
    NavRailItem(RedoxIcons.radio, 'Radyo'),
    NavRailItem(RedoxIcons.film, 'Film'),
    NavRailItem(RedoxIcons.series, 'Dizi'),
    NavRailItem(RedoxIcons.favorites, 'Favoriler'),
    NavRailItem(RedoxIcons.splitScreen, '2x2 Ekran'),
    NavRailItem(RedoxIcons.sources, 'Kaynaklar'),
  ];

  static const footer = [
    NavRailItem(RedoxIcons.settings, 'Ayarlar'),
  ];

  /// Telefon alt menüsü (kullanıcı isteği): Anasayfa kırmızı yuvarlak düğme,
  /// Kumanda en sonda. Etiketler 360 dp genişlikte sığsın diye kısadır.
  static const phoneBar = [
    NavRailItem(RedoxIcons.television, 'TV'),
    NavRailItem(RedoxIcons.radio, 'Radyo'),
    NavRailItem(RedoxIcons.home, 'Anasayfa'),
    NavRailItem(RedoxIcons.film, 'Film'),
    NavRailItem(RedoxIcons.series, 'Dizi'),
    NavRailItem(RedoxIcons.favorites, 'Favori'),
    NavRailItem(RedoxIcons.remote, 'Kumanda'),
  ];

  /// Alt menüde kırmızı düğme olan (Anasayfa) öğenin dizini.
  static const phoneBarHome = 2;

  /// Telefonda alt menüye sığmayanlar: başlıktaki "Diğer" düğmesiyle açılır.
  static const phoneMore = [
    NavRailItem(RedoxIcons.splitScreen, '2x2 Ekran'),
    NavRailItem(RedoxIcons.sources, 'Kaynaklar'),
    NavRailItem(RedoxIcons.settings, 'Ayarlar'),
  ];
}
