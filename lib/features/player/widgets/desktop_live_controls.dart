import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/playback/engine/playback_engine.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/redox_icon.dart';

/// Masaüstü canlı yayın denetimleri: görüntünün altında yüzen 72 dp'lik tek
/// satır çubuk (üst kenarında programın ilerlemesi), sağ üstte saat ve
/// kapat. Düğmeler ikondur; adları ve kısayolları ipucunda yazar.
class DesktopLiveControls extends StatelessWidget {
  const DesktopLiveControls({
    super.key,
    required this.channel,
    required this.playing,
    required this.clock,
    required this.audio,
    required this.streamIndex,
    required this.streamCount,
    required this.channelListOpen,
    required this.onClose,
    required this.onPlayPause,
    required this.onPreviousChannel,
    required this.onNextChannel,
    required this.onTracks,
    required this.onToggleMute,
    required this.onVolume,
    required this.onChannelList,
    required this.onOptions,
    this.resolution,
    this.onNextStream,
    this.lastChannelName,
    this.onLastChannel,
  });

  /// Çubuğun yüksekliği ve kenar boşluğu (kanal listesi çubuğun üstünde biter).
  static const double barHeight = 72;
  static const double margin = 24;

  final LiveChannel channel;
  final bool playing;
  final String clock;
  final ValueListenable<AudioLevel> audio;
  final int streamIndex;
  final int streamCount;
  final bool channelListOpen;
  final String? resolution;
  final String? lastChannelName;

  final VoidCallback onClose;
  final VoidCallback onPlayPause;
  final VoidCallback onPreviousChannel;
  final VoidCallback onNextChannel;
  final VoidCallback onTracks;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final VoidCallback onChannelList;
  final VoidCallback onOptions;

  /// null ise kanalın tek akışı var.
  final VoidCallback? onNextStream;

