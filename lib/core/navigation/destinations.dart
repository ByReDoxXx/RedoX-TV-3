import '../ui/nav_rail.dart';
import '../ui/redox_icon.dart';

/// Uygulamanın bölümleri. Ray, alt menü ve "Diğer" sayfası aynı bölümlerden
/// kurulur; dizinler değil bölümler karşılaştırılır.
enum AppSection {
  home(RedoxIcons.home, 'Anasayfa'),
  tv(RedoxIcons.television, 'Televizyon', short: 'TV'),
  radio(RedoxIcons.radio, 'Radyo'),
  film(RedoxIcons.film, 'Film'),
  series(RedoxIcons.series, 'Dizi'),
  favorites(RedoxIcons.favorites, 'Favoriler', short: 'Favori'),
  splitScreen(RedoxIcons.splitScreen, '2x2 Ekran'),
  sources(RedoxIcons.sources, 'Kaynaklar'),
  settings(RedoxIcons.settings, 'Ayarlar'),

  /// Telefonu kumanda olarak eşleme (yalnız telefonda, "Diğer" sayfasında).
  remote(RedoxIcons.remote, 'Kumanda');

  const AppSection(this.icon, this.label, {String? short}) : shortLabel = short ?? label;

  final RedoxIcons icon;
  final String label;

  /// Telefon alt menüsünde (360 dp'de sığsın diye kısa).
  final String shortLabel;
}

/// Bölümlerin yerleşimi. Kumanda eşleme bir telefon/tablet özelliğidir
/// (telefonda "Diğer" sayfasında); TV'de Ayarlar altından QR ile açılır. İkonlar M3
/// Expressive rayında tek renktir (onSurfaceVariant); seçili öğe göstergeyle
/// ayrılır.
abstract final class AppDestinations {
  /// Rayın ana bölümleri ve alt bölümü (dizinleri ana bölümlerden sonra gelir).
  static const railSections = [
    AppSection.home,
    AppSection.tv,
    AppSection.radio,
    AppSection.film,
    AppSection.series,
    AppSection.favorites,
    AppSection.splitScreen,
    AppSection.sources,
  ];
  static const railFooterSections = [AppSection.settings];

  /// Çocuk profili: Anasayfa ve Televizyon; Ayarlar yok.
  static const kidsRailSections = [AppSection.home, AppSection.tv];

  /// Telefon alt menüsü (kullanıcı isteği): Anasayfa yok (başlıktaki logo
  /// Anasayfa'ya götürür), Kumanda "Diğer" sayfasında. Beş öğe (M3 sınırı).
  static const phoneBarSections = [
    AppSection.tv,
    AppSection.radio,
    AppSection.film,
    AppSection.series,
    AppSection.favorites,
  ];

  /// Telefonda alt menüye sığmayanlar: başlıktaki "Diğer" düğmesiyle açılır.
  /// Kumanda burada (kullanıcı isteği: başlıkta göze batıyordu).
  static const phoneMoreSections = [AppSection.splitScreen, AppSection.sources, AppSection.remote, AppSection.settings];

  /// Çocuk profilinde telefonda alt menü yoktur; "Diğer" sayfasında
  /// Televizyon durur.
  static const kidsPhoneMoreSections = [AppSection.tv];

  static final main = [for (final s in railSections) NavRailItem(s.icon, s.label)];
  static final footer = [for (final s in railFooterSections) NavRailItem(s.icon, s.label)];
  static final phoneBar = [for (final s in phoneBarSections) NavRailItem(s.icon, s.shortLabel)];
  static final phoneMore = [for (final s in phoneMoreSections) NavRailItem(s.icon, s.label)];

  static List<NavRailItem> items(List<AppSection> sections) => [for (final s in sections) NavRailItem(s.icon, s.label)];

  /// Bölümün raydaki dizini (ana bölümler, sonra alt bölüm).
  static int railIndexOf(
    AppSection section, {
    List<AppSection> main = railSections,
    List<AppSection> footer = railFooterSections,
  }) {
    final i = main.indexOf(section);
    if (i >= 0) return i;
    final j = footer.indexOf(section);
    return j >= 0 ? main.length + j : -1;
  }

  /// Raydaki dizinin bölümü.
  static AppSection railSectionAt(
    int index, {
    List<AppSection> main = railSections,
    List<AppSection> footer = railFooterSections,
  }) => index < main.length ? main[index] : footer[index - main.length];
}
