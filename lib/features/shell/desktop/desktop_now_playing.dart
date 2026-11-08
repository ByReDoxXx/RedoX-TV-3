import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/playback/engine/playback_engine.dart';
import '../../../core/playback/playback_session.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import 'desktop_playback.dart';

/// Alttaki oynatma çubuğu (Spotify'daki gibi üç bölge): solda kanal ve
/// program, ortada önceki/oynat/sonraki ve programın ilerlemesi, sağda ses,
/// panel, tam ekran ve kapat.
class DesktopNowPlayingBar extends StatelessWidget {
  const DesktopNowPlayingBar({
    super.key,
    required this.playback,
    required this.panelOpen,
    required this.onTogglePanel,
    required this.onFullScreen,
  });

  static const double height = 88;

  final DesktopPlayback playback;
  final bool panelOpen;
  final VoidCallback onTogglePanel;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final session = playback.session!;
    final engine = playback.engine!;
    final channel = session.channel;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _NowChannel(channel: channel, status: session.status, onPressed: onFullScreen),
          ),
          SizedBox(
            width: 460,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BarButton(icon: RedoxIcons.previous, tooltip: 'Önceki kanal', onPressed: () => playback.zap(-1)),
                    const SizedBox(width: 16),
                    ValueListenableBuilder<EngineState>(
                      valueListenable: engine.state,
                      builder: (context, s, _) => _PlayButton(playing: s.playing, onPressed: playback.playOrPause),
                    ),
                    const SizedBox(width: 16),
                    _BarButton(icon: RedoxIcons.next, tooltip: 'Sonraki kanal', onPressed: () => playback.zap(1)),
                  ],
                ),
                const SizedBox(height: 6),
                _ProgramLine(channel: channel),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ValueListenableBuilder<AudioLevel>(
                  valueListenable: engine.audio,
                  builder: (context, a, _) => _BarButton(
                    icon: a.silent ? RedoxIcons.volumeOff : RedoxIcons.volume,
                    tooltip: a.muted ? 'Sesi aç' : 'Sesi kapat',
                    onPressed: playback.toggleMute,
                  ),
                ),
                _BarButton(
                  icon: panelOpen ? RedoxIcons.panelClose : RedoxIcons.panelOpen,
                  tooltip: panelOpen ? '"Şimdi oynatılan" panelini kapat' : '"Şimdi oynatılan" panelini aç',
                  selected: panelOpen,
                  onPressed: onTogglePanel,
                ),
                _BarButton(icon: RedoxIcons.fullscreen, tooltip: 'Tam ekran', onPressed: onFullScreen),
                _BarButton(icon: RedoxIcons.close, tooltip: 'Oynatmayı durdur', onPressed: playback.stop),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NowChannel extends StatelessWidget {
  const _NowChannel({required this.channel, required this.status, required this.onPressed});

  final LiveChannel channel;
  final PlaybackStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final subtitle = switch (status) {
      PlaybackStatus.loading => 'Açılıyor…',
      PlaybackStatus.failed => 'Yayın açılamadı',
      PlaybackStatus.playing => channel.programTitle ?? 'Kanal ${channel.number}',
    };
    return Row(
      children: [
        const SizedBox(width: 12),
        Tooltip(
          message: 'Tam ekran',
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(RedoxRadius.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.md),
              child: SizedBox.square(
                dimension: 56,
                child: ChannelLogo(name: channel.name, logoUrl: channel.logoUrl, size: 0.8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall!.copyWith(
                  color: status == PlaybackStatus.failed ? RedoxRoles.error : RedoxRoles.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Programın saat aralığı ve ilerlemesi (canlı yayında sarma yok).
class _ProgramLine extends StatelessWidget {
  const _ProgramLine({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final range = channel.timeRange?.split('–').map((s) => s.trim()).toList();
    final style = t.labelSmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular);
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(range?.first ?? 'CANLI', textAlign: TextAlign.right, style: style),
        ),
        const SizedBox(width: 10),
        Expanded(child: RedoxProgressBar(value: channel.progress ?? 1, height: 4)),
        const SizedBox(width: 10),
        SizedBox(width: 44, child: Text(range != null && range.length > 1 ? range[1] : '', style: style)),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: playing ? 'Duraklat' : 'Oynat',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: RedoxRoles.primaryContainer,
        hoverColor: RedoxRoles.onPrimaryContainer.withValues(alpha: 0.08),
        fixedSize: const Size.square(48),
      ),
      icon: RedoxIcon(playing ? RedoxIcons.pause : RedoxIcons.play, filled: true, color: RedoxRoles.onPrimaryContainer),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.tooltip, required this.onPressed, this.selected = false});

  final RedoxIcons icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: RedoxIcon(icon, filled: selected, color: selected ? RedoxRoles.secondary : RedoxRoles.onSurfaceVariant),
    );
  }
}

/// Sağdaki "Şimdi oynatılan" paneli: canlı görüntü (tıklayınca tam ekran),
/// kanal, şimdiki ve sonraki program, sıradaki kanallar.
class DesktopNowPlayingPanel extends StatelessWidget {
  const DesktopNowPlayingPanel({super.key, required this.playback, required this.onFullScreen, required this.onClose});

  static const double width = 340;

  final DesktopPlayback playback;
  final VoidCallback onFullScreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final session = playback.session!;
    final engine = playback.engine!;
    final channel = session.channel;
    final channels = session.channels;
    final upNext = [for (var i = 1; i <= 8 && i < channels.length; i++) (session.index + i) % channels.length];
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RedoxRadius.lg),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Şimdi oynatılan',
                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Paneli kapat',
                onPressed: onClose,
                icon: const RedoxIcon(RedoxIcons.close, color: RedoxRoles.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Video(engine: engine, status: session.status, onPressed: onFullScreen),
          const SizedBox(height: 16),
          Text(
            channel.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
          ),
          Text(
            'Kanal ${channel.number} · ${channel.category}',
            style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _ProgramCard(channel: channel),
          if (upNext.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Sıradaki kanallar',
              style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final i in upNext) _UpNext(channel: channels[i], onPressed: () => playback.openAt(i)),
          ],
        ],
      ),
    );
  }
}

