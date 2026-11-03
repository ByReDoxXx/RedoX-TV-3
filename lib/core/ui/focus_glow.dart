import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringSimulation;

import '../theme/m3e_motion.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_metrics.dart';

/// Odak geri bildirimi (DESIGN.md "Focus Elevation"): yay fiziğiyle büyüme,
/// 2px kızıl dış halka, aura + ışıma. D-pad/klavye odağı ve fare üstü "odak"
/// sayılır; dokunmatik kipte odak halkası gösterilmez.
///
/// Kendisi odak almaz; alt ağaçtaki odaklanabilir öğeyi (düğme, InkWell) izler.
class FocusGlow extends StatefulWidget {
  const FocusGlow({super.key, required this.borderRadius, required this.builder, this.focused, this.scale});

  final BorderRadius borderRadius;

  /// İçerik; `active` odakta (veya fare üstünde) olup olmadığını söyler.
  final Widget Function(BuildContext context, bool active) builder;

  /// null: odaktan ve fare üstünden otomatik. true/false: dışarıdan sabit.
  final bool? focused;

  /// null: temadaki RedoxMetrics.focusScale.
  final double? scale;

  @override
  State<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends State<FocusGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _hasFocus = false;
  bool _hovered = false;
  bool _initialized = false;
  double _target = 1;

  bool get _active =>
      widget.focused ??
      ((_hasFocus && FocusManager.instance.highlightMode == FocusHighlightMode.traditional) || _hovered);

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // İlk çizimde hedef ölçek animasyonsuz uygulanır.
    _sync(animate: _initialized);
    _initialized = true;
  }

  @override
  void didUpdateWidget(FocusGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _scale.dispose();
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode _) {
    setState(() {});
    _sync();
  }

  void _setFocus(bool value) {
    if (value == _hasFocus) return;
    setState(() => _hasFocus = value);
    _sync();
  }

  void _setHover(bool value) {
    setState(() => _hovered = value);
    _sync();
  }

  void _sync({bool animate = true}) {
    final scale = widget.scale ?? Theme.of(context).extension<RedoxMetrics>()?.focusScale ?? 1;
    final target = _active ? scale : 1.0;
    if (target == _target && _initialized) return;
    _target = target;
    if (!animate || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(SpringSimulation(M3EMotion.spatialFast, _scale.value, target, _scale.velocity));
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _setFocus,
      child: MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: ScaleTransition(
          scale: _scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: active ? RedoxElevation.focusGlow : null,
            ),
            child: Stack(
              // passthrough: içerik, FocusGlow'a gelen kısıtı aynen alır
              // (varsayılan "loose" kartları içeriğe büzerdi).
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              children: [
                widget.builder(context, active),
                // Halka öğeden 2 dp açıkta (M3 odak göstergesi ofseti): kızıl
                // dolgulu öğelerde kızıl halka ancak böyle ayırt edilir.
                // Yerleşimi etkilemez.
                if (active)
                  Positioned.fill(
                    left: -RedoxElevation.focusRingOffset,
                    top: -RedoxElevation.focusRingOffset,
                    right: -RedoxElevation.focusRingOffset,
                    bottom: -RedoxElevation.focusRingOffset,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: widget.borderRadius.add(BorderRadius.circular(RedoxElevation.focusRingOffset)),
                          border: const Border.fromBorderSide(RedoxElevation.focusRing),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
