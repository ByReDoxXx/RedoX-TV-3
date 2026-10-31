import '../ui/nav_rail.dart';
import '../ui/redox_icon.dart';

/// Uygulamanın ana bölümleri (rayın sırası). Kumanda eşleme bir telefon/tablet
/// özelliğidir; TV'de Ayarlar altından QR ile açılır. İkonlar M3 Expressive
/// rayında tek renktir (onSurfaceVariant); seçili öğe göstergeyle ayrılır.
abstract final class AppDestinations {
  static const main = [
    NavRailItem(RedoxIcons.home, 'Anasayfa'),
    NavRailItem(RedoxIcons.television, 'Televizyon'),
    NavRailItem(RedoxIcons.radio, 'Radyo'),
    NavRailItem(RedoxIcons.film, 'Film'),
    NavRailItem(RedoxIcons.series, 'Dizi'),
    NavRailItem(RedoxIcons.favorites, 'Favoriler'),
    NavRailItem(RedoxIcons.splitScreen, 'Bölünmüş ekran'),
    NavRailItem(RedoxIcons.sources, 'Kaynaklar'),
  ];

  static const footer = [
    NavRailItem(RedoxIcons.settings, 'Ayarlar'),
  ];
}
