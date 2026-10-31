import '../theme/redox_colors.dart';
import '../ui/nav_rail.dart';
import '../ui/redox_icon.dart';

/// Uygulamanın ana bölümleri (rayın sırası). Kumanda eşleme bir telefon/tablet
/// özelliğidir; TV'de Ayarlar altından QR ile açılır.
abstract final class AppDestinations {
  static const main = [
    NavRailItem(RedoxIcons.home, 'Anasayfa'),
    NavRailItem(RedoxIcons.television, 'Televizyon', tint: RedoxRoles.primary),
    NavRailItem(RedoxIcons.radio, 'Radyo', tint: RedoxRoles.tertiary),
    NavRailItem(RedoxIcons.film, 'Film', tint: RedoxRoles.secondary),
    NavRailItem(RedoxIcons.series, 'Dizi', tint: RedoxRoles.secondary),
    NavRailItem(RedoxIcons.favorites, 'Favoriler', tint: RedoxRoles.tertiary),
    NavRailItem(RedoxIcons.splitScreen, 'Bölünmüş ekran', tint: RedoxRoles.primary),
    NavRailItem(RedoxIcons.sources, 'Kaynaklar'),
  ];

  static const footer = [
    NavRailItem(RedoxIcons.settings, 'Ayarlar'),
  ];
}
