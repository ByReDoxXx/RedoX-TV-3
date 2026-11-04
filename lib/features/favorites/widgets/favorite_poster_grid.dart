import 'package:flutter/material.dart';

import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/center_on_focus.dart';
import '../../../core/ui/long_press_select.dart';
import '../../../core/ui/media_card.dart';
import '../../../core/ui/redox_icon.dart';

/// Favori film ve dizilerin afiş ızgarası. OK/dokunma açar. Kumandada uzun OK
/// çıkarır. Tablet ve telefonda basılı tutup sürüklemek sırayı değiştirir
/// ([onReorder]; kullanıcı isteği), çıkarmak afişin köşesindeki düğmeyle.
class FavoritePosterGrid<T extends Object> extends StatelessWidget {
  const FavoritePosterGrid({
    super.key,
    required this.items,
    required this.padding,
    required this.phone,
    required this.keyOf,
    required this.titleOf,
    required this.artworkOf,
    required this.onOpen,
    required this.onRemove,
    this.badgeOf,
    this.onReorder,
    this.autofocusFirst = true,
  });

  final List<T> items;
  final EdgeInsets padding;
  final bool phone;
  final String Function(T) keyOf;
  final String Function(T) titleOf;
  final String? Function(T)? badgeOf;
  final Widget Function(T) artworkOf;
  final ValueChanged<T> onOpen;
  final ValueChanged<T> onRemove;

  /// Sürüklenen kayıt hedefin yerine geçer; null ise sürükleme yok (arama,
  /// A-Z, kumanda).
  final void Function(T moved, T target)? onReorder;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    final tv = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;
    return GridView.builder(
      // Üstte/altta odak payı: büyüyen (1.08) afiş ve halkası kesilmesin.
      padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, phone ? padding.bottom : 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: phone ? 130 : 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2 / 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final x = items[i];
        return KeyedSubtree(
          key: ValueKey(keyOf(x)),
          child: LayoutBuilder(builder: (context, box) => _cell(x, i, box.maxWidth, tv)),
        );
      },
    );
  }

  Widget _cell(T x, int i, double width, bool tv) {
    final reorder = tv ? null : onReorder;
    final card = Stack(
      children: [
        GestureDetector(
          onLongPress: reorder == null ? () => onRemove(x) : null,
          child: LongPressSelect(
            onPressed: () => onOpen(x),
            onLongPress: () => onRemove(x),
            icon: RedoxIcons.close,
            child: MediaCard(
              title: titleOf(x),
              badge: switch (badgeOf?.call(x)) {
                final text? => PosterBadge(text),
                null => null,
              },
              width: width,
              autofocus: autofocusFirst && i == 0,
              artwork: artworkOf(x),
              onPressed: () => onOpen(x),
            ),
          ),
        ),
        if (!tv) Positioned(top: 4, right: 4, child: _RemoveButton(onPressed: () => onRemove(x))),
      ],
    );
    if (reorder == null) return CenterOnFocus(child: card);
    return DragTarget<T>(
      onWillAcceptWithDetails: (d) => d.data != x,
      onAcceptWithDetails: (d) => reorder(d.data, x),
      builder: (context, hovering, _) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RedoxRadius.lg),
          border: hovering.isEmpty ? null : Border.all(color: RedoxSeeds.gold, width: 2),
        ),
        child: LongPressDraggable<T>(
          data: x,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: width,
              height: width * 3 / 2,
              child: Opacity(
                opacity: 0.9,
                child: ClipRRect(borderRadius: BorderRadius.circular(RedoxRadius.lg), child: artworkOf(x)),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: card),
          child: card,
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Favorilerden çıkar',
    excludeSemantics: true,
    child: Material(
      color: const Color(0xD90B0B20),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: RedoxIcon(RedoxIcons.close, size: 16, color: RedoxRoles.onSurface),
        ),
      ),
    ),
  );
}
