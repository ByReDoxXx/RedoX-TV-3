import 'package:flutter/widgets.dart';

import '../theme/redox_metrics.dart';
import '../ui/nav_rail.dart';
import 'form_factor.dart';

/// Bölüm sayfalarının ortak kenar boşlukları. Ray TV/tablet/masaüstünde
/// içeriğin üstünde durur (daralmış 96 dp); içerik raydan 24 dp sonra başlar.
/// Telefonda ray yoktur, içerik kenar boşluğundan başlar.
abstract final class PageLayout {
  static double left(RedoxMetrics metrics) =>
      metrics.formFactor == FormFactor.phone ? metrics.margin.left : RedoxNavRail.collapsedWidth + 24;

  /// Kaydırılan içeriğin dolgusu: kenarlar, durum çubuğu ve (telefonda) alt
  /// menü payı. [context], Scaffold gövdesinin içinden olmalıdır.
  static EdgeInsets scrollPadding(BuildContext context, RedoxMetrics metrics) {
    final m = metrics.margin;
    final safe = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(left(metrics), m.top + safe.top, m.right, m.bottom + safe.bottom);
  }
}
