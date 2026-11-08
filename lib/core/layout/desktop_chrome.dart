import 'package:flutter/widgets.dart';

/// Masaüstü kabuğunun (Windows/Linux) içindeki bölüm sayfalarını işaretler.
/// Kabuk üst çubuğu (arama, profil, saat) ve sol kitaplık panelini kendisi
/// çizer; bu yüzden sayfalar kendi başlıklarını göstermez ve ray payı
/// bırakmaz (bkz. AppHeader, PageLayout).
class DesktopChrome extends InheritedWidget {
  const DesktopChrome({super.key, required super.child});

  /// Sayfa masaüstü kabuğunun içinde mi?
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopChrome>() != null;

  @override
  bool updateShouldNotify(DesktopChrome oldWidget) => false;
}
