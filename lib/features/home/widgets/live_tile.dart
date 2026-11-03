import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_card.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_progress_bar.dart';

/// Anasayfanın "Şu an yayında" şeridindeki ince kanal kartı (B tasarımı):
/// solda küçük yayın karesi (yoksa logo), sağda kanal, program ve
/// yayın ilerlemesi (numara yok: TV'de 16 dp yazıyla ad kesiliyordu). Kanal kartından alçak: 540 dp tuvalde panonun altına sığar.
class LiveTile extends StatelessWidget {
  const LiveTile({
    super.key,
    required this.channelName,
    required this.programTitle,
    required this.progress,
    required this.artwork,
    this.accent = CardAccent.crimson,
    this.width = 220,
    this.onPressed,
  });

  final String channelName;
  final String programTitle;
  final double progress;
  final Widget artwork;
  final CardAccent accent;
  final double width;
  final VoidCallback? onPressed;

  /// Küçük karenin genişliği (16:9).
  static const thumbWidth = 88.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return SizedBox(
      width: width,
      child: FocusGlow(
        borderRadius: radius,
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
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RedoxRadius.sm),
                    child: SizedBox(width: thumbWidth, height: thumbWidth * 9 / 16, child: artwork),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelMedium!.copyWith(
                            color: accent.text,
                            fontWeight: FontWeight.w700,
                            fontFeatures: RedoxType.tabular,
                          ),
                        ),
                        Text(
                          programTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        RedoxProgressBar(value: progress, color: accent.fill, height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
