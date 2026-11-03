import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
import 'focus_glow.dart';
import 'redox_icon.dart';

/// Dairesel ikon düğmesi: 48 dp (dokunma/işaretçi), TV'de 40 dp.
/// Zemin cam düğmeyle aynıdır; odakta amber.
class IconActionButton extends StatelessWidget {
  const IconActionButton({super.key, required this.icon, required this.onPressed, this.focused, this.focusNode});

  final RedoxIcons icon;
  final VoidCallback? onPressed;
  final bool? focused;

  /// Odağı dışarıdan taşımak için (örn. radyo kadranında ▲ Seçenekler).
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final size = Theme.of(context).extension<RedoxMetrics>()!.iconButtonSize;
    return FocusGlow(
      borderRadius: BorderRadius.circular(size / 2),
      focused: focused,
      builder: (context, active) => Material(
        color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
        shape: CircleBorder(side: active ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder)),
        child: InkWell(
          onTap: onPressed,
          focusNode: focusNode,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox.square(
            dimension: size,
            child: Center(child: RedoxIcon(icon, color: active ? RedoxSeeds.obsidian : RedoxRoles.onSurface)),
          ),
        ),
      ),
    );
  }
}
