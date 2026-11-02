import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/platform/device_controls.dart';
import 'package:redox_tv/core/remote/remote_input.dart';
import 'package:redox_tv/core/remote/remote_key.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/features/remote/remote_text_dialog.dart';

Widget _app(Widget home) => MaterialApp(
  theme: RedoxTheme.dark(formFactor: FormFactor.tv),
  home: home,
);

void main() {
  testWidgets('yön tuşları odağı gezdirir, OK odaktaki düğmeyi etkinleştirir', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Column(
            children: [
              TextButton(autofocus: true, onPressed: () => pressed.add('üst'), child: const Text('Üst')),
              TextButton(onPressed: () => pressed.add('alt'), child: const Text('Alt')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    RemoteInput.press(RemoteKey.down);
    await tester.pump();
    RemoteInput.press(RemoteKey.ok);
    await tester.pump();
    expect(pressed, ['alt']);
    RemoteInput.press(RemoteKey.up);
    await tester.pump();
    RemoteInput.press(RemoteKey.ok);
    await tester.pump();
    expect(pressed, ['alt', 'üst']);
  });

  testWidgets('oynatıcı kısayolları: kanal, rakam (karakteriyle), oynat/duraklat', (tester) async {
    final got = <(LogicalKeyboardKey, String?)>[];
    await tester.pumpWidget(
      _app(
        Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent) got.add((e.logicalKey, e.character));
            return KeyEventResult.handled;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    for (final k in [RemoteKey.channelUp, RemoteKey.digit(7), RemoteKey.playPause]) {
      expect(RemoteInput.press(k), isTrue);
    }
    expect(got, [
      (LogicalKeyboardKey.channelUp, null),
      (LogicalKeyboardKey.digit7, '7'),
      (LogicalKeyboardKey.mediaPlayPause, null),
    ]);
  });

  testWidgets('Geri açık sayfayı kapatır; ses cihaz sesini adım adım değiştirir', (tester) async {
    DeviceControls.debugValues = {'ses': 0.5};
    addTearDown(() => DeviceControls.debugValues = null);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: const Text('Kök')));
    unawaited(nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Text('İkinci'))));
    await tester.pumpAndSettle();
    await RemoteInput.handle(RemoteKey.back, onHome: () {});
    await tester.pumpAndSettle();
    expect(find.text('Kök'), findsOneWidget);
    await RemoteInput.handle(RemoteKey.volumeUp, onHome: () {});
    expect(DeviceControls.debugValues!['ses'], closeTo(0.5 + RemoteInput.volumeStep, 1e-9));
    var home = 0;
    await RemoteInput.handle(RemoteKey.home, onHome: () => home++);
    expect(home, 1);
  });

  testWidgets('yazı: odaktaki metin alanına; yazı penceresi açıksa ona', (tester) async {
    final text = TextEditingController();
    await tester.pumpWidget(_app(Scaffold(body: TextField(controller: text, autofocus: true))));
    await tester.pump();
    expect(RemoteInput.type('Show TV'), isTrue);
    expect(text.text, 'Show TV');

    late BuildContext ctx;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(RemoteInput.type('boşa'), isFalse);
    String? result;
    unawaited(RemoteTextDialog.show(ctx, title: 'Adres').then((v) => result = v));
    await tester.pumpAndSettle();
    expect(find.text('Yazı bekleniyor…'), findsOneWidget);
    expect(RemoteInput.type('http://ornek.tv/liste.m3u'), isTrue);
    await tester.pump();
    expect(find.text('http://ornek.tv/liste.m3u'), findsOneWidget);
    RemoteInput.press(RemoteKey.ok);
    await tester.pumpAndSettle();
    expect(result, 'http://ornek.tv/liste.m3u');
    expect(RemoteInput.textTarget, isNull);
  });
}
