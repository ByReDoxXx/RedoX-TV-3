import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/m3e_motion.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import 'station_avatar.dart';

/// Kadran tekerleği (radyo C tasarımı): alttan yükselen büyük bir tekerlek;
/// istasyon logoları kenarının üstünde dizilir. Ayarlı istasyon tepede, büyük ve
/// altın çerçeveli; kızıl ibre üstünde. Yanlardakiler tekerleğe göre eğilir,
/// uzaklaştıkça küçülüp söner. ◄ ► ile tekerlek döner (logolar kayar).
class RadioWheel extends StatelessWidget {
  const RadioWheel({super.key, required this.stations, required this.index, this.active = false, this.height = 200});

  final List<LiveChannel> stations;

  /// Tepedeki (ayarlı) istasyon.
  final int index;

  /// Kadran odakta: tekerleğin kenarı altın.
  final bool active;
  final double height;

  /// Tepeden her yana çizilen istasyon (en uçtakiler kenardan çıkar).
  static const _side = 3;

  /// Logonun alt kenarıyla tekerlek kenarı arası.
  static const _lift = 6.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          // Dar ekranda (telefon) yanlardaki logolar da sığsın.
          final big = math.min(height * 0.5, w * 0.3).clamp(64.0, 140.0);
          final small = big * 0.62;
          // Geniş ekranda tekerlek büyük, yay düz; dar ekranda daha kavisli.
          final radius = math.max(w * 0.62, height * 1.5);
          // Logolar kenarın üstünde durur (çizgi logoların altından geçer).
          final center = Offset(w / 2, 18 + big + _lift + radius);
          // Komşu logolar arası yay uzunluğu: TV'de beş, telefonda üç logo sığar.
          final spacing = math.max(big * 1.15, w / (w < 600 ? 3.3 : 5.4));
          final angle = spacing / radius;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _Wheel(center: center, radius: radius, step: angle, ring: big * 0.95, active: active),
                ),
              ),
              if (stations.isNotEmpty)
                for (var d = -_side; d <= _side; d++) _station(d, center, radius, angle, big, small),
              // İbre: tepedeki logonun üstünde aşağı bakan kızıl üçgen.
              Positioned(
                left: w / 2 - 9,
                top: 0,
                width: 18,
                height: 12,
                child: const IgnorePointer(child: CustomPaint(painter: _Needle())),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _station(int d, Offset center, double radius, double angle, double big, double small) {
    final n = stations.length;
    final s = stations[((index + d) % n + n) % n];
    final top = d == 0;
    final theta = d * angle;
    final size = top ? big : small * (1 - (d.abs() - 1) * 0.12);
    final r = radius + size / 2 + _lift;
    final x = center.dx + r * math.sin(theta);
    final y = center.dy - r * math.cos(theta);
    return AnimatedPositioned(
      // Anahtar sanal konumdur (sarmadan önce): ◄ ► ile logolar yay boyunca
      // kayarak yer değiştirir; kısa listede aynı istasyon iki yerde olabilir.
      key: ValueKey(index + d),
      duration: M3EMotion.medium2,
      curve: M3EMotion.emphasized,
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedRotation(
          turns: theta / (2 * math.pi),
          duration: M3EMotion.medium2,
          curve: M3EMotion.emphasized,
          child: AnimatedOpacity(
            opacity: top ? 1 : (1 - d.abs() * 0.22).clamp(0.2, 1.0),
            duration: M3EMotion.medium2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(RedoxRadius.lg + 3),
                border: top ? Border.all(color: RedoxSeeds.gold, width: 3) : null,
                boxShadow: top ? const [BoxShadow(color: Color(0x73FBBE4D), blurRadius: 28)] : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(top ? 4 : 0),
                child: StationAvatar(station: s, size: size - (top ? 14 : 0), radius: RedoxRadius.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tekerlek: hafif kızıl dolgu, kenar çizgisi (odakta altın), kenarda
/// istasyon başına altın, arada kısa çentikler ve içte kesik altın halka.
class _Wheel extends CustomPainter {
  const _Wheel({
    required this.center,
    required this.radius,
    required this.step,
    required this.ring,
    required this.active,
  });

  final Offset center;
  final double radius;

  /// İki istasyon arası açı.
  final double step;

  /// Kesik halkanın kenardan içeri uzaklığı.
  final double ring;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00D7232C), Color(0x14D7232C), Color(0x29D7232C)],
          stops: [0.8, 0.95, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 1.5
        ..color = active ? RedoxSeeds.gold : RedoxRoles.outlineVariant,
    );
    // Görünen yayın açısı (ekran genişliği kadar).
    final span = math.asin((size.width / 2 / radius).clamp(0.0, 1.0)) + step;
    final minor = Paint()
      ..color = RedoxRoles.outlineVariant
      ..strokeWidth = 1.5;
    final major = Paint()
      ..color = RedoxSeeds.gold.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    const per = 5;
    for (var k = -(span / step * per).ceil(); k <= (span / step * per).ceil(); k++) {
      final a = k * step / per;
      final isMajor = k % per == 0;
      final len = isMajor ? 14.0 : 7.0;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(center + dir * (radius - 2), center + dir * (radius - 2 - len), isMajor ? major : minor);
    }
    // İç kesik halka.
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = RedoxSeeds.gold.withValues(alpha: 0.25);
    final r = radius - ring * 1.25;
    final dash = 6 / r;
    for (var a = -span; a < span; a += dash * 2.2) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -math.pi / 2 + a, dash, false, inner);
    }
  }

  @override
  bool shouldRepaint(_Wheel old) =>
      old.center != center || old.radius != radius || old.step != step || old.ring != ring || old.active != active;
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
