import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/m3e_motion.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import 'station_avatar.dart';

/// "Kadran" (eski uygulamada seçilen K2 tasarımı): yatay tuner. İbre ortada
/// sabittir, istasyonlar kayar; ortadaki istasyon büyük ve altın çerçevelidir,
/// uzaklaştıkça solar. Altta frekans çizgileri ve istasyon adları.
class RadioDial extends StatelessWidget {
  const RadioDial({super.key, required this.stations, required this.index, this.active = false, this.height = 200});

  final List<LiveChannel> stations;

  /// Ortadaki (ayarlı) istasyon.
  final int index;

  /// Kadran odakta: altın çerçeve.
  final bool active;
  final double height;

  /// Ortadan her yana gösterilen istasyon.
  static const _side = 2;

  /// İstasyon başına bundan dar kadranda (telefon) yan adlar sığmaz
  /// ("Metro ...", "Radyo Ş..."): yalnız ortadaki ad, kadran boyunca yazılır.
  static const labelStep = 96.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RedoxRoles.surfaceContainerHigh, RedoxRoles.surfaceContainerLowest],
        ),
        border: Border.all(color: active ? RedoxSeeds.gold : RedoxRoles.outlineVariant, width: active ? 3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final step = w / (2 * _side + 1);
          final big = height * 0.42;
          final small = height * 0.28;
          final tileTop = height * 0.14;
          final ticksTop = height * 0.66;
          final labels = step >= labelStep;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Frekans çizgileri: istasyon başına uzun altın, arada kısa.
              Positioned(
                left: 0,
                right: 0,
                top: ticksTop,
                height: height * 0.14,
                child: CustomPaint(painter: _Ticks(step: step)),
              ),
              if (stations.isNotEmpty)
                for (var d = -_side - 1; d <= _side + 1; d++)
                  _station(context, t, d, w, step, big, small, tileTop, labels),
              if (!labels && stations.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: height * 0.04,
                  child: Text(
                    stations[index % stations.length].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                  ),
                ),
              // İbre: ortada kızıl dikey çizgi ve üstte üçgen.
              Positioned(
                left: w / 2 - 1,
                top: 0,
                bottom: height * 0.18,
                width: 2,
                child: const IgnorePointer(child: ColoredBox(color: RedoxSeeds.crimson)),
              ),
              Positioned(
                left: w / 2 - 7,
                top: 0,
                width: 14,
                height: 9,
                child: const IgnorePointer(child: CustomPaint(painter: _Needle())),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _station(
    BuildContext context,
    TextTheme t,
    int d,
    double w,
    double step,
    double big,
    double small,
    double tileTop,
    bool label,
  ) {
    final n = stations.length;
    final i = ((index + d) % n + n) % n;
    final s = stations[i];
    final center = d == 0;
    final size = center ? big : small;
    final x = w / 2 + d * step;
    final fade = center ? 1.0 : (1 - d.abs() * 0.3).clamp(0.15, 1.0);
    return AnimatedPositioned(
      // Anahtar sanal konumdur (sarmadan önce): ◄ ► ile istasyonlar kayarak
      // yer değiştirir; kısa listede aynı istasyon iki yerde olabilir.
      key: ValueKey(index + d),
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasized,
      left: x - step / 2,
      width: step,
      top: 0,
      height: height,
      child: IgnorePointer(
        child: Opacity(
          opacity: fade,
          child: Column(
            children: [
              SizedBox(height: tileTop + (big - size) / 2),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(RedoxRadius.lg + 2),
                  border: center ? Border.all(color: RedoxSeeds.gold, width: 3) : null,
                  boxShadow: center ? const [BoxShadow(color: Color(0x66FBBE4D), blurRadius: 18)] : null,
                ),
                child: StationAvatar(station: s, size: size, radius: RedoxRadius.lg),
              ),
              const Spacer(),
              if (label)
                Padding(
                  padding: EdgeInsets.only(bottom: height * 0.04),
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (center ? t.titleMedium : t.bodyMedium)!.copyWith(
                      color: center ? RedoxRoles.onSurface : RedoxRoles.onSurfaceVariant,
                      fontWeight: center ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İbrenin ucu: aşağı bakan kızıl üçgen.
class _Needle extends CustomPainter {
  const _Needle();

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
  bool shouldRepaint(_Needle old) => false;
}

class _Ticks extends CustomPainter {
  _Ticks({required this.step});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = RedoxRoles.outlineVariant
      ..strokeWidth = 1.5;
    final major = Paint()
      ..color = RedoxSeeds.gold.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    final per = 5;
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
