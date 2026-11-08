import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/playback/engine/playback_engine.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/redox_icon.dart';

/// Masaüstü film ve dizi denetimleri (sinema düzeni): panel kutusu yok,
/// görüntünün üstünde koyu geçiş. Sol üstte geri, tür rozeti, başlık; altta
/// tam genişlik sarma çubuğu ve tek satır düğmeler. Dizide bölüm şeridi
/// ([episodes]) düğmelerin üstünde açılır.
class DesktopVodControls extends StatelessWidget {
  const DesktopVodControls({
    super.key,
    required this.series,
    required this.title,
    required this.subtitle,
    required this.clock,
    required this.playing,
    required this.audio,
    required this.speedLabel,
    required this.onBack,
    required this.onPlayPause,
    required this.onToggleMute,
    required this.onVolume,
    required this.onTracks,
    required this.onSpeed,
    required this.onOptions,
    this.seekBar,
    this.endTime,
    this.onSeekBy,
    this.onRestart,
    this.onEpisodes,
    this.episodesOpen = false,
    this.nextLabel,
    this.onNext,
    this.episodes,
  });

  static const double margin = 32;

  final bool series;
  final String title;
  final String subtitle;
  final String clock;
  final bool playing;
  final ValueListenable<AudioLevel> audio;

  /// "1x"; null ise hız seçilemez (canlı benzeri, sarılamayan yayın).
  final String? speedLabel;

  final Widget? seekBar;
  final Widget? endTime;

  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;
  final VoidCallback onTracks;
  final VoidCallback onSpeed;
  final VoidCallback onOptions;

  /// ±10 sn; null ise sarılamaz.
  final ValueChanged<int>? onSeekBy;
  final VoidCallback? onRestart;

  /// Dizi: bölüm şeridini açar/kapatır; null ise tek bölüm.
  final VoidCallback? onEpisodes;
  final bool episodesOpen;

  /// Dizi: sıradaki bölümün adı ("S2 · B6"); null ise son bölüm.
  final String? nextLabel;
  final VoidCallback? onNext;

  /// Açık bölüm şeridi.
  final Widget? episodes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(left: 0, right: 0, top: 0, height: 180, child: IgnorePointer(child: _Scrim(top: true))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: episodes == null ? 260 : 460,
          child: const IgnorePointer(child: _Scrim(top: false)),
        ),
        Positioned(
          left: margin,
          top: 24,
          right: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Round(icon: RedoxIcons.back, tooltip: 'Geri (Esc)', onPressed: onBack),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KindBadge(series: series),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w800),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: margin,
          top: 24,
          child: _ClockPill(clock: clock),
        ),
        Positioned(
          left: margin,
          right: margin,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (episodes case final strip?) ...[strip, const SizedBox(height: 16)],
              if (seekBar != null)
                Row(
                  children: [
                    Expanded(child: seekBar!),
                    if (endTime case final end?) ...[const SizedBox(width: 16), end],
                  ],
                ),
              const SizedBox(height: 10),
              _buttons(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buttons(BuildContext context) {
    return Row(
      children: [
        if (onSeekBy case final seek?) ...[
          _Round(icon: RedoxIcons.replay10, tooltip: '10 sn geri (←)', onPressed: () => seek(-1)),
          const SizedBox(width: 10),
        ],
        _PlayButton(playing: playing, onPressed: onPlayPause),
        if (onSeekBy case final seek?) ...[
          const SizedBox(width: 10),
          _Round(icon: RedoxIcons.forward10, tooltip: '10 sn ileri (→)', onPressed: () => seek(1)),
        ],
        const SizedBox(width: 12),
        _Volume(audio: audio, onToggleMute: onToggleMute, onVolume: onVolume),
        const Spacer(),
        if (onEpisodes case final open?) ...[
          _Pill(icon: RedoxIcons.series, label: 'Bölümler', selected: episodesOpen, onPressed: open),
          const SizedBox(width: 8),
        ],
        if (nextLabel != null && onNext != null) ...[
          _Pill(icon: RedoxIcons.next, label: 'Sonraki bölüm', tooltip: nextLabel, onPressed: onNext!),
          const SizedBox(width: 8),
        ],
        _Pill(icon: RedoxIcons.subtitles, label: 'Ses ve altyazı', tooltip: 'Ses ve altyazı (A)', onPressed: onTracks),
        if (speedLabel case final speed?) ...[
          const SizedBox(width: 8),
          _Pill(icon: RedoxIcons.tune, label: 'Hız $speed', onPressed: onSpeed),
        ],
        if (onRestart case final restart?) ...[
          const SizedBox(width: 8),
          _Pill(icon: RedoxIcons.history, label: 'Baştan başla', onPressed: restart),
        ],
        const SizedBox(width: 8),
        _Round(icon: RedoxIcons.moreHorizontal, tooltip: 'Seçenekler', onPressed: onOptions),
      ],
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
            Colors.black.withValues(alpha: top ? 0.75 : 0.9),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.series});

  final bool series;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: series ? RedoxSeeds.amber : RedoxSeeds.gold,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Text(
        series ? 'DİZİ' : 'FİLM',
        style: t.labelSmall!.copyWith(color: RedoxSeeds.obsidian, fontWeight: FontWeight.w800, letterSpacing: 1.5),
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
        mainAxisSize: MainAxisSize.min,
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

class _Volume extends StatelessWidget {
  const _Volume({required this.audio, required this.onToggleMute, required this.onVolume});

  final ValueListenable<AudioLevel> audio;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolume;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioLevel>(
      valueListenable: audio,
      builder: (context, a, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Round(
            icon: a.silent ? RedoxIcons.volumeOff : RedoxIcons.volume,
            tooltip: a.muted ? 'Sesi aç (M)' : 'Sesi kapat (M)',
            onPressed: onToggleMute,
            plain: true,
          ),
          SizedBox(
            width: 110,
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
            fixedSize: const Size.square(56),
          ),
          icon: RedoxIcon(
            playing ? RedoxIcons.pause : RedoxIcons.play,
            filled: true,
            size: 28,
            color: RedoxRoles.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.tooltip, required this.onPressed, this.plain = false});

  final RedoxIcons icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Zeminsiz (ses düğmesi).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: plain ? null : Colors.white.withValues(alpha: 0.08),
        hoverColor: Colors.white.withValues(alpha: 0.14),
      ),
      icon: RedoxIcon(icon, color: RedoxRoles.onSurface),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onPressed, this.selected = false, this.tooltip});

  final RedoxIcons icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = selected ? RedoxSeeds.obsidian : RedoxRoles.onSurface;
    final button = Material(
      color: selected ? RedoxSeeds.amber : Colors.white.withValues(alpha: 0.08),
      shape: StadiumBorder(side: BorderSide(color: selected ? RedoxSeeds.amber : Colors.white.withValues(alpha: 0.12))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: Colors.white.withValues(alpha: 0.08),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RedoxIcon(icon, size: 20, filled: selected, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: t.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: tooltip == null ? button : Tooltip(message: tooltip!, child: button),
    );
  }
}
