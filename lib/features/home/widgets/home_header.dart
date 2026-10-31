import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/header_search.dart';
import '../../../core/ui/redox_icon.dart';

/// Üst şerit: logo, arama (TV'de kutu), saat ve profil. Logo rayda değil
/// burada durur: 540 dp TV yüksekliğinde ray öğelerine yer kalsın diye.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.clock, required this.profileName});

  final String clock;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SvgPicture.asset(
          'assets/brand/redox-logo.svg',
          width: 44,
          height: 44,
          semanticsLabel: 'RedoX TV',
        ),
        const SizedBox(width: 16),
        const SizedBox(width: 340, child: HeaderSearch()),
        const Spacer(),
        _Pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RedoxIcon(RedoxIcons.clock, color: RedoxRoles.tertiary, size: 20),
              const SizedBox(width: 8),
              Text(
                clock,
                style: t.titleMedium!.copyWith(
                  color: RedoxRoles.onSurface,
                  fontWeight: FontWeight.w700,
                  fontFeatures: RedoxType.tabular,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _Pill(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: RedoxRoles.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: RedoxIcon(RedoxIcons.profile, filled: true, color: RedoxRoles.onPrimaryContainer, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Text(profileName, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
        border: Border.all(color: RedoxRoles.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}
