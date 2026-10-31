import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_shapes.dart';

/// Rozet tonları. Yazı/zemin çiftleri >= 4,5:1 (redox_contrast_test.dart).
enum BadgeTone {
  /// Canlı yayın: kızıl zemin, beyaz yazı.
  live(RedoxRoles.primaryContainer, RedoxRoles.onPrimaryContainer),

  /// Puan, VIP, 4K: Incandescent Gold zemin, obsidyen yazı.
  gold(RedoxSeeds.gold, RedoxSeeds.obsidian),

  /// Öne çıkan bilgi: amber kabı.
  amber(RedoxRoles.secondaryContainer, RedoxRoles.onSecondaryContainer),

  /// Nötr bilgi (kayıt, teknik bilgi).
  neutral(RedoxRoles.surfaceContainerHighest, RedoxRoles.onSurface);

  const BadgeTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Küçük hap rozet; istenirse içinde nabız atan nokta (DESIGN.md "Status / Live
/// Badges"). Nabız: opaklık 1 → 0,5 → 1, 2 sn (zip'teki tasarımın animate-pulse
/// değeri). Sistem animasyonları kapalıysa nokta sabit kalır.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.live,
    this.pulse = false,
  });

  /// Büyük harfle verilir (Türkçe İ/I dönüşümü yazı anında yapılmaz).
  final String label;
  final BadgeTone tone;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse) ...[
            _PulseDot(color: tone.foreground),
            const SizedBox(width: 6),
          ],
          Text(label, style: style.copyWith(color: tone.foreground, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  // Tailwind animate-pulse eğrisi: cubic-bezier(0.4, 0, 0.6, 1).
  late final Animation<double> _opacity = Tween(begin: 1.0, end: 0.5)
      .chain(CurveTween(curve: const Cubic(0.4, 0, 0.6, 1)))
      .animate(_c);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
