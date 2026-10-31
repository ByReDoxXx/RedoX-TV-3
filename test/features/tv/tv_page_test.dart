import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/content/xmltv.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/category_chip.dart';
import 'package:redox_tv/core/ui/channel_tile.dart';
import 'package:redox_tv/core/ui/redox_buttons.dart';
import 'package:redox_tv/core/ui/scroll_hint_row.dart';
import 'package:redox_tv/core/ui/segmented_toggle.dart';
import 'package:redox_tv/features/player/player_page.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';
import 'package:redox_tv/features/tv/tv_page.dart';
import 'package:redox_tv/features/tv/widgets/channel_preview.dart';
import 'package:redox_tv/features/tv/widgets/epg_grid.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

Widget _app(FormFactor f, {Key? boundary, TvContent content = TvContent.preview, List<FakeEngine>? engines}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RedoxTheme.dark(formFactor: f),
      home: RepaintBoundary(
        key: boundary,
        child: RootShell(
          tv: content,
          initial: AppSection.tv,
          // Yerel video kütüphanesi testte yok: sahte motor.
          engineFactory: () => FakeEngine()..addTo(engines),
        ),
      ),
    );

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// Sayfada sonsuz nabız animasyonu var: pumpAndSettle yerine sabit adım. İlk
// kare ayrı: yeni rota ilk karede sahne dışındadır (geçiş hesabı).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  test('kategoriler kanallardaki ilk görülme sırasıyla, tekrarsız', () {
    expect(TvContent.preview.categories, ['Ulusal', 'Haber', 'Spor', 'Belgesel', 'Müzik', 'Çocuk']);
  });

  testWidgets(
    'TV: sayılı çipler, 3 sütunlu logo kartları; panel OK ile dolar, düğmeleri ekranda (4K görüntü)',
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
      final cards = find.byType(ChannelTile);
      final top = tester.getTopLeft(cards.at(0)).dy;
      expect(tester.getTopLeft(cards.at(2)).dy, top);
      expect(tester.getTopLeft(cards.at(3)).dy, greaterThan(top));
      // Açılışta önizleme yok: panelde yönerge durur.
      expect(find.byType(ChannelPreview), findsNothing);
      expect(find.byType(ChannelPreviewHint), findsOneWidget);
      await maybeSnapshot(tester, key, 'build/tv/televizyon-bos-4k.png', pixelRatio: 4);

      await tester.tap(cards.first);
      await settleAssets(tester, rounds: 2);
      expect(tester.widget<ChannelPreview>(find.byType(ChannelPreview)).channel, TvContent.preview.channels.first);
      expect(tester.widget<ChannelTile>(cards.first).selected, isTrue);
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

  testWidgets('ilk OK/dokunma önizler, aynı kanalda ikincisi tam ekran; Geri sayfaya döner', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    final engines = <FakeEngine>[];
    await tester.pumpWidget(_app(FormFactor.tv, engines: engines));
    await _settle(tester);
    final channels = TvContent.preview.channels;
    LiveChannel previewed() => tester.widget<ChannelPreview>(find.byType(ChannelPreview)).channel;

    await tester.tap(find.byType(ChannelTile).at(1));
    await _settle(tester);
    expect(previewed(), channels[1]);
    expect(find.byType(PlayerPage), findsNothing);
    // Önizleme panelde oynar (kullanıcı isteği).
    expect(engines, hasLength(1));
    expect(engines.single.opened.first, channels[1].streams.first);
    expect(tester.widget<ChannelPreview>(find.byType(ChannelPreview)).video, isNotNull);

    // Başka kanal: önizleme değişir, tam ekran açılmaz.
    await tester.tap(find.byType(ChannelTile).at(2));
    await _settle(tester);
    expect(previewed(), channels[2]);
    expect(find.byType(PlayerPage), findsNothing);

    // Aynı kanalda ikinci kez: tam ekran.
    await tester.tap(find.byType(ChannelTile).at(2));
    await _settle(tester);
    final player = tester.widget<PlayerPage>(find.byType(PlayerPage));
    expect(player.channels[player.initialIndex], channels[2]);
    // Tam ekranda önizleme durur (iki yayın birden çözülmesin).
    expect(engines.first.disposed, isTrue);

    // Geri: önce kanal açılışında görünen çubuk kapanır, sonra oynatıcıdan
    // çıkılır; Televizyon (önizleme korunarak) kalır.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(PlayerPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(PlayerPage), findsNothing);
    expect(find.byType(TvPage), findsOneWidget);
    expect(previewed(), channels[2]);
    // Dönüşte önizleme aynı kanalda sürer (yeni motor).
    expect(engines.last.disposed, isFalse);
    expect(engines.last.opened.last, channels[2].streams.first);
  });

  testWidgets(
    'EPG çizelgesi: anahtarla açılır, taşmasız; programa dokunma kanalı açar (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final key = GlobalKey();
      await tester.pumpWidget(_app(FormFactor.tv, boundary: key));
      await _settle(tester);

      // Seçili olmayan görünümün adı yazılıdır.
      await tester.tap(find.text('EPG çizelgesi'));
      await settleAssets(tester, rounds: 2);
      expect(tester.takeException(), isNull);
      expect(find.byType(EpgGrid), findsOneWidget);
      expect(find.byType(ChannelTile), findsNothing);
      expect(find.text('20:45'), findsWidgets); // şimdi hapı (ve saat)
      await maybeSnapshot(tester, key, 'build/tv/epg-4k.png', pixelRatio: 4);

      final first = TvContent.preview.channels.first;
      await tester.tap(find.bySemanticsLabel(RegExp('^${first.programTitle},')));
      await _settle(tester);
      final player = tester.widget<PlayerPage>(find.byType(PlayerPage));
      expect(player.channels[player.initialIndex], first);
    }),
  );

  testWidgets('çip seçimi ızgarayı süzer; "Tümü" geri getirir', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);

    // Kaydırma okları: başta yalnız ">" görünür; sona kayınca "<" da.
    List<double> arrows() => [
      for (final o in tester.widgetList<AnimatedOpacity>(
        find.descendant(of: find.byType(ScrollHintRow), matching: find.byType(AnimatedOpacity)),
      ))
        o.opacity,
    ];
    expect(arrows(), [0, 1]);
    await tester.ensureVisible(find.widgetWithText(CategoryChip, 'Çocuk'));
    await _settle(tester);
    expect(arrows(), [1, 0]);

    // Çipler yatay kayar (sağda görünüm anahtarı): önce görünür kıl.
    await tester.ensureVisible(find.widgetWithText(CategoryChip, 'Spor'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(CategoryChip, 'Spor'));
    await _settle(tester);
    final spor = TvContent.preview.channels.where((c) => c.category == 'Spor').toList();
    expect(find.byType(ChannelTile), findsNWidgets(spor.length));
    expect(find.text('HABER 24'), findsNothing);
    expect(tester.widget<CategoryChip>(find.widgetWithText(CategoryChip, 'Spor')).selected, isTrue);

    await tester.ensureVisible(find.widgetWithText(CategoryChip, 'Tümü'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(CategoryChip, 'Tümü'));
    await _settle(tester);
    expect(find.text('ULUSAL 1 HD'), findsWidgets);
  });

  testWidgets(
    'gerçek liste (yayın akışı yok): kartlar, önizleme ve EPG taşmasız (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final content = TvContent.fromM3u(File('assets/channels/tr.m3u').readAsStringSync());
      final key = GlobalKey();
      await tester.pumpWidget(_app(FormFactor.tv, boundary: key, content: content));
      await settleAssets(tester, rounds: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('TRT Belgesel'), findsOneWidget);
      expect(find.textContaining('akış · Belgesel'), findsOneWidget, reason: 'program yerine akış sayısı ve kategori');

      await tester.tap(find.byType(ChannelTile).first);
      await _settle(tester);
      expect(find.text('Yayın akışı bilgisi yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/tv/televizyon-gercek-4k.png', pixelRatio: 4);

      await tester.tap(find.text('EPG çizelgesi'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Yayın akışı bilgisi yok'), findsWidgets);
      await maybeSnapshot(tester, key, 'build/tv/epg-gercek-4k.png', pixelRatio: 4);
    }),
  );

  testWidgets(
    'gerçek liste + yayın akışı: kart, panel ve çizelge programı gösterir (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final now = DateTime(2026, 10, 31, 20, 15);
      DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 31, h, m);
      final guide = EpgGuide({
        EpgGuide.key('TRT Belgesel'): [
          GuideEntry(title: 'Evvel Zaman Tarifleri', start: t(20), stop: t(21), category: 'Belgesel'),
          GuideEntry(title: 'Gizli Oteller', start: t(21), stop: t(22)),
        ],
      });
      final content = TvContent.fromM3u(File('assets/channels/tr.m3u').readAsStringSync()).withGuide(guide, now);
      final key = GlobalKey();
      await tester.pumpWidget(_app(FormFactor.tv, boundary: key, content: content));
      await settleAssets(tester, rounds: 2);
      expect(find.text('Evvel Zaman Tarifleri'), findsOneWidget, reason: 'kartta şimdiki program');
      expect(find.text('20:15'), findsOneWidget, reason: 'başlık saati akışın "şimdi"si');

      await tester.tap(find.byType(ChannelTile).first);
      await _settle(tester);
      expect(find.text('Evvel Zaman Tarifleri'), findsNWidgets(2), reason: 'kart ve panel');
      expect(find.text('20:00 – 21:00 · Belgesel'), findsOneWidget);
      expect(find.text('Sonraki: 21:00 Gizli Oteller'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/tv/televizyon-akis-4k.png', pixelRatio: 4);

      await tester.tap(find.text('EPG çizelgesi'));
      await _settle(tester);
      expect(find.text('Evvel Zaman Tarifleri'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await maybeSnapshot(tester, key, 'build/tv/epg-akis-4k.png', pixelRatio: 4);
    }),
  );

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
      expect(find.byType(ChannelPreviewHint), TvPage.hasPreview(f) ? findsOneWidget : findsNothing);
      final cards = find.byType(ChannelTile);
      final top = tester.getTopLeft(cards.at(0)).dy;
      expect(tester.getTopLeft(cards.at(columns - 1)).dy, top);
      expect(tester.getTopLeft(cards.at(columns)).dy, greaterThan(top));

      // EPG görünümü de taşmasız.
      await tester.tap(find.byType(SegmentedToggle).first);
      await tester.tap(find.descendant(of: find.byType(SegmentedToggle), matching: find.byType(InkWell)).last);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(EpgGrid), findsOneWidget);
    });
  }
}
