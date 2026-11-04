import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/icon_action_button.dart';
import '../../../core/ui/long_press_select.dart';
import '../../../core/ui/redox_icon.dart';
import '../../radio/widgets/station_avatar.dart';

/// Favoriler'de kanal ya da istasyon satırı: sıra, büyük karo, ad, şu anki
/// program (TV) ya da tür (radyo), sağda çıkar. Yukarı/aşağı düğmeleri yalnız
/// taşırken görünür; dokunmatikte taşıma soldaki tutamaçla yapılır.
class FavoriteRow extends StatelessWidget {
  const FavoriteRow({
    super.key,
    required this.channel,
    required this.position,
    required this.radio,
    required this.compact,
    required this.onPressed,
    required this.onRemove,
    this.onUp,
    this.onDown,
    this.onLongPress,
    this.moving = false,
    this.autofocus = false,
    this.handle,
  });

  static const height = 72.0;

  /// Sürükle-bırak tutamacı (dokunmatik, "Sıram"); yoksa null.
  final Widget? handle;

  final LiveChannel channel;
  final int position;
  final bool radio;
  final bool compact;
  final bool autofocus;
  final VoidCallback onPressed;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback onRemove;

  /// Uzun OK/dokunma: taşıma kipini aç/kapat.
  final VoidCallback? onLongPress;

  /// Taşınıyor: altın kenarlık, ▲▼ yönergesi.
  final bool moving;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    final touch = Theme.of(context).extension<RedoxMetrics>()!.formFactor != FormFactor.tv;
    final subtitle = moving
        ? (touch ? 'Yukarı/aşağı ile taşıyın, bitirmek için dokunun' : 'Yukarı/aşağı ile taşıyın, OK ile bitirin')
        : radio
        ? c.category
        : (c.programTitle ?? c.category);
    return Container(
      decoration: BoxDecoration(
        color: moving ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        border: moving
            ? Border.all(color: RedoxSeeds.gold, width: 2)
            : Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FocusGlow(
              borderRadius: radius,
              scale: 1,
              // Taşırken iç odak halkası yok: altın çerçeve bütün satırı gösterir.
              focused: moving ? false : null,
              builder: (context, active) => Material(
                color: active ? RedoxRoles.surfaceContainerHighest : Colors.transparent,
                borderRadius: radius,
                child: LongPressSelect(
                  onPressed: onPressed,
                  onLongPress: onLongPress,
                  // Taşıma kipi: sıralama simgesi.
                  icon: RedoxIcons.menu,
                  child: InkWell(
                    onTap: onPressed,
                    onLongPress: onLongPress,
                    autofocus: autofocus,
                    borderRadius: radius,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          ?handle,
                          if (!compact) ...[
                            SizedBox(
                              width: 28,
                              child: Text(
                                '$position',
                                textAlign: TextAlign.center,
                                style: t.titleSmall!.copyWith(
                                  color: RedoxRoles.tertiary,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: RedoxType.tabular,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          StationAvatar(station: c, size: 52, radius: RedoxRadius.md),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.titleMedium!.copyWith(
                                    color: RedoxRoles.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (moving && handle == null) ...[
            _Action(icon: RedoxIcons.expandLess, label: 'Yukarı taşı', onPressed: onUp),
            const SizedBox(width: 6),
            _Action(icon: RedoxIcons.expandMore, label: 'Aşağı taşı', onPressed: onDown),
            const SizedBox(width: 6),
          ],
          _Action(icon: RedoxIcons.close, label: 'Favorilerden çıkar', onPressed: onRemove),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Satır sonundaki düğme; devre dışıysa soluk ve odak almaz.
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onPressed});

  final RedoxIcons icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Opacity(
      opacity: onPressed == null ? 0.3 : 1,
      child: ExcludeFocus(
        excluding: onPressed == null,
        child: IconActionButton(icon: icon, onPressed: onPressed),
      ),
    ),
  );
}
