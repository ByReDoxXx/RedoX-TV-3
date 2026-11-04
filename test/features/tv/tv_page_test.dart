
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/reminders.dart';
import 'package:redox_tv/features/shell/reminder_prompt.dart';
import 'package:redox_tv/core/content/favorites.dart';
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
import '../../support/real_list.dart';

Widget _app(
  FormFactor f, {
  Key? boundary,
  TvContent content = TvContent.preview,
  List<FakeEngine>? engines,
  Favorites? favorites,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: RedoxTheme.dark(formFactor: f),
  home: RepaintBoundary(
    key: boundary,
    child: RootShell(
      tv: content,
      initial: AppSection.tv,
      favorites: favorites ?? Favorites(),
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
      // Tam ekran, favori, sonrakini hatırlat ve bölünmüş ekrana ekle.
      expect(buttons, findsNWidgets(4));
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
    'EPG çizelgesi: anahtarla açılır, taşmasız; satıra dokunma kanalı açar (4K görüntü)',
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
      // Odak satır düzeyinde: satıra (kanal + programlar) dokunma kanalı açar.
      await tester.tap(find.bySemanticsLabel(RegExp('^${first.name}')).first);
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
      final content = TvContent.fromM3u(realChannelList.readAsStringSync());
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
    skip: noRealChannelList,
  );

  testWidgets(
    'gerçek liste + yayın akışı: kart, panel ve çizelge programı gösterir (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      await _size(tester, const Size(960, 540));
      final now = DateTime(2026, 10, 31, 20, 15);
      DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 31, h, m);
      final guide = EpgGuide({
        // İlk kart: listenin ilk kanalı.
        EpgGuide.key('TRT 1'): [
          GuideEntry(title: 'Evvel Zaman Tarifleri', start: t(20), stop: t(21), category: 'Belgesel'),
          GuideEntry(title: 'Gizli Oteller', start: t(21), stop: t(22)),
        ],
      });
      final content = TvContent.fromM3u(realChannelList.readAsStringSync()).withGuide(guide, now);
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
    skip: noRealChannelList,
  );

  // Açık katlanabilir telefon (840 dp, tablet düzeni): panel yerine 4 sütun.
  for (final (f, size, columns, preview) in [
    (FormFactor.phone, const Size(360, 780), 2, false),
    (FormFactor.phone, const Size(411, 891), 2, false),
    (FormFactor.tablet, const Size(840, 800), 4, false),
    (FormFactor.tablet, const Size(1280, 800), 4, true),
  ]) {
    testWidgets('${f.name} ${size.width.toInt()} dp: $columns sütun, önizleme ${preview ? 'var' : 'yok'}, taşmasız', (
      tester,
    ) async {
      await loadSora(tester);
      await _size(tester, size);
      final key = GlobalKey();
      await tester.pumpWidget(_app(f, boundary: key));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ChannelPreviewHint), preview ? findsOneWidget : findsNothing);
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
      // Kanal adı her biçimde görünür (telefonda da).
      expect(find.descendant(of: find.byType(EpgGrid), matching: find.text('ULUSAL 1 HD')), findsOneWidget);
      await maybeSnapshot(tester, key, 'build/tv/epg-${f.name}-${size.width.toInt()}.png', pixelRatio: 2);
    });
  }

  testWidgets('TV: uzun OK kanalı favorilere ekler, kısa OK önizler; yıldız işareti çıkar', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    final fav = Favorites();
    await tester.pumpWidget(_app(FormFactor.tv, favorites: fav));
    await _settle(tester);
    final first = TvContent.preview.channels.first;
    // Odak ilk kartta (kumandada D-pad ile gelinir).
    final inside = find.descendant(of: find.byType(ChannelTile).first, matching: find.byType(Column)).first;
    Focus.of(tester.element(inside)).requestFocus();
    await _settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await _settle(tester);
    expect(fav.hasChannel(first.number), isTrue);
    expect(find.textContaining('favorilere eklendi'), findsOneWidget);

    // Kısa OK favoriye dokunmaz.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await _settle(tester);
    expect(fav.hasChannel(first.number), isTrue);
  });

  testWidgets('telefon: yıldıza dokunma favoriye ekler/çıkarır', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(390, 844));
    final fav = Favorites();
    await tester.pumpWidget(_app(FormFactor.phone, favorites: fav));
    await _settle(tester);
    final first = TvContent.preview.channels.first;
    final star = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Favorilere ekle');
    await tester.tap(star.first);
    await _settle(tester);
    expect(fav.hasChannel(first.number), isTrue);
    await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Favorilerden çıkar').first);
    await _settle(tester);
    expect(fav.hasChannel(first.number), isFalse);
  });

  testWidgets('TV: önizlemede "Sonrakini hatırlat" kurar ve kaldırır; vakti gelince kart "İzle" ile kanalı açar', (
    tester,
  ) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    Reminders.instance = Reminders();
    addTearDown(() => Reminders.instance = Reminders());
    final engines = <FakeEngine>[];
    await tester.pumpWidget(_app(FormFactor.tv, engines: engines));
    await _settle(tester);
    final first = TvContent.preview.channels.first;
    await tester.tap(find.byType(ChannelTile).first);
    await _settle(tester);
    Finder label(String l) => find.byTooltip(l);
    await tester.tap(label('Sonrakini hatırlat'));
    await _settle(tester);
    expect(Reminders.instance.items.single.channel, first.number);
    expect(find.textContaining('başlarken hatırlatılacak'), findsOneWidget);
    expect(find.textContaining('hatırlatılacak'), findsWidgets);
    await tester.tap(label('Hatırlatıcıyı kaldır'));
    await _settle(tester);
    expect(Reminders.instance.items, isEmpty);

    // Vakti gelmiş hatırlatıcı (kabuk 20 sn'de bir bakar).
    final r = Reminder(channel: first.number, channelName: first.name, title: 'Gece Haberleri', start: DateTime.now());
    Reminders.instance.toggle(r);
    await tester.pump(const Duration(seconds: 20));
    await _settle(tester);
    expect(find.byType(ReminderCard), findsOneWidget);
    expect(find.text('Gece Haberleri başlıyor'), findsOneWidget);
    await tester.tap(find.text('İzle'));
    await _settle(tester);
    await _settle(tester);
    expect(find.byType(ReminderCard), findsNothing);
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)).channels[tester
          .widget<PlayerPage>(find.byType(PlayerPage))
          .initialIndex],
      first,
    );
    expect(Reminders.instance.items, isEmpty);
  });

  testWidgets('hatırlatıcı kartı Kapat ile ve 30 sn sonra kendiliğinden kapanır', (tester) async {
    await loadSora(tester);
    await _size(tester, const Size(960, 540));
    Reminders.instance = Reminders();
    addTearDown(() => Reminders.instance = Reminders());
    await tester.pumpWidget(_app(FormFactor.tv));
    await _settle(tester);
    final first = TvContent.preview.channels.first;
    Reminders.instance.toggle(
      Reminder(channel: first.number, channelName: first.name, title: 'A', start: DateTime.now()),
    );
    await tester.pump(const Duration(seconds: 20));
    await _settle(tester);
    await tester.tap(find.text('Kapat'));
    await _settle(tester);
    expect(find.byType(ReminderCard), findsNothing);
    expect(find.byType(PlayerPage), findsNothing);

    Reminders.instance.toggle(
      Reminder(channel: first.number, channelName: first.name, title: 'B', start: DateTime.now()),
    );
    await tester.pump(const Duration(seconds: 20));
    await _settle(tester);
    expect(find.text('B başlıyor'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await _settle(tester);
    expect(find.byType(ReminderCard), findsNothing);
  });
}