  /// null ise önceki kanal yok.
  final VoidCallback? onLastChannel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Yazıların okunması için üstte ve altta koyu geçiş.
        const Positioned(left: 0, right: 0, top: 0, height: 120, child: IgnorePointer(child: _Scrim(top: true))),
        const Positioned(left: 0, right: 0, bottom: 0, height: 160, child: IgnorePointer(child: _Scrim(top: false))),
        Positioned(
          right: margin,
          top: 20,
          child: Row(
            children: [
              _ClockPill(clock: clock),
              const SizedBox(width: 8),
              _IconButton(
                icon: RedoxIcons.close,
                tooltip: 'Kapat (Esc)',
                onPressed: onClose,
                background: RedoxRoles.surfaceContainer.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
        Positioned(left: margin, right: margin, bottom: margin, child: _bar(context)),
      ],
    );
  }

  Widget _bar(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final progress = (channel.progress ?? 0).clamp(0.0, 1.0);
    final program = channel.programTitle;
    final meta = [?resolution, if (streamCount > 1) 'Akış ${streamIndex + 1}/$streamCount'].join(' · ');
    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Programın ilerlemesi: çubuğun üst kenarında ince ısıl çizgi.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 3,
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [RedoxSeeds.crimson, RedoxSeeds.amber])),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(RedoxRadius.md),
                  child: SizedBox.square(
                    dimension: 44,
                    child: ChannelLogo(name: channel.name, logoUrl: channel.logoUrl, size: 0.8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            channel.number.toString().padLeft(3, '0'),
                            style: t.labelMedium!.copyWith(
                              color: RedoxRoles.tertiary,
                              fontWeight: FontWeight.w700,
                              fontFeatures: RedoxType.tabular,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const _LiveBadge(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: program ?? 'Yayın akışı bilgisi yok',
                              style: const TextStyle(color: RedoxRoles.onSurface, fontWeight: FontWeight.w600),
                            ),
                            if (channel.timeRange case final range?) TextSpan(text: ' · $range'),
                            if (meta.isNotEmpty) TextSpan(text: ' · $meta'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall!.copyWith(
                          color: RedoxRoles.onSurfaceVariant,
                          fontFeatures: RedoxType.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _IconButton(icon: RedoxIcons.previous, tooltip: 'Önceki kanal (↓)', onPressed: onPreviousChannel),
                const SizedBox(width: 8),
                _PlayButton(playing: playing, onPressed: onPlayPause),
                const SizedBox(width: 8),
                _IconButton(icon: RedoxIcons.next, tooltip: 'Sonraki kanal (↑)', onPressed: onNextChannel),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: channel.next == null
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SONRA',
                              style: t.labelSmall!.copyWith(
                                color: RedoxRoles.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              channel.next!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _IconButton(icon: RedoxIcons.subtitles, tooltip: 'Ses ve altyazı (A)', onPressed: onTracks),
                if (onNextStream case final next?)
                  _IconButton(
                    icon: RedoxIcons.sync,
                    tooltip: 'Akış ${streamIndex + 1}/$streamCount · sonrakine geç (→)',
                    onPressed: next,
                  ),
                if (onLastChannel case final last?)
                  _IconButton(
                    icon: RedoxIcons.history,
                    tooltip: lastChannelName == null ? 'Son kanal (0)' : 'Son kanal: $lastChannelName (0)',
                    onPressed: last,
                  ),
                ValueListenableBuilder<AudioLevel>(
                  valueListenable: audio,
                  builder: (context, a, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconButton(
                        icon: a.silent ? RedoxIcons.volumeOff : RedoxIcons.volume,
                        tooltip: a.muted ? 'Sesi aç (M)' : 'Sesi kapat (M)',
                        onPressed: onToggleMute,
                      ),
                      SizedBox(
                        width: 96,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: RedoxSeeds.amber,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                            thumbColor: RedoxRoles.onSurface,
                            overlayColor: RedoxSeeds.amber.withValues(alpha: 0.16),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: a.muted ? 0 : a.level,
                            semanticFormatterCallback: (v) => 'Ses düzeyi %${(v * 100).round()}',
                            onChanged: onVolume,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _IconButton(
                  icon: RedoxIcons.epg,
                  tooltip: 'Kanal listesi (L)',
                  onPressed: onChannelList,
                  selected: channelListOpen,
                ),
                _IconButton(icon: RedoxIcons.moreHorizontal, tooltip: 'Seçenekler', onPressed: onOptions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: top ? 0.6 : 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: RedoxSeeds.crimson, borderRadius: BorderRadius.circular(RedoxRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: RedoxRoles.onPrimaryContainer, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            'CANLI',
            style: t.labelSmall!.copyWith(
              color: RedoxRoles.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockPill extends StatelessWidget {
  const _ClockPill({required this.clock});

  final String clock;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Row(
        children: [
          const RedoxIcon(RedoxIcons.clock, size: 18, color: RedoxRoles.tertiary),
          const SizedBox(width: 8),
          Text(
            clock,
            style: t.titleSmall!.copyWith(
              color: RedoxRoles.onSurface,
              fontWeight: FontWeight.w700,
              fontFeatures: RedoxType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? 'Duraklat (Boşluk)' : 'Oynat (Boşluk)',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: RedoxSeeds.crimson.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 6)),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: RedoxSeeds.crimson,
            hoverColor: RedoxRoles.onPrimaryContainer.withValues(alpha: 0.08),
            fixedSize: const Size.square(48),
          ),
          icon: RedoxIcon(
            playing ? RedoxIcons.pause : RedoxIcons.play,
            filled: true,
            color: RedoxRoles.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.background,
  });

  final RedoxIcons icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      isSelected: selected,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        backgroundColor: selected ? RedoxSeeds.amber : background,
        hoverColor: Colors.white.withValues(alpha: 0.10),
      ),
      icon: RedoxIcon(icon, filled: selected, color: selected ? RedoxSeeds.obsidian : RedoxRoles.onSurface),
    );
  }
}
