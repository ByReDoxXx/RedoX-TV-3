import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import '../theme/redox_elevation.dart';
import '../theme/redox_shapes.dart';
import '../theme/redox_spacing.dart';
import 'focus_glow.dart';
import 'key_hint.dart';
import 'redox_icon.dart';

final _pill = BorderRadius.circular(RedoxRadius.full);

/// Birincil "Combustive" düğme: kızıl hap; odakta 1.06 büyür ve alev aurası alır.
/// Renk ve şekil temadaki FilledButton stilinden gelir.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.keyHint,
    this.focused,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RedoxIcons? icon;

  /// Örn. "OK": düğmenin kumandada hangi tuşla tetiklendiği.
  final String? keyHint;
  final bool? focused;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    const fg = RedoxRoles.onPrimaryContainer;
    return FocusGlow(
      borderRadius: _pill,
      scale: RedoxElevation.focusScalePrimaryButton,
      focused: focused,
      builder: (context, _) => FilledButton(
        onPressed: onPressed,
        autofocus: autofocus,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              RedoxIcon(icon!, filled: true, color: fg, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label),
            if (keyHint != null) ...[
              const SizedBox(width: 10),
              KeyHint(keyHint!, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

/// İkincil "Glass" düğme: yarı saydam hap; odakta amber zemin, koyu yazı.
/// Renkler temadaki OutlinedButton stilinden gelir.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.focused,
    this.iconOnly = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final RedoxIcons? icon;

  /// null: gerçek odak/fare durumu. true/false: dışarıdan sabit.
  final bool? focused;

  /// Dar ekran: 40 dp yuvarlak, yalnız ikon; ad ipucu ve ekran okuyucu
  /// etiketi olur. [icon] gerekir.
  final bool iconOnly;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _applyForced();
  }

  @override
  void didUpdateWidget(GlassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyForced();
  }

  void _applyForced() {
    final forced = widget.focused;
    if (forced != null) _states.update(WidgetState.focused, forced);
  }

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.iconOnly) {
      return FocusGlow(
        borderRadius: _pill,
        focused: widget.focused,
        builder: (context, active) => Tooltip(
          message: widget.label,
          child: OutlinedButton(
            onPressed: widget.onPressed,
            statesController: _states,
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(RedoxButtonSize.height),
              fixedSize: const Size.square(RedoxButtonSize.height),
            ),
            // Ad ipucundan okunur; ikonun kendi adı ("Saat") karışmasın.
            child: ExcludeSemantics(
              child: RedoxIcon(widget.icon!, color: active ? RedoxSeeds.obsidian : RedoxRoles.secondary, size: 20),
            ),
          ),
        ),
      );
    }
    return FocusGlow(
      borderRadius: _pill,
      focused: widget.focused,
      builder: (context, active) => OutlinedButton(
        onPressed: widget.onPressed,
        statesController: _states,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              RedoxIcon(
                widget.icon!,
                color: active ? RedoxSeeds.obsidian : RedoxRoles.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Text(widget.label),
          ],
        ),
      ),
    );
  }
}
