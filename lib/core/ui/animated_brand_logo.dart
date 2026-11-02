import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../brand/brand_assets.dart';
import '../theme/m3e_motion.dart';

/// Girişteki büyük logo, canlı (kullanıcı isteği: "logoyu animasyonlu
/// yapabilir miyiz"). Logo tek parça görsel olduğundan parçaları değil
/// bütünü canlanır:
/// - **Giriş:** M3E uzamsal yayıyla büyüyerek belirir (hafif aşım).
/// - **Nefes:** arkasındaki kızıl-amber ışıma 4 sn'de bir yavaşça güçlenip
///   söner; logo 3 dp yükselip iner.
/// - **Kıvılcımlar:** alevlerden yukarı süzülen küçük közler.
///
/// Hareketi azalt açıksa (erişilebilirlik) yalnız durağan logo çizilir.
/// Tek denetleyici, tek boyama; Chromecast gibi zayıf kutuda da hafif.
class AnimatedBrandLogo extends StatefulWidget {
  const AnimatedBrandLogo({super.key, required this.height});

  final double height;

  /// Nefes ve kıvılcım döngüsü.
  static const period = Duration(seconds: 4);

  /// Kıvılcım sayısı.
  static const embers = 18;

  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo> with TickerProviderStateMixin {
  late final _intro = AnimationController.unbounded(vsync: this);
  late final _loop = AnimationController(vsync: this, duration: AnimatedBrandLogo.period);

  /// null: henüz başlamadı.
  bool? _still;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still == _still) return;
    _still = still;
    if (still) {
      _intro.value = 1;
      _loop.stop();
    } else {
      _intro
        ..value = 0
        ..animateWith(SpringSimulation(M3EMotion.spatialSlow, 0, 1, 0));
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      BrandAssets.logoTransparent,
      height: widget.height,
      semanticLabel: 'RedoX TV',
      filterQuality: FilterQuality.medium,
    );
    if (_still ?? true) return logo;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, child) {
          final intro = _intro.value;
          // 0→1→0 yumuşak nefes.
          final breath = (1 - math.cos(_loop.value * 2 * math.pi)) / 2;
          final shown = intro.clamp(0.0, 1.0);
          return CustomPaint(
            // Işıma logonun arkasında, kıvılcımlar önünde.
            painter: _GlowPainter(intro: shown, breath: breath, loop: _loop.value, embers: false),
            foregroundPainter: _GlowPainter(intro: shown, breath: breath, loop: _loop.value, embers: true),
            child: Opacity(
              opacity: shown,
              child: Transform.translate(
                offset: Offset(0, -3 * breath),
                child: Transform.scale(scale: 0.86 + 0.14 * intro, child: child),
              ),
            ),
          );
        },
        child: RepaintBoundary(child: logo),
      ),
    );
  }
}

/// Logonun arkasındaki ışıma ve önündeki kıvılcımlar.
class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.intro, required this.breath, required this.loop, required this.embers});

  /// true: kıvılcımlar (önde); false: ışıma (arkada).
  final bool embers;
  final double intro;
  final double breath;
  final double loop;

  static const _crimson = Color(0xFFD7232C);
  static const _amber = Color(0xFFFC7422);
  static const _gold = Color(0xFFFBBE4D);

  @override
  void paint(Canvas canvas, Size size) => embers ? _embers(canvas, size) : _glow(canvas, size);

  void _glow(Canvas canvas, Size size) {
    // Işıma: işaretin ortası (görselin üst %40'ı), nefesle güçlenir.
    final center = Offset(size.width / 2, size.height * 0.4);
    final radius = size.height * (0.42 + 0.06 * breath);
    final strength = intro * (0.55 + 0.45 * breath);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _crimson.withValues(alpha: 0.75 * strength),
            _amber.withValues(alpha: 0.35 * strength),
            _amber.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _embers(Canvas canvas, Size size) {
    // Kıvılcımlar: her biri kendi evresinde alevlerin üstünden yükselir,
    // hafif yalpalar ve söner. Yerleri sabit tohumdan (her açılışta aynı).
    final random = math.Random(7);
    // Yumuşak kenarlı köz; boyut logo yüksekliğine göre.
    final ember = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * 0.004);
    for (var i = 0; i < AnimatedBrandLogo.embers; i++) {
      final x0 = size.width * (0.18 + 0.64 * random.nextDouble());
      final phase = random.nextDouble();
      final speed = 0.6 + 0.8 * random.nextDouble();
      final r = size.height * (0.006 + 0.008 * random.nextDouble());
      final t = (loop * speed + phase) % 1;
      final y = size.height * (0.55 - 0.62 * t);
      final x = x0 + math.sin((t + phase) * 2 * math.pi) * size.width * 0.03;
      // Doğarken belirir, yükseldikçe söner.
      final alpha = intro * math.sin(t * math.pi) * 0.9;
      ember.color = Color.lerp(_gold, _amber, t)!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r * (1 - 0.5 * t), ember);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.intro != intro || old.breath != breath || old.loop != loop;
}
