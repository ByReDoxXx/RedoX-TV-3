import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_type.dart';
import 'focus_glow.dart';

/// Medya kartı (DESIGN.md "Media Cards"): 16:9 veya 2:3, rounded-lg, görselin
/// alt üçte birinde obsidyen rampa, başlık title-md. Odakta 1.08 büyür ve alt
/// bilgi satırı öne gelir.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.artwork,
    this.subtitle,
    this.aspectRatio = 2 / 3,
    this.width = 160,
    this.badge,
    this.onPressed,
    this.focused,
  });

  final String title;
  final String? subtitle;
  final Widget artwork;

  /// 2/3 (afiş) veya 16/9 (yatay).
  final double aspectRatio;
  final double width;
  final Widget? badge;
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
          color: RedoxRoles.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: active ? BorderSide.none : RedoxElevation.restingBorder,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  artwork,
                  // Alt üçte bir: rgba(13,14,17,0) → rgba(13,14,17,0.95).
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 1 / 3,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [RedoxAccent.rampStart, RedoxAccent.rampEnd],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (badge != null) Positioned(top: 8, left: 8, child: badge!),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (active && subtitle != null)
                          Text(
                            subtitle!,
                            style: t.bodySmall!.copyWith(
                              color: RedoxRoles.onSurfaceVariant,
                              fontFeatures: RedoxType.tabular,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }
}
