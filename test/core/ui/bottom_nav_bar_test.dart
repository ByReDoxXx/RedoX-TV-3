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
    bottomNavigationBar: RedoxBottomBar(items: AppDestinations.phoneBar, onSelected: onSelected),
  ),
);

void main() {
  for (final width in [360.0, 411.0]) {
    testWidgets('$width dp: beş öğe eşit yuvada, taşmasız; Anasayfa ve Kumanda yok', (tester) async {
      await loadSora(tester);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final taps = <int>[];
      await tester.pumpWidget(_bar(taps.add));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);

      // Anasayfa logoda, Kumanda "Diğer" sayfasında (kullanıcı isteği).
      expect(find.text('Anasayfa'), findsNothing);
      expect(find.text('Kumanda'), findsNothing);
      expect(AppDestinations.phoneBar, hasLength(5));
      final slot = width / AppDestinations.phoneBar.length;
      for (var i = 0; i < AppDestinations.phoneBar.length; i++) {
        final label = AppDestinations.phoneBar[i].label;
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.center.dx, closeTo(slot * (i + 0.5), 0.01), reason: label);
      }
      expect(tester.getSize(find.byType(RedoxBottomBar)).height, RedoxBottomBar.barHeight);

      await tester.tap(find.bySemanticsLabel('Favori'));
      expect(taps, [AppDestinations.phoneBar.length - 1]);
    });
  }
}
