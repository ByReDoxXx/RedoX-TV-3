import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/redox_metrics.dart';
import 'form_factor.dart';

/// Android TV'de fare ve klavye (kullanıcı isteği). Fare kullanılınca arayüz
/// masaüstü biçimine geçer: geri düğmeleri, tıklanır oynatıcı çubuğu, sarma
/// çubuğu, kapat düğmeleri. İlk tuşta kumanda/klavye arayüzüne döner. Fare
/// hiç kullanılmazsa (kumandalı TV) hiçbir şey değişmez.
class MouseMode extends ValueNotifier<bool> {
  MouseMode._() : super(false);

  static final instance = MouseMode._();

  /// Yalnız TV'de: uygulama açılışında bir kez.
  void start() => HardwareKeyboard.instance.addHandler(_onKey);

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) value = false;
    return false;
  }

  /// Telefon kumandasından gelen tuş da kumanda arayüzüne döndürür.
  void keyUsed() => value = false;

  void pointer(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse || e.kind == PointerDeviceKind.trackpad) value = true;
  }

  /// Temanın biçimi: TV farede masaüstü arayüzünü kullanır.
  FormFactor apply(FormFactor f) => f == FormFactor.tv && value ? FormFactor.desktop : f;
}

/// Yazı TV'de her zaman yerel metin kutusundadır, fare kipinde de: Flutter
/// metin alanında Gboard kumandanın yön tuşlarını alamıyor.
bool usesSystemTextInput(BuildContext context) =>
    FormFactor.current == FormFactor.tv || Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.tv;
