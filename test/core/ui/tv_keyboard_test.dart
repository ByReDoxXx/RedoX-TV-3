import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/core/ui/tv_keyboard.dart';
import 'package:redox_tv/features/profiles/widgets/profile_editor.dart';

import '../../support/render.dart';

Future<TextEditingController> _open(WidgetTester tester, {int? maxLength}) async {
  await loadSora(tester);
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = TextEditingController();
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: RedoxTheme.dark(formFactor: FormFactor.tv),
      home: Scaffold(
        body: Center(child: TvKeyboard(controller: c, maxLength: maxLength, autofocus: true)),
      ),
    ),
  );
  await tester.pump();
  return c;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump();
}

void main() {
  testWidgets('kelime başı kendiliğinden büyük; Türkçe "i" → "İ"', (tester) async {
    final c = await _open(tester);
    for (final k in ['İ', 'p', 'e', 'k']) {
      await _tap(tester, k);
    }
    await _tap(tester, 'Boşluk');
    await _tap(tester, 'Ş');
    await _tap(tester, 'u');
    expect(c.text, 'İpek Şu');
  });

  testWidgets('⇧ tek harf için büyüklüğü tersine çevirir; sil son harfi siler', (tester) async {
    final c = await _open(tester);
    await _tap(tester, 'Büyük harf');
    await _tap(tester, 'ı');
    await _tap(tester, 'a');
    expect(c.text, 'ıa');
    await _tap(tester, 'Sil');
    expect(c.text, 'ı');
  });

  testWidgets('rakamlar ve uzunluk sınırı', (tester) async {
    final c = await _open(tester, maxLength: 3);
    for (final k in ['1', '2', '3', '4']) {
      await _tap(tester, k);
    }
    expect(c.text, '123');
  });

  testWidgets('fiziksel klavye ve kumanda rakamları yazar; yön tuşları gezinir', (tester) async {
    final c = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(c.text, 'k');
    // Odak "a"dan sağa, "s"ye geçti; OK basar.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.text, 'ks');
  });

  testWidgets('TV düzenleyicisinde sistem metin alanı yok; klavye sığar', (tester) async {
    await loadSora(tester);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: RedoxTheme.dark(formFactor: FormFactor.tv),
        home: const Scaffold(body: ProfileEditor()),
      ),
    );
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TvKeyboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
