import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';

// M3 Expressive ray ölçüleri (Compose M3 belirteçleri): daralmış 96 dp,
// gösterge 56 x 32, öğe arası 4 dp, üst boşluk 44 dp; açık 220–360 dp.

Widget _rail(FormFactor f, {bool? expanded}) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: f),
  home: Scaffold(
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RedoxNavRail(
          items: AppDestinations.main,
          footer: AppDestinations.footer,
          selectedIndex: 0,
          expanded: expanded,
          onSelected: (_) {},
        ),
      ],
    ),
  ),
);

List<Offset> _iconOrigins(WidgetTester tester) => [
  for (final e in find.byType(RedoxIcon).evaluate())
    if ((e.widget as RedoxIcon).icon != RedoxIcons.menu && (e.widget as RedoxIcon).icon != RedoxIcons.menuOpen)
      (e.renderObject! as RenderBox).localToGlobal(Offset.zero),
];

void _tv(WidgetTester tester) {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('TV, daralmış: ikonlar rayın ortasında, öğeler 48 + 4 dp, menü düğmesi yok', (tester) async {
    _tv(tester);
    await tester.pumpWidget(_rail(FormFactor.tv));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getSize(find.byType(RedoxNavRail)).width, RedoxNavRail.collapsedWidth);
    final icons = _iconOrigins(tester);
    expect(icons, hasLength(9));
    // Gösterge sol kenarı 20, ikon göstergenin 16 dp içinde: 36 = (96 - 24) / 2.
    for (final o in icons) {
      expect(o.dx, RedoxNavRail.indicatorInset + 16);
    }
    expect(icons.first.dy, RedoxNavRail.topSpace + (RedoxNavRail.iconOnlyItemHeight - 24) / 2);
    for (var i = 1; i < 8; i++) {
      expect(icons[i].dy - icons[i - 1].dy, RedoxNavRail.iconOnlyItemHeight + RedoxNavRail.itemSpace);
    }
    // 540 dp'de etiketler sığmaz; daralmışta yalnız ikon.
    expect(find.text('Televizyon').hitTestable(), findsNothing);
    expect(find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == RedoxIcons.menu), findsNothing);
  });

  testWidgets('seçili gösterge: secondaryContainer, 56 x 32 hap', (tester) async {
    _tv(tester);
    await tester.pumpWidget(_rail(FormFactor.tv));
    await tester.pump(const Duration(milliseconds: 500));

    final indicator = find.byWidgetPredicate(
      (w) => w is AnimatedContainer && (w.decoration as BoxDecoration?)?.color == RedoxRoles.secondaryContainer,
    );
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator), const Size(RedoxNavRail.indicatorWidth, RedoxNavRail.indicatorHeight));
  });

  testWidgets('açık: 256 dp, ikonlar yerinde, etiketler görünür', (tester) async {
    _tv(tester);
    await tester.pumpWidget(_rail(FormFactor.tv, expanded: true));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.getSize(find.byType(RedoxNavRail)).width, RedoxNavRail.expandedWidth);
    expect(RedoxNavRail.expandedWidth, inInclusiveRange(220, 360));
    for (final o in _iconOrigins(tester).take(5)) {
      expect(o.dx, RedoxNavRail.indicatorInset + 16);
    }
    expect(find.text('Televizyon'), findsOneWidget);
    final indicator = find.byWidgetPredicate(
      (w) => w is AnimatedContainer && (w.decoration as BoxDecoration?)?.color == RedoxRoles.secondaryContainer,
    );
    expect(tester.getSize(indicator).height, RedoxNavRail.expandedItemHeight);
  });

  testWidgets('tablet: etiketler altta, menü düğmesi rayı açık tutar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_rail(FormFactor.tablet));
    await tester.pump(const Duration(milliseconds: 500));

    // Alttaki etiket (ortalı); yandaki etiket daralmışta göstergeyle kesilir.
    final below = find.byWidgetPredicate((w) => w is Text && w.data == 'Televizyon' && w.textAlign == TextAlign.center);
    expect(below, findsOneWidget);
    expect(tester.getTopLeft(below).dy, greaterThan(tester.getBottomLeft(find.byType(RedoxIcon).at(2)).dy));
    expect(tester.getSize(find.byType(RedoxNavRail)).width, RedoxNavRail.collapsedWidth);

    await tester.tap(find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == RedoxIcons.menu));
    // İlk kare animasyonu başlatır, ikinci kare 400 ms'lik açılışı bitirir.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getSize(find.byType(RedoxNavRail)).width, RedoxNavRail.expandedWidth);
    expect(find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == RedoxIcons.menuOpen), findsOneWidget);
  });
}
