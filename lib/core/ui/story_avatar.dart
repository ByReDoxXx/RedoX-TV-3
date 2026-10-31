import 'package:flutter/material.dart';

import '../theme/redox_colors.dart';
import 'focus_glow.dart';

/// Hikâye halkası (Anasayfa: yeni kanallar ve özellikler). Görülmemiş: ısıl
/// süpürme degradesi (kızıl → amber → altın); görülmüş: dış çizgi rengi.
class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.label,
    required this.child,
    this.seen = false,
    this.diameter = 72,
    this.onPressed,
    this.focused,
  });

  final String label;
  final Widget child;
  final bool seen;
  final double diameter;
  final VoidCallback? onPressed;
  final bool? focused;

  static const _ring = 3.0;
  static const _gap = 3.0;

  /// Yuva = halka + bu pay; halkalar arası boşluk da budur. Kullanıcı isteğiyle
  /// 48 → 36 → 28'e indi. 20'de yan yana etiketler (~5 dp) birbirine
  /// değiyordu (emülatör). Etiketin iki yanında [labelInset] pay kalır:
  /// komşu etiketler arası en az 8 dp. Yuvaya sığmayan etiket ("Çoklu ekran",
  /// TV'de ~105 dp) kesilmez, iki satıra iner; daha uzunu "…" ile kısalır.
  static const slotExtra = 28.0;
  static const labelInset = 4.0;
  static const labelLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    return SizedBox(
      width: diameter + slotExtra,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusGlow(
            borderRadius: BorderRadius.circular(diameter / 2),
            focused: focused,
            builder: (context, _) => Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                customBorder: const CircleBorder(),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Container(
                  width: diameter,
                  height: diameter,
                  padding: const EdgeInsets.all(_ring),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: seen ? RedoxRoles.outlineVariant : null,
                    gradient: seen
                        ? null
                        : const SweepGradient(colors: [...RedoxAccent.thermal, RedoxRoles.primaryContainer]),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(_gap),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: RedoxRoles.surfaceContainerLowest),
                    child: ClipOval(child: child),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: labelInset),
            child: Text(
              label,
              style: style.copyWith(color: RedoxRoles.onSurface),
              maxLines: labelLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
