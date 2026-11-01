import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/favorites.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/destinations.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';
import 'package:redox_tv/core/theme/redox_metrics.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/bottom_nav_bar.dart';
import 'package:redox_tv/core/ui/nav_rail.dart';
import 'package:redox_tv/features/shell/root_shell.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/fake_radio_audio.dart';
import '../../support/render.dart';

/// Katlanabilir telefon (Pixel 9 Pro Fold): kapalı dış ekran ve açık iç ekran
/// (dp). Telefon APK'sı açıkken tablet düzenine geçer (FormFactor.forWindow).
const _folded = Size(411, 923);
const _open = Size(840, 800);

final _stations = [
  for (var i = 1; i <= 12; i++)
    LiveChannel(
      name: ['Yıldız Pop', 'Anadolu Türküleri', 'Gündem Radyo', 'Kıyı Hit'][i % 4],
      number: i,
      category: 'Pop',
      streams: ['s$i'],
    ),
];

Widget _app(Size size, AppSection section, {GlobalKey? boundary}) {
  final audio = FakeRadioAudio();
  final radio = RadioController(stations: ValueNotifier(_stations), audio: () => audio);
  addTearDown(radio.dispose);
  return RepaintBoundary(
    key: boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      theme: RedoxTheme.dark(formFactor: FormFactor.forWindow(FormFactor.phone, size)),
      home: RootShell(
        tv: TvContent.preview,
        initial: section,
        radio: radio,
        favorites: Favorites(channels: const [1, 2, 3], radios: const [1, 2]),
        engineFactory: FakeEngine.new,
      ),
    ),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  test('telefon APK\'sı geniş pencerede tablet düzeni; TV ve tablet sabit', () {
    expect(FormFactor.forWindow(FormFactor.phone, _folded), FormFactor.phone);
    expect(FormFactor.forWindow(FormFactor.phone, _open), FormFactor.tablet);
    expect(FormFactor.forWindow(FormFactor.phone, const Size(900, 412)), FormFactor.phone, reason: 'yatay telefon');
    expect(FormFactor.forWindow(FormFactor.tv, const Size(960, 540)), FormFactor.tv);
  });

  testWidgets('Fold açık: sol ray, taşma yok; kapalı: alt menü', (tester) async {
    await _size(tester, _open);
    await tester.pumpWidget(_app(_open, AppSection.tv));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(RedoxNavRail), findsOneWidget);
    expect(find.byType(RedoxBottomBar), findsNothing);

    await _size(tester, _folded);
    await tester.pumpWidget(_app(_folded, AppSection.tv));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(RedoxBottomBar), findsOneWidget);
    expect(Theme.of(tester.element(find.byType(RootShell))).extension<RedoxMetrics>()!.formFactor, FormFactor.phone);
  });

  testWidgets('görüntüler: Fold açık ve kapalı', (tester) async {
    await withRealShadows(() async {
      for (final (name, size) in [('acik', _open), ('kapali', _folded)]) {
        await _size(tester, size);
        for (final section in [AppSection.home, AppSection.tv, AppSection.radio, AppSection.favorites]) {
          final key = GlobalKey();
          await tester.pumpWidget(_app(size, section, boundary: key));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: '$name ${section.name}');
          await maybeSnapshot(tester, key, 'build/fold/$name-${section.name}.png', pixelRatio: 1.5);
        }
      }
    });
  });
}
