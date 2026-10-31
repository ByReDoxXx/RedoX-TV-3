import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';

import '../../support/render.dart';

Widget _bar(ValueChanged<int> onSelected) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: FormFactor.phone),
  home: Scaffold(
    extendBody: true,
    bottomNavigationBar: RedoxBottomBar(
      items: AppDestinations.phoneBar,
      centerIndex: AppDestinations.phoneBarHome,
      selectedIndex: AppDestinations.phoneBarHome,
      onSelected: onSelected,
    ),
  ),
);

void main() {
  for (final width in [360.0, 411.0]) {
    testWidgets('$width dp: yedi öğe taşmasız, Anasayfa kendi yuvasında ve çubuktan taşar', (tester) async {
      await loadSora(tester);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final taps = <int>[];
      await tester.pumpWidget(_bar(taps.add));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      for (final item in AppDestinations.phoneBar) {
        expect(find.text(item.label), findsOneWidget, reason: item.label);
      }
      final home = tester.getRect(find.bySemanticsLabel('Anasayfa'));
      // Düğme yuvasının ortasında: (dizin + 0,5) yuva genişliği.
      final slot = width / AppDestinations.phoneBar.length;
      expect(home.center.dx, closeTo(slot * (AppDestinations.phoneBarHome + 0.5), 0.01));
      expect(AppDestinations.phoneBar.last.label, 'Kumanda');
      expect(home.width, closeTo(RedoxBottomBar.centerSize, 0.01));
      // Çubuğun üst kenarı: ekran altı - 64. Düğme alt kenarı gösterge altında.
      const barTop = 800 - RedoxBottomBar.barHeight;
      expect(home.top, closeTo(barTop - RedoxBottomBar.lift, 0.01));
      expect(home.bottom, closeTo(barTop + RedoxBottomBar.topSpace + RedoxBottomBar.indicatorHeight, 0.01));

      // Düğmenin çubuktan taşan üst kısmına da dokunulabilir.
      await tester.tapAt(Offset(home.center.dx, home.top + 4));
      await tester.tap(find.bySemanticsLabel('Kumanda'));
      expect(taps, [AppDestinations.phoneBarHome, AppDestinations.phoneBar.length - 1]);
    });
  }
}
