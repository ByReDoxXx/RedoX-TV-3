import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/content/song_history.dart';
import '../../../core/layout/form_factor.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_metrics.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import 'station_avatar.dart';

/// Son dinlenen şarkılar: şarkı adı, istasyon ve saat; OK/dokunma o
/// istasyonu açar ([onOpen]). Radyo listesindeki "Son şarkılar" çipi ve
/// kadrandaki "Son çalanlar" paneli.
class RecentSongList extends StatelessWidget {
  const RecentSongList({
    super.key,
    required this.songs,
    required this.stations,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
  });

  final List<SongEntry> songs;

  /// Bütün istasyonlar (şarkının istasyonu numarasıyla bulunur).
  final List<LiveChannel> stations;
  final ValueChanged<LiveChannel> onOpen;
  final EdgeInsets padding;
  final bool shrinkWrap;

  static String clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (songs.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          'Henüz şarkı yok. Radyo dinlerken yayının bildirdiği şarkı adları burada listelenir.',
          style: t.bodyLarge!.copyWith(color: RedoxRoles.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final e = songs[i];
        final station = stations.where((s) => s.number == e.stationNumber).firstOrNull;
        final radius = BorderRadius.circular(RedoxRadius.lg);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: FocusGlow(
            borderRadius: radius,
            scale: 1,
            builder: (context, active) => Material(
              color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainer,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                autofocus: i == 0,
                focusColor: Colors.transparent,
                onTap: station == null ? null : () => onOpen(station),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      if (station != null) StationAvatar(station: station, size: 44) else const SizedBox(width: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface),
                            ),
                            Text(
                              '${e.station} · ${clock(e.at)}',
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
          ),
        );
      },
    );
  }
}

/// Kadrandaki "Son çalanlar" paneli: TV/tablette sağda yan panel, telefonda
/// alt sayfa. Şarkıya basılırsa istasyonu döner (panel kapanır).
Future<LiveChannel?> showRecentSongs(
  BuildContext context, {
  required SongHistory songs,
  required List<LiveChannel> stations,
}) {
  final phone = Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.phone;
  Widget panel(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text('Son çalanlar', style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface)),
          ),
          Flexible(
            child: ValueListenableBuilder(
              valueListenable: songs,
              builder: (context, list, _) => RecentSongList(
                songs: list,
                stations: stations,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onOpen: (s) => Navigator.pop(context, s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  if (phone) {
    return showModalBottomSheet<LiveChannel>(
      context: context,
      showDragHandle: true,
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: SafeArea(child: panel(context)),
      ),
    );
  }
  return showGeneralDialog<LiveChannel>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: const Color(0x99000000),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: RedoxRoles.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(RedoxRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(width: 440, child: panel(context)),
        ),
      ),
    ),
  );
}
