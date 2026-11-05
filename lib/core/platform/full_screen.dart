import 'package:flutter/services.dart';

import '../layout/form_factor.dart';

/// Oynatıcı ekranlarında telefon ve tabletin sistem çubuklarını gizler (alt
/// gezinme çubuğu, görev çubuğu, durum çubuğu). Kenardan kaydırınca kısa süre
/// görünür, kendiliğinden gizlenir. Üst üste açılan oynatıcı ekranları sayılır:
/// sonuncusu kapanınca çubuklar geri gelir. TV'de ve masaüstünde sistem çubuğu
/// yoktur, dokunulmaz.
abstract final class FullScreen {
  static int _depth = 0;

  static bool get _applies => switch (FormFactor.current) {
    FormFactor.phone || FormFactor.tablet => true,
    FormFactor.tv || FormFactor.desktop => false,
  };

  static Future<void> enter() async {
    if (!_applies || _depth++ > 0) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static Future<void> leave() async {
    if (!_applies || _depth == 0 || --_depth > 0) return;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }
}
