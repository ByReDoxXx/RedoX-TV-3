import 'package:flutter/material.dart';

import '../../../core/content/user_sources.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';

// Kaynaklar bölümü ve Ayarlar > Kaynak ekle sekmesinin ortak parçaları.

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(width: 4, height: 20, color: RedoxSeeds.crimson),
        const SizedBox(width: 10),
        Text(title, style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Eşit genişlikte kutular (satırlara sarılır).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  static const gap = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.source, required this.onPressed, this.autofocus = false});

  final UserSource source;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = source;
    final radius = BorderRadius.circular(RedoxRadius.lg);
    return FocusGlow(
      borderRadius: radius,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          autofocus: autofocus,
          borderRadius: radius,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: RedoxSeeds.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RedoxRadius.sm),
                  ),
                  child: const RedoxIcon(RedoxIcons.folder, color: RedoxSeeds.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${s.count} ${switch (s.kind) {
                          SourceKind.live => 'kanal',
                          SourceKind.film => 'film',
                          SourceKind.series => 'bölüm',
                        }} · ${s.kind == SourceKind.live ? '' : '${s.kind.label} · '}${s.origin.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
