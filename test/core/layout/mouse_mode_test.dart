import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/layout/form_factor.dart';
import 'package:redox_tv/core/layout/mouse_mode.dart';

void main() {
  final mode = MouseMode.instance;
  tearDown(() => mode.value = false);

  test('fare TV arayüzünü masaüstüne geçirir; diğer biçimler değişmez', () {
    expect(mode.apply(FormFactor.tv), FormFactor.tv);
    mode.pointer(const PointerHoverEvent(kind: PointerDeviceKind.mouse));
    expect(mode.apply(FormFactor.tv), FormFactor.desktop);
    expect(mode.apply(FormFactor.phone), FormFactor.phone);
    expect(mode.apply(FormFactor.tablet), FormFactor.tablet);
  });

  test('dokunma fare sayılmaz', () {
    mode.pointer(const PointerDownEvent(kind: PointerDeviceKind.touch));
    expect(mode.value, isFalse);
  });

  testWidgets('tuşa basınca kumanda arayüzüne döner', (tester) async {
    mode.start();
    mode.pointer(const PointerHoverEvent(kind: PointerDeviceKind.mouse));
    expect(mode.value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(mode.value, isFalse);
  });
}
