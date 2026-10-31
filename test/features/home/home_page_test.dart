import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_colors.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/core/ui/redox_buttons.dart';
import 'package:redox_tv/core/ui/redox_icon.dart';
import 'package:redox_tv/features/home/home_content.dart';
import 'package:redox_tv/features/home/home_page.dart';
import 'package:redox_tv/features/home/widgets/hero_banner.dart';
import 'package:redox_tv/features/home/widgets/home_header.dart';

import '../../support/render.dart';

Widget _app(Key boundary, {bool previewFocus = false}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: RedoxTheme.dark(),
  home: RepaintBoundary(
    key: boundary,
    child: HomePage(content: HomeContent.preview, previewFocus: previewFocus),
  ),
);

/// Anasayfa, Android TV tuvalinde (960×540 dp) çizilir.
/// REDOX_SNAPSHOT=1: build/home/anasayfa-4k.png (ilk ekran, 4x = 3840×2160)
/// ve build/home/anasayfa-tam.png (tüm sayfa, 2x).
void main() {
  testWidgets(
    'TV ilk ekranı taşmasız çizilir (4K görüntü)',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(_app(key, previewFocus: true));
      await settleAssets(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Şampiyonlar Ligi — Çeyrek Final'), findsOneWidget);
      // Hikâye yuvası daraltıldı; en uzun etiket yine kesilmeden sığar.
      expect(tester.renderObject<RenderParagraph>(find.text('Çoklu ekran')).didExceedMaxLines, isFalse);
      await maybeSnapshot(tester, key, 'build/home/anasayfa-4k.png', pixelRatio: 4);
    }),
  );

  testWidgets(
    'tüm sayfa taşmasız çizilir',
    (tester) => withRealShadows(() async {
      await loadSora(tester);
      // Kaydırmasız tam boy: TV genişliği, içerik yüksekliği kadar uzun görünüm.
      tester.view.physicalSize = const Size(960, 1560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(_app(key, previewFocus: true));
      await settleAssets(tester);

      expect(tester.takeException(), isNull);
      for (final title in [
        'Son izlenen kanallar',
        'İzlemeye devam et',
        'Son dinlenen radyolar',
        'Son izlenen filmler',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      await maybeSnapshot(tester, key, 'build/home/anasayfa-tam.png', pixelRatio: 2);
    }),
  );

  testWidgets('menüde üstüne gelinen öğe sağa açılıp adını gösterir, ayrılınca kapanır', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GlobalKey()));
    await settleAssets(tester, rounds: 2);

    final rail = find.descendant(of: find.byType(RedoxNavRail), matching: find.byType(AnimatedContainer)).first;
    double railWidth() => tester.getSize(rail).width;
    final floating = find.byWidgetPredicate(
      (w) => w is AnimatedContainer && (w.decoration as BoxDecoration?)?.color == RedoxRoles.surfaceContainerHighest,
    );
    expect(floating, findsNothing);

    // Sayfada sonsuz nabız animasyonu var: pumpAndSettle yerine açılış süresinden
    // uzun sabit adım (400 ms).
    Future<void> settle() => tester.pump(const Duration(milliseconds: 600));

    // Televizyon ikonunun üstüne gel: yalnızca o öğe sağa açılır, ray daralmış kalır.
    final tvIcon = tester.getCenter(
      find.descendant(
        of: find.byType(RedoxNavRail),
        matching: find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == RedoxIcons.television),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(700, 300));
    await mouse.moveTo(tvIcon);
    await tester.pump();
    await settle();
    expect(railWidth(), RedoxNavRail.collapsedWidth);
    expect(floating, findsOneWidget);
    expect(tester.getSize(floating).width, greaterThan(RedoxNavRail.collapsedWidth));
    final label = find.descendant(of: find.byType(RedoxNavRail), matching: find.text('Televizyon'));
    expect(
      tester.widget<AnimatedOpacity>(find.ancestor(of: label, matching: find.byType(AnimatedOpacity)).first).opacity,
      1,
    );

    await mouse.moveTo(const Offset(700, 300));
    await tester.pump();
    await settle();
    expect(floating, findsNothing);
  });

  testWidgets('telefon: ray yok, alt menü var, sayfa taşmasız; Diğer alt sayfayı açar', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.phone),
        home: const HomePage(content: HomeContent.preview),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(RedoxNavRail), findsNothing);
    expect(find.byType(RedoxBottomBar), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Diğer'));
    await tester.pump(const Duration(milliseconds: 600));
    for (final item in AppDestinations.phoneMore) {
      expect(find.text(item.label), findsOneWidget, reason: item.label);
    }
  });

  testWidgets('tablet: arama kutusu saate kadar uzanır', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tablet),
        home: const HomePage(content: HomeContent.preview),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    final search = tester.getRect(find.byType(TextField));
    final clockIcon = tester.getRect(
      find.byWidgetPredicate((w) => w is RedoxIcon && w.icon == RedoxIcons.clock).first,
    );
    // Arama ile saat hapı arasında 16 dp; hap kenarı 1 + iç boşluğu 14 dp.
    expect(clockIcon.left - 15 - search.right, closeTo(16, 0.01));

    // Vitrin içerik genişliğinin tamamını kaplar (düğmeler Wrap'te olsa da).
    expect(tester.getSize(find.byType(HeroBanner)).width, tester.getSize(find.byType(HomeHeader)).width);
  });

  testWidgets('D-pad: açılışta vitrin düğmesi odakta; sol seçili menü öğesine (Anasayfa) gider', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(GlobalKey()));
    await tester.pump(const Duration(milliseconds: 600));

    // Odaktaki öğe hangi bileşenin içinde?
    bool focusInside<T extends Widget>() =>
        FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<T>() != null;

    // Odaktaki menü öğesinin adı (öğe Semantics etiketi).
    String? focusedRailLabel() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context?.findAncestorWidgetOfExactType<RedoxNavRail>() == null) return null;
      return context!.findAncestorWidgetOfExactType<Semantics>()?.properties.label;
    }

    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(focusInside<PrimaryButton>(), isTrue);
    // Vitrin düğmesinin solundaki en yakın öğe Kaynaklar'dır; odak yine de
    // seçili bölüme (Anasayfa) gider.
    await press(LogicalKeyboardKey.arrowLeft);
    expect(focusedRailLabel(), 'Anasayfa');
    // Ray içinde aşağı: yönlendirme yok, bir sonraki öğe.
    await press(LogicalKeyboardKey.arrowDown);
    expect(focusedRailLabel(), 'Televizyon');
    // Sağ: odak içeriğe döner.
    await press(LogicalKeyboardKey.arrowRight);
    expect(focusInside<RedoxNavRail>(), isFalse);
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
  });
}
