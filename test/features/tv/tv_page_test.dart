import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/category_chip.dart';
import 'package:redox_tv/core/ui/channel_card.dart';
import 'package:redox_tv/core/ui/redox_buttons.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/tv_page.dart';
import 'package:redox_tv/features/tv/widgets/channel_preview.dart';

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
    'TV: sayılı çipler, 3 sütunlu ızgara ve önizleme paneli düğmeleriyle ekranda (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final key = GlobalKey();
      await tester.pumpWidget(_app(FormFactor.tv, boundary: key));
      await settleAssets(tester, rounds: 2);
      expect(tester.takeException(), isNull);

      expect(find.byType(CategoryChip), findsNWidgets(TvContent.preview.categories.length + 1));
      expect(tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'Tümü')).count, 20);
      // İlk satırda üç kart, dördüncü alt satırda; önizleme ilk kanalı gösterir.
      final cards = find.byType(ChannelCard);
      final top = tester.getTopLeft(cards.at(0)).dy;
      expect(tester.getTopLeft(cards.at(2)).dy, top);
      expect(tester.getTopLeft(cards.at(3)).dy, greaterThan(top));
      expect(tester.widget<ChannelPreview>(find.byType(ChannelPreview)).channel, TvContent.preview.channels.first);
      // Önizleme düğmeleri kaydırmadan ekranda, panelin içinde.
      final panel = tester.getRect(find.byType(ChannelPreview));
      expect(panel.bottom, lessThanOrEqualTo(540));
      final buttons = find.descendant(
        of: find.byType(ChannelPreview),
        matching: find.byWidgetPredicate((w) => w is PrimaryButton || w is GlassButton),
      );
      expect(buttons, findsNWidgets(3));
      for (final rect in buttons.evaluate().map((e) => tester.getRect(find.byWidget(e.widget)))) {
        expect(rect.bottom, lessThanOrEqualTo(panel.bottom));
      }
      expect(find.text('Sonraki: ${TvContent.preview.channels.first.next}'), findsWidgets);
      await maybeSnapshot(tester, key, 'build/tv/televizyon-4k.png', pixelRatio: 4);
    }),
  );

  testWidgets('önizleme odaktaki ve dokunulan kartı izler', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);
    final channels = TvContent.preview.channels;
    LiveChannel previewed() => tester.widget<ChannelPreview>(find.byType(ChannelPreview)).channel;

    // Dokunma: ilk dokunuş önizler.
    await tester.tap(find.byType(ChannelCard).at(1));
    await _settle(tester);
    expect(previewed(), channels[1]);

    // D-pad odağı: odaklanan kart önizlemeye gelir.
    final inkWell = find.descendant(of: find.byType(ChannelCard).at(2), matching: find.byType(InkWell));
    Focus.of(tester.element(find.descendant(of: inkWell, matching: find.byType(Column)).first)).requestFocus();
    await _settle(tester);
    expect(previewed(), channels[2]);
  });

  testWidgets('çip seçimi ızgarayı süzer; "Tümü" geri getirir', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);

    await tester.tap(find.widgetWithText(CategoryChip, 'Spor'));
    await _settle(tester);
    final spor = TvContent.preview.channels.where((c) => c.category == 'Spor').toList();
    expect(find.byType(ChannelCard), findsNWidgets(spor.length));
    expect(find.text('HABER 24'), findsNothing);
    expect(tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'Spor')).selected, isTrue);

    await tester.tap(find.widgetWithText(CategoryChip, 'Tümü'));
    await _settle(tester);
    expect(find.text('ULUSAL 1 HD'), findsWidgets);
  });

  for (final (f, size) in [
    (FormFactor.phone, const Size(360, 780)),
    (FormFactor.phone, const Size(411, 891)),
    (FormFactor.tablet, const Size(1280, 800)),
  ]) {
    final columns = TvPage.columnsFor(f);
    testWidgets('${f.name} ${size.width.toInt()} dp: $columns sütun, taşmasız', (tester) async {
      await loadSora(tester);
      await _size(tester, size);
      await tester.pumpWidget(_app(f));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ChannelPreview), TvPage.hasPreview(f) ? findsOneWidget : findsNothing);
      final cards = find.byType(ChannelCard);
      final top = tester.getTopLeft(cards.at(0)).dy;
      expect(tester.getTopLeft(cards.at(columns - 1)).dy, top);
      expect(tester.getTopLeft(cards.at(columns)).dy, greaterThan(top));
    });
  }
}
