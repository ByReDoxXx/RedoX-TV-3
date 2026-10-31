import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';
import '../home_content.dart';

/// Son dinlenen radyo: yuvarlak istasyon görseli, ad ve tür.
class RadioTile extends StatelessWidget {
  const RadioTile({super.key, required this.radio, this.width = 158, this.onPressed, this.focused});

  final HomeRadio radio;
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
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 48,
                    child: ClipOval(child: ArtworkFallback(name: radio.name, icon: RedoxIcons.radio)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    radio.name,
                    style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    radio.genre,
                    style: t.bodySmall!.copyWith(color: RedoxRoles.tertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
