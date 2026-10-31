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

  /// Yuva = halka + bu pay; halkalar arası boşluk da budur. 48'den 36'ya
  /// indirildi (kullanıcı isteği). En uzun etiket "Çoklu ekran" TV'de ~105 dp,
  /// 108 dp yuvaya kesilmeden sığar; daha uzunu "…" ile kısalır.
  static const slotExtra = 36.0;

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
                        : const SweepGradient(
                            colors: [...RedoxAccent.thermal, RedoxRoles.primaryContainer],
                          ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(_gap),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: RedoxRoles.surfaceContainerLowest,
                    ),
                    child: ClipOval(child: child),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: style.copyWith(color: RedoxRoles.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
