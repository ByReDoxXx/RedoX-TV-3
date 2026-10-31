import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/redox_buttons.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';

/// Televizyon sayfasının sağ paneli (TV/tablet): OK'e basılan kanalın logosu,
/// şimdiki ve sonraki program, tam ekran düğmesi (aynı kanalda ikinci OK de
/// tam ekrana geçer). Kullanıcının
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
                    ChannelLogo(name: c.name, logoUrl: c.logoUrl, alignment: Alignment.center),
                    if (c.live) const Positioned(top: 8, left: 8, child: StatusBadge(label: 'CANLI', pulse: true)),
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
                    child: PrimaryButton(
                      label: 'Tam ekran',
                      icon: RedoxIcons.fullscreen,
                      keyHint: 'OK',
                      onPressed: onWatch,
                    ),
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

/// Önizleme paneli boşken: ne yapılacağını söyleyen yer tutucu.
class ChannelPreviewHint extends StatelessWidget {
  const ChannelPreviewHint({super.key, required this.touch});

  /// Dokunmatik/fare: "dokunun"; D-pad: "OK'e basın".
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final action = touch ? 'dokunun' : "OK'e basın";
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        border: Border.all(color: RedoxRoles.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RedoxIcon(RedoxIcons.television, color: RedoxRoles.onSurfaceVariant, size: 40),
            const SizedBox(height: 12),
            Text(
              'Önizlemek için bir kanala $action',
              textAlign: TextAlign.center,
              style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'Aynı kanalda tekrar ${touch ? 'dokunmak' : 'OK'} tam ekran açar.',
              textAlign: TextAlign.center,
              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
