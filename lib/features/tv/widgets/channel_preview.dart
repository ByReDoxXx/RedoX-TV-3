import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/artwork_fallback.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';

/// Televizyon sayfasının sağ paneli (TV/tablet): odaktaki kanalın büyük
/// görseli, şimdiki ve sonraki program, izleme düğmeleri. Kullanıcının
/// Stitch referansından ("Canlı önizleme") esinlenildi; teknik bilgi
/// (bit hızı, tampon) oynatıcı yazılana kadar gösterilmez.
class ChannelPreview extends StatelessWidget {
  const ChannelPreview({super.key, required this.channel, this.onWatch});

  final LiveChannel channel;
  final VoidCallback? onWatch;

  /// 540 dp TV yüksekliğinde düğmeler dahil sığacak genişlik (16:9 görsel).
  static const width = 280.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
      ),
      child: SingleChildScrollView(
        // Panel kayarken odak halkası kesilmesin.
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ArtworkFallback(name: c.name, icon: RedoxIcons.television),
                    if (c.live)
                      const Positioned(top: 8, left: 8, child: StatusBadge(label: 'CANLI', pulse: true)),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(RedoxRadius.full),
                        ),
                        child: Text(
                          'Kanal ${c.number}',
                          style: t.labelSmall!.copyWith(
                            color: RedoxRoles.tertiary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: RedoxType.tabular,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              c.name,
              style: t.labelMedium!.copyWith(color: c.accent.text, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              c.programTitle,
              style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${c.timeRange} · ${c.genre}',
              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            RedoxProgressBar(value: c.progress, color: c.accent.fill),
            if (c.next != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sonraki: ${c.next}',
                style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: PrimaryButton(label: 'İzle', icon: RedoxIcons.play, keyHint: 'OK', onPressed: onWatch),
                  ),
                ),
                const SizedBox(width: 12),
                GlassButton(label: '2x2 Ekrana ekle', icon: RedoxIcons.splitScreen, iconOnly: true, onPressed: () {}),
                const SizedBox(width: 8),
                GlassButton(label: 'Yayın akışı', icon: RedoxIcons.clock, iconOnly: true, onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
