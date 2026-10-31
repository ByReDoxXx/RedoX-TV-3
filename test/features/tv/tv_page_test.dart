import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/category_chip.dart';
import 'package:redox_tv/core/ui/channel_card.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/tv_page.dart';

import '../../support/render.dart';

Widget _app(FormFactor f, {Key? boundary}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: RedoxTheme.dark(formFactor: f),
  home: RepaintBoundary(
    key: boundary,
    child: const RootShell(home: HomeContent.preview, tv: TvContent.preview, initial: AppSection.tv),
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// Sayfada sonsuz nabız animasyonu var: pumpAndSettle yerine sabit adım.
Future<void> _settle(WidgetTester tester) => tester.pump(const Duration(milliseconds: 600));

void main() {
  test('kategoriler kanallardaki ilk görülme sırasıyla, tekrarsız', () {
    expect(TvContent.preview.categories, ['Ulusal', 'Haber', 'Spor', 'Belgesel', 'Müzik', 'Çocuk']);
  });

  testWidgets(
    'TV: başlık, "Tümü" + kategori çipleri, 4 sütunlu ızgara taşmasız (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final key = GlobalKey();
      await tester.pumpWidget(_app(FormFactor.tv, boundary: key));
      await settleAssets(tester, rounds: 2);
      expect(tester.takeException(), isNull);

      expect(find.text('Televizyon'), findsWidgets);
      expect(find.text('${TvContent.preview.channels.length} kanal'), findsOneWidget);
      expect(find.byType(CategoryChip), findsNWidgets(TvContent.preview.categories.length + 1));
      // İlk satırdaki dört kart aynı hizada, beşinci alt satırda.
      final cards = find.byType(ChannelCard);
      final top = tester.getTopLeft(cards.at(0)).dy;
      for (var i = 1; i < 4; i++) {
        expect(tester.getTopLeft(cards.at(i)).dy, top);
      }
      expect(tester.getTopLeft(cards.at(4)).dy, greaterThan(top));
      await maybeSnapshot(tester, key, 'build/tv/televizyon-4k.png', pixelRatio: 4);
    }),
  );

  testWidgets('çip seçimi ızgarayı süzer; "Tümü" geri getirir', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);

    await tester.tap(find.widgetWithText(CategoryChip, 'Spor'));
    await _settle(tester);
    final spor = TvContent.preview.channels.where((c) => c.category == 'Spor').toList();
    expect(find.text('${spor.length} kanal'), findsOneWidget);
    expect(find.byType(ChannelCard), findsNWidgets(spor.length));
    expect(find.text('HABER 24'), findsNothing);
    expect(tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'Spor')).selected, isTrue);

    await tester.tap(find.widgetWithText(CategoryChip, 'Tümü'));
    await _settle(tester);
    expect(find.text('${TvContent.preview.channels.length} kanal'), findsOneWidget);
  });

  for (final (f, size, columns) in [
    (FormFactor.phone, const Size(360, 780), 2),
    (FormFactor.phone, const Size(411, 891), 2),
    (FormFactor.tablet, const Size(1280, 800), 4),
  ]) {
    testWidgets('${f.name} ${size.width.toInt()} dp: $columns sütun, taşmasız', (tester) async {
      await loadSora(tester);
      await _size(tester, size);
      await tester.pumpWidget(_app(f));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(TvPage.columnsFor(f), columns);
      final cards = find.byType(ChannelCard);
      final top = tester.getTopLeft(cards.at(0)).dy;
      expect(tester.getTopLeft(cards.at(columns - 1)).dy, top);
      expect(tester.getTopLeft(cards.at(columns)).dy, greaterThan(top));
    });
  }
}
