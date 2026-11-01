import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Kumandada uzun OK (kullanıcı isteği: "OK uzun basınca favorilere
/// eklesin"). Altındaki odaklanabilir öğenin OK'ini yakalar: kısa basış
/// bırakılınca [onPressed], [holdDuration] basılı tutunca [onLongPress]
/// (bırakınca kısa basış çalışmaz). Varsayılan "OK basılınca etkinleştir"
/// kısayolu aşağı basışta çalıştığından OK burada tutulur ve bırakışta
/// karar verilir. Dokunmatik uzun basış, öğenin kendi `onLongPress`'idir.
class LongPressSelect extends StatefulWidget {
  const LongPressSelect({super.key, required this.child, this.onPressed, this.onLongPress});

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  static const holdDuration = Duration(milliseconds: 600);

  static bool isSelect(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  @override
  State<LongPressSelect> createState() => _LongPressSelectState();
}

class _LongPressSelectState extends State<LongPressSelect> {
  /// Basılı tutma sayacı; süre dolunca uzun basış.
  Timer? _hold;
  bool _down = false;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (widget.onLongPress == null || !LongPressSelect.isSelect(e.logicalKey)) return KeyEventResult.ignored;
    switch (e) {
      case KeyDownEvent():
        _down = true;
        _hold?.cancel();
        _hold = Timer(LongPressSelect.holdDuration, () => widget.onLongPress?.call());
      case KeyRepeatEvent():
        break;
      case KeyUpEvent():
        // Süre dolmadan bırakıldı: kısa basış.
        if (_down && (_hold?.isActive ?? false)) widget.onPressed?.call();
        _hold?.cancel();
        _down = false;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: widget.child);
}
