import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/m3e_motion.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import 'station_avatar.dart';

/// Kadran şeridi (radyo A tasarımı, eski düz kadranın yenisi): eski radyo
/// skalası gibi amber ışıklı cam, altın çerçeve. İbre ortada sabittir,
/// istasyonlar kayar; ortadaki büyük ve altın çerçeveli, uzaklaştıkça solar.
/// Logoların altında çentikler, adlar ve istasyon numarası ("040").
class RadioDial extends StatelessWidget {
  const RadioDial({super.key, required this.stations, required this.index, this.active = false, this.height = 200});

  final List<LiveChannel> stations;

  /// Ortadaki (ayarlı) istasyon.
  final int index;

  /// Kadran odakta: çerçeve kalın ve parlak.
  final bool active;
  final double height;

  /// Ortadan her yana gösterilen istasyon.
  static const _side = 2;

  /// İstasyon başına bundan dar kadranda (telefon) yan adlar sığmaz: yalnız
  /// ortadaki ad yazılır, yanlarda numara kalır.
  static const labelStep = 96.0;

  /// Kadran camı: koyu amberden obsidyene.
  static const _glass = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xF22B1A14), Color(0xF2140C10)],
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: M3EMotion.short4,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        gradient: _glass,
        border: Border.all(
          color: active ? RedoxSeeds.gold : RedoxSeeds.gold.withValues(alpha: 0.45),
          width: active ? 3 : 1.5,
        ),
        boxShadow: [BoxShadow(color: RedoxSeeds.amber.withValues(alpha: active ? 0.28 : 0.12), blurRadius: 36)],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          final step = w / (2 * _side + 1);
          final big = h * 0.38;
          final small = h * 0.27;
          final tileTop = h * 0.11;
          final ticksTop = h * 0.58;
          final ticksHeight = h * 0.13;
          final labels = step >= labelStep;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Arkadan ışık: skalanın altından amber parıltı ve camın üst yansıması.
              const Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _Backlight())),
              ),
              // Çentikler: istasyon başına uzun altın, arada kısa.
              Positioned(
                left: 0,
                right: 0,
                top: ticksTop,
                height: ticksHeight,
                child: CustomPaint(painter: _Ticks(step: step)),
              ),
              if (stations.isNotEmpty)
                for (var d = -_side - 1; d <= _side + 1; d++)
                  _station(t, d, w, h, step, big, small, tileTop, ticksTop + ticksHeight, labels),
              // İbre: logonun üstünde ve altında iki parça (logonun üstünden
              // geçmez), üstte üçgen; adın üstünde biter.
              Positioned(
                left: w / 2 - 1.5,
                top: 0,
                height: math.max(0, tileTop - 6),
                width: 3,
                child: const IgnorePointer(child: _NeedleLine()),
              ),
              Positioned(
                left: w / 2 - 1.5,
                top: tileTop + big + 7,
                height: math.max(0, ticksTop + ticksHeight - tileTop - big - 7),
                width: 3,
                child: const IgnorePointer(child: _NeedleLine()),
              ),
              Positioned(
                left: w / 2 - 8,
                top: 0,
                width: 16,
                height: 10,
                child: const IgnorePointer(child: CustomPaint(painter: _NeedleTip())),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _station(
    TextTheme t,
    int d,
    double w,
    double h,
    double step,
    double big,
    double small,
    double tileTop,
    double labelTop,
    bool labels,
  ) {
    final n = stations.length;
    final s = stations[((index + d) % n + n) % n];
    final center = d == 0;
    final size = center ? big : small;
    final fade = center ? 1.0 : (1 - d.abs() * 0.28).clamp(0.15, 1.0);
    final name = center || labels;
    return AnimatedPositioned(
      // Anahtar sanal konumdur (sarmadan önce): ◄ ► ile istasyonlar kayarak
      // yer değiştirir; kısa listede aynı istasyon iki yerde olabilir.
      key: ValueKey(index + d),
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasized,
      left: w / 2 + d * step - (center && !labels ? w : step) / 2,
      width: center && !labels ? w : step,
      top: 0,
      height: h,
      child: IgnorePointer(
        child: Opacity(
          opacity: fade,
          // Yığın: kısa kadranda ad ve numara alttan kesilir, taşma olmaz.
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                // Çerçeve (3 dp) logonun dışında; logo hizası değişmez.
                top: tileTop + (big - size) / 2 - (center ? 3 : 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(RedoxRadius.lg + 3),
                    border: center ? Border.all(color: RedoxSeeds.gold, width: 3) : null,
                    boxShadow: center ? const [BoxShadow(color: Color(0x80FBBE4D), blurRadius: 24)] : null,
                  ),
                  child: StationAvatar(station: s, size: size, radius: RedoxRadius.lg),
                ),
              ),
              Positioned(
                top: labelTop + h * 0.02,
                left: 8,
                right: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name ? s.name : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      // Ortadaki ad yanlardakinden büyük (bodySmall'un 1,15 katı).
                      style: t.bodySmall!.copyWith(
                        fontSize: (t.bodySmall!.fontSize ?? 14) * (center ? 1.15 : 1),
                        color: center ? RedoxRoles.onSurface : RedoxSeeds.gold.withValues(alpha: 0.7),
                        fontWeight: center ? FontWeight.w800 : FontWeight.w600,
                        height: 1.2,
                        shadows: center ? const [Shadow(color: RedoxSeeds.amber, blurRadius: 12)] : null,
                      ),
                    ),
                    Text(
                      s.number.toString().padLeft(3, '0'),
                      style: t.labelSmall!.copyWith(
                        color: RedoxSeeds.gold.withValues(alpha: center ? 1 : 0.5),
                        fontFeatures: RedoxType.tabular,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeedleLine extends StatelessWidget {
  const _NeedleLine();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: RedoxSeeds.crimson,
      boxShadow: [BoxShadow(color: Color(0xCCD7232C), blurRadius: 10)],
    ),
  );
}

/// İbrenin ucu: aşağı bakan kızıl üçgen.
class _NeedleTip extends CustomPainter {
  const _NeedleTip();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = RedoxSeeds.crimson,
    );
  }

  @override
  bool shouldRepaint(_NeedleTip old) => false;
}

/// Skalanın arka ışığı: alttan amber parıltı, üstte camın yansıması.
class _Backlight extends CustomPainter {
  const _Backlight();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 1.6),
          radius: 1.1,
          colors: [RedoxSeeds.gold.withValues(alpha: 0.3), RedoxSeeds.gold.withValues(alpha: 0)],
        ).createShader(rect),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0FFFFFFF), Color(0x00FFFFFF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35)),
    );
  }

  @override
  bool shouldRepaint(_Backlight old) => false;
}

class _Ticks extends CustomPainter {
  _Ticks({required this.step});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = RedoxSeeds.gold.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = RedoxSeeds.gold
      ..strokeWidth = 2;
    const per = 6;
    final dx = step / per;
    // Ortadaki istasyon çizgisi tam ortada.
    final start = (size.width / 2) % step;
    var k = 0;
    for (var x = start - step; x < size.width + step; x += dx, k++) {
      final isMajor = k % per == 0;
      final h = isMajor ? size.height : size.height * 0.45;
      canvas.drawLine(Offset(x, size.height - h), Offset(x, size.height), isMajor ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_Ticks old) => old.step != step;
}
