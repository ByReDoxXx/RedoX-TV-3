import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/live_channel.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/ui/channel_logo.dart';
import '../../core/ui/status_badge.dart';

/// Tam ekran izleme. Oynatıcı (video motoru) henüz yazılmadı: şimdilik siyah
/// zeminde kanal kimliği ve şimdiki program durur. Geri (veya Esc) Televizyon
/// sayfasına döner.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key, required this.channel});

  final LiveChannel channel;

  static Route<void> route(LiveChannel channel) => MaterialPageRoute(builder: (_) => PlayerPage(channel: channel));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: RedoxSeeds.obsidian,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.square(
                    dimension: 120,
                    child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
                  ),
                ),
                const SizedBox(height: 16),
                if (c.live) ...[const StatusBadge(label: 'CANLI', pulse: true), const SizedBox(height: 8)],
                Text(
                  c.name,
                  style: t.titleMedium!.copyWith(color: c.accent.text, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(c.programTitle, style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
                const SizedBox(height: 4),
                Text(c.timeRange, style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
                const SizedBox(height: 24),
                Text('Oynatıcı henüz hazır değil.', style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