class _Video extends StatefulWidget {
  const _Video({required this.engine, required this.status, required this.onPressed});

  final PlaybackEngine engine;
  final PlaybackStatus status;
  final VoidCallback onPressed;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          label: 'Tam ekran',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(RedoxRadius.lg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.engine.view(),
                    if (widget.status == PlaybackStatus.loading)
                      const Center(child: CircularProgressIndicator(color: RedoxRoles.primary)),
                    if (widget.status == PlaybackStatus.failed)
                      Center(
                        child: Text('Yayın açılamadı', style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface)),
                      ),
                    AnimatedOpacity(
                      opacity: _hover ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const ColoredBox(
                        color: Color(0x66000000),
                        child: Center(child: RedoxIcon(RedoxIcons.fullscreen, size: 40, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.channel});

  final LiveChannel channel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final label = t.labelMedium!.copyWith(color: RedoxRoles.secondary, fontWeight: FontWeight.w700);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: BorderRadius.circular(RedoxRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ŞİMDİ', style: label),
          const SizedBox(height: 4),
          Text(
            channel.programTitle ?? 'Yayın akışı bilgisi yok',
            style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface),
          ),
          if (channel.timeRange case final range?)
            Text(
              range,
              style: t.bodySmall!.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
            ),
          if (channel.progress case final p?) ...[const SizedBox(height: 8), RedoxProgressBar(value: p, height: 4)],
          if (channel.next case final next?) ...[
            const SizedBox(height: 14),
            Text('SONRA', style: label.copyWith(color: RedoxRoles.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(next, style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurface)),
          ],
        ],
      ),
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.channel, required this.onPressed});

  final LiveChannel channel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      hoverColor: RedoxRoles.onSurface.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.sm),
              child: SizedBox.square(
                dimension: 44,
                child: ChannelLogo(name: channel.name, logoUrl: channel.logoUrl, size: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.labelLarge!.copyWith(color: RedoxRoles.onSurface),
                  ),
                  Text(
                    channel.programTitle ?? 'Kanal ${channel.number}',
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
    );
  }
}
