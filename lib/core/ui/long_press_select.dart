import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';
import 'redox_icon.dart';

/// Kumandada uzun OK (kullanıcı isteği: "OK uzun basınca favorilere
/// eklesin"). Altındaki odaklanabilir öğenin OK'ini yakalar: kısa basış
/// bırakılınca [onPressed], [holdDuration] basılı tutunca [onLongPress]
/// (bırakınca kısa basış çalışmaz). Varsayılan "OK basılınca etkinleştir"
/// kısayolu aşağı basışta çalıştığından OK burada tutulur ve bırakışta
/// karar verilir. Dokunmatik uzun basış, öğenin kendi `onLongPress`'idir.
///
/// Basılı tutarken öğenin ortasında [icon] ve dolan halka görünür
/// (kullanıcı isteği: "uzun basılınca animasyon olsun"); süre dolunca ikon
/// büyüyüp söner.
class LongPressSelect extends StatefulWidget {
  const LongPressSelect({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.icon = RedoxIcons.star,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final RedoxIcons icon;

  static const holdDuration = Duration(milliseconds: 600);

  static bool isSelect(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  @override
  State<LongPressSelect> createState() => _LongPressSelectState();
}

class _LongPressSelectState extends State<LongPressSelect> with TickerProviderStateMixin {
  /// Basılı tutma: 0 → 1 dolunca uzun basış.
  late final _hold = AnimationController(vsync: this, duration: LongPressSelect.holdDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _fire();
    });

  /// Uzun basış sonrası ikonun büyüyüp sönmesi.
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  bool _down = false;

  /// Bu basışta uzun basış çalıştı: bırakılana kadar yenisi yok (tekrar ve
  /// yinelenen aşağı basış olayları ikinci kez çalıştırıyordu; cihazda görüldü).
  bool _fired = false;

  @override
  void dispose() {
    _hold.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _fire() {
    if (_fired || !_down) return;
    _fired = true;
    _hold.value = 0;
    _pop.forward(from: 0);
    widget.onLongPress?.call();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (widget.onLongPress == null || !LongPressSelect.isSelect(e.logicalKey)) return KeyEventResult.ignored;
    switch (e) {
      case KeyDownEvent():
        if (_down) break;
        _down = true;
        _fired = false;
        _hold.forward(from: 0);
      case KeyRepeatEvent():
        // Android basılı tuşu uzun basış süresi (~500 ms) dolunca tekrarlar:
        // ilk tekrar uzun basıştır (adb --longpress de böyle gönderir).
        if (_hold.isAnimating) {
          _hold.stop();
          _fire();
        }
      case KeyUpEvent():
        // Süre dolmadan bırakıldı: kısa basış.
        if (_down && _hold.isAnimating) widget.onPressed?.call();
        _hold
          ..stop()
          ..value = 0;
        _down = false;
        _fired = false;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _onKey,
    child: Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_hold, _pop]),
              builder: (context, _) {
                final hold = _hold.value, pop = _pop.value;
                final popping = _pop.isAnimating;
                if (hold == 0 && !popping) return const SizedBox.shrink();
                // Doldururken ikon büyür; sonra 1 → 1,6 ölçekte söner.
                final scale = popping ? 1 + 0.6 * pop : 0.7 + 0.3 * hold;
                final opacity = popping ? 1 - pop : 1.0;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45 * (popping ? 1 - pop : hold)),
                    borderRadius: BorderRadius.circular(RedoxRadius.lg),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox.square(
                          dimension: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!popping)
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: hold,
                                    strokeWidth: 4,
                                    color: RedoxSeeds.gold,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                              RedoxIcon(widget.icon, filled: true, size: 28, color: RedoxSeeds.gold),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
