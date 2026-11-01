import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/profiles.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/theme/redox_theme.dart';
import 'package:redox_tv/features/settings/parent_pin_tab.dart';

import '../../support/render.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Kumandanın rakam tuşlarıyla PIN girer.
Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)));
  }
  await _settle(tester);
}

Future<ProfileStore> _open(WidgetTester tester, {String? pin}) async {
  await loadSora(tester);
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = ProfileStore();
  if (pin != null) await tester.runAsync(() => store.setPin(pin));
  await tester.pumpWidget(
    MaterialApp(
      theme: RedoxTheme.dark(formFactor: FormFactor.tv),
      home: Scaffold(body: ParentPinTab(store: store)),
    ),
  );
  await _settle(tester);
  return store;
}

void main() {
  testWidgets('değiştir: önce mevcut PIN, sonra yeni PIN iki kez; yanlış PIN değiştirmez', (tester) async {
    final store = await _open(tester, pin: '1234');
    expect(find.text("PIN'i kaldır"), findsOneWidget);

    await tester.tap(find.text("PIN'i değiştir"));
    await _settle(tester);
    await tester.runAsync(() => _typePin(tester, '1234'));
    await _settle(tester);
    await _typePin(tester, '5678');
    await _typePin(tester, '5678');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(await tester.runAsync(() => store.checkPin('5678')), isTrue);
    expect(await tester.runAsync(() => store.checkPin('1234')), isFalse);
  });

  testWidgets('kaldır: mevcut PIN ile; sonra yalnız "PIN belirle"', (tester) async {
    final store = await _open(tester, pin: '1234');
    await tester.tap(find.text("PIN'i kaldır"));
    await _settle(tester);
    await tester.runAsync(() => _typePin(tester, '1234'));
    await _settle(tester);
    expect(store.hasPin, isFalse);
    expect(find.text('PIN belirle'), findsOneWidget);
    expect(find.text("PIN'i kaldır"), findsNothing);
  });
}
