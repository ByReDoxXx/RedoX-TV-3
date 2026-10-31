import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import 'redox_icon.dart';

/// Yatay kayan satır (örn. kategori çipleri); kaydırılabilen uçta "<" / ">"
/// oku belirir, satırın kaydığı anlaşılsın. Ok, zemine karışan bir solmanın
/// üstündedir; dokunma/fare ile bir sayfa kaydırır. D-pad'de odak almaz:
/// kumandada satır odakla kayar; odaktaki öğe okun altında kalırsa satır
/// ok genişliği kadar daha kayar.
class ScrollHintRow extends StatefulWidget {
  const ScrollHintRow({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  State<ScrollHintRow> createState() => _ScrollHintRowState();
}

class _ScrollHintRowState extends State<ScrollHintRow> {
  final _controller = ScrollController();
  final _viewport = GlobalKey();
  bool _canBack = false;
  bool _canForward = false;

  static const _arrowWidth = 40.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    FocusManager.instance.addListener(_onFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final back = p.pixels > p.minScrollExtent + 1;
    final forward = p.pixels < p.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  /// Odak bu satırdaki bir öğeye geçince: varsayılan kaydırma öğeyi kenara
  /// yaslar (okun altına); kaydırma bittikten sonra ok payı kadar içeri al.
  void _onFocus() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null || !mounted || focused.findAncestorStateOfType<_ScrollHintRowState>() != this) return;
    // Odak kaydırması (ensureVisible) aynı karede atlar: bir kare sonra ölç.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focused.mounted || !_controller.hasClients) return;
      final item = focused.findRenderObject() as RenderBox?;
      final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
      if (item == null || viewport == null || !item.attached) return;
      final left = item.localToGlobal(Offset.zero, ancestor: viewport).dx;
      final right = left + item.size.width;
      final p = _controller.position;
      double? target;
      if (left < _arrowWidth && _canBack) target = p.pixels - (_arrowWidth - left);
      if (right > viewport.size.width - _arrowWidth && _canForward) {
        target = p.pixels + (right - viewport.size.width + _arrowWidth);
      }
      if (target == null) return;
      _controller.animateTo(
        target.clamp(p.minScrollExtent, p.maxScrollExtent),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _page(int direction) {
    final p = _controller.position;
    final target = (p.pixels + direction * p.viewportDimension * 0.8).clamp(p.minScrollExtent, p.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Widget _arrow({required bool forward, required bool visible}) {
    final edge = RedoxSeeds.obsidian;
    return Positioned(
      top: widget.padding.top,
      bottom: widget.padding.bottom,
      left: forward ? null : 0,
      right: forward ? 0 : null,
      width: _arrowWidth,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: GestureDetector(
            onTap: () => _page(forward ? 1 : -1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: forward ? Alignment.centerRight : Alignment.centerLeft,
                  end: forward ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [edge, edge.withValues(alpha: 0.85), edge.withValues(alpha: 0)],
                  stops: const [0, 0.6, 1],
                ),
              ),
              child: Align(
                alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
                child: RedoxIcon(
                  forward ? RedoxIcons.chevronRight : RedoxIcons.chevronLeft,
                  color: RedoxRoles.onSurface,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      // Boyut değişince (pencere, içerik) uçlar yeniden hesaplanır.
      onNotification: (_) {
        _sync();
        return false;
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            key: _viewport,
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            child: widget.child,
          ),
          _arrow(forward: false, visible: _canBack),
          _arrow(forward: true, visible: _canForward),
        ],
      ),
    );
  }
}
