import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';

/// Boş sekme: ikon, başlık, nasıl ekleneceği ve ilgili bölüme giden düğme.
class FavoritesEmpty extends StatelessWidget {
  const FavoritesEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    this.onAction,
  });

  final RedoxIcons icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: RedoxRoles.surfaceContainerHigh, shape: BoxShape.circle),
                child: RedoxIcon(icon, size: 34, color: RedoxRoles.tertiary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
              if (onAction != null) ...[const SizedBox(height: 18), GlassButton(label: action, onPressed: onAction)],
            ],
          ),
        ),
      ),
    );
  }
}
