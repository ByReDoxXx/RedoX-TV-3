import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/navigation/double_back_to_exit.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/header_search.dart';

// TV emülatöründe görülen iki sorun: D-pad kutunun üstünden geçerken klavye
// açılıyordu; Geri ilk basışta klavyeyi, ikincide uygulamayı kapatıyordu.

Widget _app() => MaterialApp(
  theme: RedoxTheme.dark(formFactor: FormFactor.tv),
  home: DoubleBackToExit(
    child: Scaffold(
      body: Column(
        children: [
          const SizedBox(width: 400, child: HeaderSearch()),
          TextButton(onPressed: () {}, autofocus: true, child: const Text('Alttaki')),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('D-pad kutuya gelince klavye açılmaz; OK yazmayı başlatır; Geri yazmayı bitirir', (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump();

    // Yukarı: odak kutuya geçer, ama metin alanı (klavye bağlantısı) yok.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<HeaderSearch>(), isNotNull);

    // OK (select): yazma kipi, alan odakta, klavye görünür.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField), 'spor');
    await tester.pump();

    // Geri: yazma biter, odak kutuya döner, yazılan kalır; uyarı çıkmaz.
    // Kumanda Geri'si Android'de "pop" olarak gelir: yazma biter, odak
    // kutuya döner, yazılan kalır; çıkış uyarısı çıkmaz.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('spor'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<HeaderSearch>(), isNotNull);
    expect(find.text(DoubleBackToExit.message), findsNothing);

    // Klavyeli cihazda Esc de yazmayı bitirir.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('kök sayfada Geri: ilk basışta uyarı, ikincide çıkış', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_app());
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text(DoubleBackToExit.message), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, contains('SystemNavigator.pop'));
  });
}
