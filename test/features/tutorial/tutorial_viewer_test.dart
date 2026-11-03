import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/tutorial/tutorial_stories.dart';
import 'package:redox_tv/features/tutorial/tutorial_viewer.dart';

import '../../support/render.dart';

void main() {
  test('her sayfanın görüntüsü ve vurgusu her cihazın manifestinde var', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final folder in const ['tv', 'tablet', 'telefon']) {
      final manifest = await TutorialManifest.load(folder);
      for (final story in TutorialStories.all) {
        for (final slide in story.slides) {
          expect(manifest.containsKey(slide.shot), isTrue, reason: '$folder ${slide.shot}');
          await rootBundle.load('assets/tutorial/$folder/${slide.shot}.webp');
          if (slide.highlight case final h?) {
            expect(manifest[slide.shot]!.containsKey(h), isTrue, reason: '$folder $h');
          }
        }
      }
    }
  });

  for (final (f, size, name) in const [
    (FormFactor.tv, Size(960, 540), 'tv'),
    (FormFactor.tablet, Size(1280, 800), 'tablet'),
    (FormFactor.phone, Size(390, 844), 'telefon'),
  ]) {
    testWidgets('$name: hikâye sayfaları geçer, son bölümden sonra kapanır; "bölüme git"', (tester) async {
      await withRealShadows(() async {
        await loadSora(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        AppSection? went;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: RedoxTheme.dark(formFactor: f),
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTutorial(context, stories: TutorialStories.all, start: 1, onGo: (s) => went = s),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Aç'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await settleAssets(tester, rounds: 3);
        expect(find.text('TELEVIZYON'), findsOneWidget);
        expect(find.text('Kanallar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await maybeSnapshot(tester, key, 'build/egitim-ekran/$name-1.png', pixelRatio: 2);

        // Sonraki sayfa: kumandada OK/sağ, dokunmatikte sağa dokunma.
        if (f == FormFactor.tv) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        } else {
          await tester.tapAt(Offset(size.width * 0.8, size.height * 0.5));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('İzle'), findsOneWidget);

        // Sayfa kendiliğinden geçer.
        await tester.pump(TutorialViewer.slideDuration);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Yayın akışı'), findsOneWidget);
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, 'build/egitim-ekran/$name-2.png', pixelRatio: 2);

        // Bölüme git: TV'de yukarı, dokunmatikte düğme.
        if (f == FormFactor.tv) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        } else {
          await tester.tap(find.text('Televizyon bölümüne git'));
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(went, AppSection.tv);
        expect(find.byType(TutorialViewer), findsNothing);
        expect(TutorialSeen.instance.value, contains(AppSection.tv));
      });
    });
  }
}
