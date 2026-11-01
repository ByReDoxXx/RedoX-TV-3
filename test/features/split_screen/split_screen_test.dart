import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/split_screen/split_screen.dart';
import 'package:redox_tv/features/split_screen/split_screen_page.dart';
import 'package:redox_tv/features/tv/tv_content.dart';

import '../../support/fake_engine.dart';
import '../../support/render.dart';

final _channels = TvContent.preview.channels;

Future<void> _size(WidgetTester tester, Size size) async {
  await loadSora(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(FormFactor f, SplitScreen split, List<FakeEngine> engines, {GlobalKey? boundary}) => RepaintBoundary(
  key: boundary,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RedoxTheme.dark(formFactor: f),
    home: Scaffold(
      body: SplitScreenPage(
        split: split,
        channels: _channels,
        clock: '20:45',
        profileName: 'Profil 1',
        engineFactory: () => FakeEngine()..addTo(engines),
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  test('ekleme: ilk boş karo; 2\'li dolunca 4\'lüye geçer; dörtten fazlası sığmaz', () {
    final s = SplitScreen()..layout = 2;
    expect(s.add(_channels[0]), 0);
    expect(s.add(_channels[0]), 0, reason: 'aynı kanal yerinde kalır');
    expect(s.add(_channels[1]), 1);
    expect(s.add(_channels[2]), 2);
    expect(s.layout, SplitScreen.maxSlots);
    expect(s.add(_channels[3]), 3);
    expect(s.add(_channels[4]), -1);
  });

  testWidgets('karolar açılır; ses yalnız odaktakinden; kaldırınca motor kapanır', (tester) async {
    await _size(tester, const Size(960, 540));
    final split = SplitScreen()
      ..add(_channels[0])
      ..add(_channels[1]);
    final engines = <FakeEngine>[];
    await tester.pumpWidget(_app(FormFactor.tv, split, engines));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(engines, hasLength(2));
    expect(engines[0].opened, [_channels[0].streams.first]);
    expect([for (final e in engines) e.muted], [false, true]);

    // Odak ikinci karoya: ses onunla.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect([for (final e in engines) e.muted], [true, false]);

    // Boş karoya kanal ekle.
    await tester.tap(find.text('Kanal ekle').first);
    await _settle(tester);
    await tester.tap(find.text('${_channels[5].number}  ${_channels[5].name}'));
    await _settle(tester);
    expect(split.slots[2], _channels[5]);
    expect(engines, hasLength(3));

    // Dolu karo: Kaldır.
    await tester.tap(find.text('${_channels[0].number}  ${_channels[0].name}'));
    await _settle(tester);
    await tester.tap(find.text('Kaldır'));
    await _settle(tester);
    expect(split.slots[0], isNull);
    expect(engines[0].disposed, isTrue);
  });

  testWidgets('görüntüler: TV 4\'lü ve 2\'li, telefon', (tester) async {
    await withRealShadows(() async {
      for (final (f, size, name) in const [
        (FormFactor.tv, Size(960, 540), 'tv'),
        (FormFactor.phone, Size(390, 844), 'telefon'),
      ]) {
        await _size(tester, size);
        final key = GlobalKey();
        final split = SplitScreen()
          ..add(_channels[0])
          ..add(_channels[1])
          ..add(_channels[2]);
        await tester.pumpWidget(_app(f, split, [], boundary: key));
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, "build/bolunmus/$name-4lu.png", pixelRatio: 2);
        expect(tester.takeException(), isNull);
        split.layout = 2;
        await settleAssets(tester, rounds: 2);
        await maybeSnapshot(tester, key, "build/bolunmus/$name-2li.png", pixelRatio: 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
