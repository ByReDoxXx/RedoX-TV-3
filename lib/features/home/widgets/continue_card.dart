import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../home_content.dart';

/// "İzlemeye devam et" kartı: solda 16:9 görsel, sağda başlık, bölüm,
/// kalan süre ve amber ilerleme.
class ContinueCard extends StatelessWidget {
  const ContinueCard({super.key, required this.item, this.width = 364, this.onPressed, this.focused});

  final HomeContinueItem item;
  final double width;
  final VoidCallback? onPressed;
  final bool? focused;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return SizedBox(
      width: width,
      child: FocusGlow(
        borderRadius: radius,
        focused: focused,
        builder: (context, active) => Material(
          color: active ? RedoxRoles.surfaceContainerHigh : RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: active ? BorderSide.none : RedoxElevation.restingBorder,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ArtworkFallback(name: item.title, icon: item.icon),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.detail,
                          style: t.labelMedium!.copyWith(color: RedoxRoles.secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.title,
                          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.remaining,
                          style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        RedoxProgressBar(value: item.progress),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
