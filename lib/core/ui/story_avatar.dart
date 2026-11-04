import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/form_factor.dart';
import '../theme/redox_colors.dart';
import '../theme/redox_metrics.dart';
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

  /// Telefonda etiketler 12 sp'dir (TV'de 16): halkalar arası 12 dp yeter
  /// (kullanıcı isteği). En uzun etiket iki satıra iner.
  static const slotExtraPhone = 12.0;
  static const minSlot = 76.0;
  static const labelInset = 4.0;
  static const labelLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final phone = Theme.of(context).extension<RedoxMetrics>()?.formFactor == FormFactor.phone;
    return SizedBox(
      // Küçük halkada (TV) da etiket kelime ortasından bölünmesin.
      width: math.max(diameter + (phone ? slotExtraPhone : slotExtra), minSlot),
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
            // Tek kelime bölünmez: dar yuvada küçülür ("Anasay-fa" olmasın).
            child: label.contains(' ')
                ? Text(
                    label,
                    style: style.copyWith(color: RedoxRoles.onSurface),
                    maxLines: labelLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: style.copyWith(color: RedoxRoles.onSurface), maxLines: 1),
                  ),
          ),
        ],
      ),
    );
  }
}
