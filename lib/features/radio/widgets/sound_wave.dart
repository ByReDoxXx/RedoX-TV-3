import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';

/// Süs ses dalgası: ısıl renkli (kızıl → amber → altın) dikey çubuklar.
/// Gerçek ses seviyesi değildir (yayından okunmaz); [active] iken salınır,
/// değilse alçak durur. Kendi katmanında çizilir (RepaintBoundary): salınım
/// sayfanın geri kalanını yeniden çizdirmez.
class SoundWave extends StatefulWidget {
  const SoundWave({super.key, required this.active, this.bars = 44, this.height = 40});

  final bool active;
  final int bars;
  final double height;

  @override
  State<SoundWave> createState() => _SoundWaveState();
}

class _SoundWaveState extends State<SoundWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SoundWave old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: CustomPaint(painter: _WavePainter(_c, widget.bars, widget.active), size: Size.infinite),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.bars, this.active) : super(repaint: t);

  final Animation<double> t;
  final int bars;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width / bars;
    final w = math.max(2.0, gap * 0.45);
    final phase = t.value * 2 * math.pi;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars; i++) {
      final x = gap * (i + 0.5);
      final f = i / (bars - 1);
      // Üç dalganın toplamı: düzensiz ama sürekli salınım.
      final v = active
          ? 0.25 +
                0.75 *
                    ((math.sin(phase * 3 + i * 0.55) + math.sin(phase * 5 + i * 0.23) + math.sin(phase * 2 + i * 1.1)) /
                                6 +
                            0.5)
                        .clamp(0.0, 1.0)
          : 0.12;
      final h = math.max(w, size.height * v);
      paint
        ..color = Color.lerp(
          Color.lerp(RedoxSeeds.crimson, RedoxSeeds.amber, (f * 2).clamp(0, 1))!,
          RedoxSeeds.gold,
          ((f - 0.5) * 2).clamp(0, 1),
        )!.withValues(alpha: active ? 0.9 : 0.4)
        ..strokeWidth = w;
      canvas.drawLine(Offset(x, size.height / 2 - h / 2 + w / 2), Offset(x, size.height / 2 + h / 2 - w / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.active != active || old.bars != bars;
}
