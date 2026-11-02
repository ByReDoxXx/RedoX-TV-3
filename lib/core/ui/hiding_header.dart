import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/m3e_motion.dart';

/// Telefonda sayfa başlığı (kullanıcı isteği: "aşağıya kaydırınca gizlensin,
/// yukarıya çıkarken geri çıksın"): içerik aşağı kaydıkça başlık parmakla
/// birlikte yukarı kayıp gizlenir, yukarı kaydırılınca hemen geri iner;
/// parmak kalkınca yarıdan fazlası görünüyorsa tamamen açılır, değilse
/// kapanır. Liste başına dönünce hep açıktır.
///
/// İçerik başlığın [gap] kadar altından başlar; kaydırılmışken üst
/// kenarında [fade] boyunca solar (kullanıcı isteği: başlığın tam bittiği
/// yerden keskin kesilmesin).
class HidingHeader extends StatefulWidget {
  const HidingHeader({super.key, required this.header, required this.child, this.gap = 12, this.fade = 24});

  final Widget header;

  /// Kayan içerik (içinde dikey kaydırılabilir bir alan).
  final Widget child;

  /// Başlıkla içerik arası.
  final double gap;

  /// İçeriğin üst kenarındaki solma yüksekliği.
  final double fade;

  @override
  State<HidingHeader> createState() => _HidingHeaderState();
}

class _HidingHeaderState extends State<HidingHeader> with SingleTickerProviderStateMixin {
  final _headerKey = GlobalKey();

  /// Gizlenen pay (0: tam açık, 1: tam gizli).
  late final _hidden = AnimationController.unbounded(vsync: this);

  /// İçerik başından kaymış mı (üst kenar solması için).
  bool _scrolled = false;

  @override
  void dispose() {
    _hidden.dispose();
    super.dispose();
  }

  /// Başlık ve aradaki boşluğun yüksekliği.
  double get _extent {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    return (box?.hasSize ?? false) ? box!.size.height + widget.gap : 0;
  }

  void _snapTo(double target) {
    if (_hidden.value == target) return;
    // Yay hedefe toleransla yaklaşır: bitince tam hedefe oturtulur.
    _hidden
        .animateWith(SpringSimulation(M3EMotion.spatialFast, _hidden.value, target, 0))
        .whenComplete(() => _hidden.value = target);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    final extent = _extent;
    if (extent == 0) return false;
    switch (n) {
      case ScrollUpdateNotification(:final scrollDelta?):
        if (n.metrics.pixels <= 0) {
          _snapTo(0);
        } else if (n.metrics.maxScrollExtent > extent) {
          // Kısa içerikte gizlenmez: başlık kalkınca içerik sığar, kaydırma
          // geri gelir ve başlık titrer.
          _hidden.stop();
          _hidden.value = (_hidden.value + scrollDelta / extent).clamp(0.0, 1.0);
        }
      case ScrollEndNotification():
        _snapTo(n.metrics.pixels <= 0 || _hidden.value < 0.5 ? 0 : 1);
      default:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final content = _scrolled && widget.fade > 0
        ? ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0x00000000), Color(0xFF000000)],
              stops: [0, (widget.fade / bounds.height).clamp(0.0, 1.0)],
            ).createShader(bounds),
            child: widget.child,
          )
        : widget.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: AnimatedBuilder(
            animation: _hidden,
            builder: (context, child) =>
                Align(alignment: Alignment.bottomCenter, heightFactor: 1 - _hidden.value.clamp(0.0, 1.0), child: child),
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.gap),
              child: KeyedSubtree(key: _headerKey, child: widget.header),
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: content),
        ),
      ],
    );
  }
}
