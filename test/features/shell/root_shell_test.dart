import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/double_back_to_exit.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/app_header.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/home/home_page.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/shell/section_placeholder.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/tv_page.dart';

import '../../support/render.dart';

Widget _app(FormFactor f) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: f),
  home: const RootShell(home: HomeContent.preview, tv: TvContent.preview),
);

Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 600));

Finder _railIcon(RedoxIcons icon) => find.descendant(
  of: find.byType(RedoxNavRail),
  matching: find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == icon),
);

void main() {
  testWidgets('TV: raydan Televizyon açılır, seçili öğe değişir; Geri Anasayfa\'ya döner, çıkış uyarısı çıkmaz', (
    tester,
  ) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(_railIcon(RedoxIcons.television));
    await _settle(tester);
    expect(find.byType(TvPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(tester.widget<RedoxNavRail>(find.byType(RedoxNavRail)).selectedIndex, 1);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text(DoubleBackToExit.message), findsNothing);

    // Anasayfada Geri: uyarı.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text(DoubleBackToExit.message), findsOneWidget);
  });

  testWidgets('TV: henüz yazılmamış bölüm "yakında" sayfası açar', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);

    await tester.tap(_railIcon(RedoxIcons.radio));
    await _settle(tester);
    expect(find.byType(SectionPlaceholder), findsOneWidget);
    expect(find.text('Bu bölüm yakında.'), findsOneWidget);
  });

  testWidgets('telefon: alt menüden TV açılır ve seçili görünür; logo Anasayfa\'ya döner', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FormFactor.phone));
    await _settle(tester);
    expect(tester.widget<RedoxBottomBar>(find.byType(RedoxBottomBar)).selectedIndex, -1);

    await tester.tap(find.descendant(of: find.byType(RedoxBottomBar), matching: find.bySemanticsLabel('TV')));
    await _settle(tester);
    expect(find.byType(TvPage), findsOneWidget);
    expect(tester.widget<RedoxBottomBar>(find.byType(RedoxBottomBar)).selectedIndex, 0);

    await tester.tap(find.descendant(of: find.byType(AppHeader), matching: find.bySemanticsLabel('Anasayfa')));
    await _settle(tester);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('telefon: "Diğer" sayfasından Kaynaklar seçilir', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(FormFactor.phone));
    await _settle(tester);

    await tester.tap(find.bySemanticsLabel('Diğer'));
    // İlk kare alt sayfa animasyonunu başlatır; ikincisi bitirir.
    await tester.pump();
    await _settle(tester);
    await tester.tap(find.text('Kaynaklar'));
    // Alt sayfanın kapanış animasyonu da iki karede biter.
    await tester.pump();
    await _settle(tester);
    expect(find.byType(SectionPlaceholder), findsOneWidget);
    expect(find.text('Kaynaklar'), findsOneWidget);
  });
}
