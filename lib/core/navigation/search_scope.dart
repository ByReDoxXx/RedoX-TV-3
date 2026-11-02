import 'package:flutter/widgets.dart';

/// Başlıktaki aramanın açtığı arama sayfası (RootShell sağlar). Arama kutusu
/// her bölüm sayfasının başlığındadır; işlevi sayfalara tek tek geçirmek
/// yerine buradan okunur.
class SearchScope extends InheritedWidget {
  const SearchScope({super.key, required this.open, required super.child});

  /// Arama sayfasını [query] ile açar (telefonda boş: yazmaya başlar).
  final void Function(BuildContext context, String query) open;

  static SearchScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SearchScope>();

  @override
  bool updateShouldNotify(SearchScope oldWidget) => open != oldWidget.open;
}
