import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/key_hint.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/redox_progress_bar.dart';
import '../../../core/ui/status_badge.dart';

/// TV canlı yayın çubuğu: üstte kanal, şimdiki program, ilerleme ve sonraki
/// program; altta önceki kanal · oynat/duraklat (odak) · sonraki kanal, Kanallar,
/// Ses ve altyazı, son kanal, sonraki akış ve Seçenekler.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.channel,
    required this.playing,
    required this.resolution,
    required this.streamIndex,
    required this.streamCount,
    required this.playFocusNode,
    this.lastChannelName,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onChannelList,
    this.onNextStream,
    this.onOptions,
    this.onTracks,
    this.onLastChannel,
  });

  final LiveChannel channel;
  final bool playing;

  /// Ölçülen çözünürlük, örn. "720p"; bilinmiyorsa null.
  final String? resolution;
  final int streamIndex;
  final int streamCount;

  /// OK ile çubuk açılınca odak buraya gelir (oynat/duraklat).
  final FocusNode playFocusNode;

  /// Bir önceki izlenen kanal; yoksa düğme yok.
  final String? lastChannelName;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onChannelList;
  final VoidCallback? onNextStream;
  final VoidCallback? onOptions;
  final VoidCallback? onTracks;
  final VoidCallback? onLastChannel;

  @override
  Widget build(BuildContext context) {
    return _BarShell(
      children: [
        _Identity(channel: channel, resolution: resolution, streamIndex: streamIndex, streamCount: streamCount),
        const SizedBox(height: 12),
        _ControlRow(
          left: [
            _BarButton(icon: RedoxIcons.previous, label: 'Önceki kanal', onPressed: onPreviousChannel),
            _PlayButton(playing: playing, focusNode: playFocusNode, onPressed: onPlayPause),
            _BarButton(icon: RedoxIcons.next, label: 'Sonraki kanal', onPressed: onNextChannel),
          ],
          pills: [
            _BarPill(icon: RedoxIcons.television, label: 'Kanallar', onPressed: onChannelList),
            _BarPill(icon: RedoxIcons.subtitles, label: 'Ses ve altyazı', onPressed: onTracks),
            if (lastChannelName case final name?)
              _BarPill(icon: RedoxIcons.history, label: 'Son: $name', onPressed: onLastChannel),
            if (streamCount > 1)
              _BarPill(icon: RedoxIcons.sync, label: 'Akış ${streamIndex + 1}/$streamCount', onPressed: onNextStream),
          ],
          onOptions: onOptions,
        ),
      ],
    );
  }
}

/// TV film/dizi çubuğu: üstte tam genişlik sarma çubuğu ve bitiş saati; altta 10 sn
/// geri, oynat/duraklat (odak), 10 sn ileri, dizide Bölümler ve sonraki bölüm, Ses
/// ve altyazı, hız, duraklatınca Baştan başla, Seçenekler. Ad ve bilgi sol üstte
/// (VodInfo).
class VodBar extends StatelessWidget {
  const VodBar({
    super.key,
    required this.playing,
    required this.seekBar,
    required this.playFocusNode,
    this.endTime,
    this.resolution,
    this.nextLabel,
    this.speedLabel,
    this.onPlayPause,
    this.onSeekBy,
    this.onNext,
    this.onOptions,
    this.onEpisodes,
    this.onTracks,
    this.onSpeed,
    this.onRestart,
  });

  final bool playing;
  final Widget? seekBar;
  final FocusNode playFocusNode;

  /// Film bu saatte biter.
  final Widget? endTime;
  final String? resolution;
  final String? nextLabel;

  /// "1,25x"; sarılamayan yayında null.
  final String? speedLabel;
  final VoidCallback? onPlayPause;
  final ValueChanged<int>? onSeekBy;
  final VoidCallback? onNext;
  final VoidCallback? onOptions;
  final VoidCallback? onEpisodes;
  final VoidCallback? onTracks;
  final VoidCallback? onSpeed;

  /// Duraklatınca görünür; yoksa düğme yok.
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    return _BarShell(
      children: [
        Row(
          children: [
            Expanded(
              child:
                  seekBar ??
                  Text(resolution ?? '', style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant)),
            ),
            if (endTime case final end?) ...[const SizedBox(width: 16), end],
          ],
        ),
        const SizedBox(height: 6),
        _ControlRow(
          left: [
            _BarButton(
              icon: RedoxIcons.replay10,
              label: '10 sn geri',
              onPressed: onSeekBy == null ? null : () => onSeekBy!(-1),
            ),
            _PlayButton(playing: playing, focusNode: playFocusNode, onPressed: onPlayPause),
            _BarButton(
              icon: RedoxIcons.forward10,
              label: '10 sn ileri',
              onPressed: onSeekBy == null ? null : () => onSeekBy!(1),
            ),
          ],
          pills: [
            if (onEpisodes case final episodes?)
              _BarPill(icon: RedoxIcons.series, label: 'Bölümler', onPressed: episodes),
            if (nextLabel case final next?) _BarPill(icon: RedoxIcons.next, label: 'Sonraki: $next', onPressed: onNext),
            _BarPill(icon: RedoxIcons.subtitles, label: 'Ses ve altyazı', onPressed: onTracks),
            if (speedLabel case final speed?) _BarPill(label: 'Hız $speed', onPressed: onSpeed),
            if (onRestart case final restart?)
              _BarPill(icon: RedoxIcons.history, label: 'Baştan başla', onPressed: restart),
          ],
          onOptions: onOptions,
        ),
      ],
    );
  }
}

class _BarShell extends StatelessWidget {
  const _BarShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(RedoxRadius.xl),
      border: Border.fromBorderSide(RedoxElevation.restingBorder),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

/// Düğme satırı: oynatma düğmeleri, ince ayraç, yazılı düğmeler (sığmazsa kayar,
/// odak görünür alana getirir), sağda Seçenekler.
class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.left, required this.pills, required this.onOptions});

  final List<Widget> left;
  final List<Widget> pills;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, w) in left.indexed) ...[if (i > 0) const SizedBox(width: 10), w],
      const SizedBox(width: 14),
      Container(width: 1, height: 28, color: RedoxRoles.outlineVariant),
      const SizedBox(width: 6),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Odak parıltısı kesilmesin.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              for (final (i, w) in pills.indexed) ...[if (i > 0) const SizedBox(width: 10), w],
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      _BarButton(icon: RedoxIcons.moreHorizontal, label: 'Seçenekler', onPressed: onOptions),
    ],
  );
}

/// Kanal, şimdiki program, ilerleme ve sonraki program.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.channel,
    required this.resolution,
    required this.streamIndex,
    required this.streamCount,
  });

  final LiveChannel channel;
  final String? resolution;
  final int streamIndex;
  final int streamCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final meta = [resolution ?? '—', if (streamCount > 0) 'Akış ${streamIndex + 1}/$streamCount'].join(' · ');
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RedoxRadius.md),
          child: SizedBox.square(
            dimension: 56,
            child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${c.number}',
                    style: t.titleMedium!.copyWith(
                      color: RedoxRoles.tertiary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: RedoxType.tabular,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      c.name,
                      style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.live) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      height: 16,
                      child: FittedBox(child: StatusBadge(label: 'CANLI', pulse: true)),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Text(
                    meta,
                    style: RedoxType.bodySm.copyWith(
                      color: RedoxRoles.onSurfaceVariant,
                      fontFeatures: RedoxType.tabular,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
              if (c.programTitle case final program?) ...[
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      if (c.timeRange case final range?)
                        TextSpan(
                          text: '$range  ',
                          style: const TextStyle(color: RedoxRoles.tertiary, fontFeatures: RedoxType.tabular),
                        ),
                      TextSpan(text: program),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
              ],
              if (c.progress case final progress?) ...[
                const SizedBox(height: 6),
                RedoxProgressBar(value: progress, height: 4),
              ],
            ],
          ),
        ),
        if (c.next case final next?) ...[
          const SizedBox(width: 16),
          Container(width: 1, height: 44, color: RedoxRoles.outlineVariant),
          const SizedBox(width: 16),
          SizedBox(
            width: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sonra', style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant)),
                Text(
                  next,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RedoxType.labelMd.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Kızıl oynat/duraklat: çevresinde koyu kırmızı çizgi (kullanıcı isteği). Simgesi
/// açık: adı yazılmaz, üstündeki bilgi satırının önüne geçmesin.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.focusNode, this.onPressed});

  final bool playing;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  static const size = 56.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: playing ? 'Duraklat' : 'Oynat',
    excludeSemantics: true,
    child: FocusGlow(
      borderRadius: BorderRadius.circular(RedoxRadius.full),
      builder: (context, active) => Material(
        color: RedoxRoles.primaryContainer,
        shape: const CircleBorder(side: BorderSide(color: RedoxRoles.onPrimaryFixedVariant, width: 4)),
        child: InkWell(
          onTap: onPressed,
          focusNode: focusNode,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: RedoxIcon(
                playing ? RedoxIcons.pause : RedoxIcons.play,
                filled: true,
                color: RedoxRoles.onPrimaryContainer,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Yazılı çubuk düğmesi.
class _BarPill extends StatelessWidget {
  const _BarPill({required this.label, this.icon, this.onPressed});

  final String label;
  final RedoxIcons? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(RedoxRadius.full);
    return FocusGlow(
      borderRadius: shape,
      builder: (context, active) => Material(
        color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainerHigh,
        borderRadius: shape,
        child: InkWell(
          onTap: onPressed,
          borderRadius: shape,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon case final i?) ...[
                  RedoxIcon(i, color: RedoxRoles.onSurface, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  softWrap: false,
                  style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Çubuk düğmesi: yuvarlak, yalnız ikon; odakta adı üstünde yazar (eski sürümdeki
/// etiket).
class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, this.onPressed});

  final RedoxIcons icon;
  final String label;
  final VoidCallback? onPressed;

  static const size = 40.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: FocusGlow(
      borderRadius: BorderRadius.circular(RedoxRadius.full),
      builder: (context, active) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: active ? RedoxRoles.surfaceContainerHighest : RedoxRoles.surfaceContainerHigh,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: SizedBox.square(
                dimension: size,
                child: Center(child: RedoxIcon(icon, color: RedoxRoles.onSurface, size: 22)),
              ),
            ),
          ),
          if (active)
            Positioned(
              bottom: size + 12,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: RedoxRoles.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(RedoxRadius.full),
                  ),
                  child: Text(
                    label,
                    softWrap: false,
                    style: RedoxType.labelMd.copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Kanal değişince çubuğun üstünde kısa süre görünen kumanda ipuçları
/// (eski sürümdeki gibi): OK Kontroller · ▲▼ Kanal · ◄ Kanal listesi ·
/// ► Sonraki akış.
class PlayerHints extends StatelessWidget {
  const PlayerHints({super.key, required this.multiStream, this.previous = false});

  /// Tek akışlı kanalda "Sonraki akış" ipucu yazılmaz.
  final bool multiStream;

  /// Önceki kanal var: "0 Önceki kanal" ipucu.
  final bool previous;

  @override
  Widget build(BuildContext context) {
    const fg = RedoxRoles.onSurface;
    Widget keyIcons(List<RedoxIcons> icons) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: fg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(RedoxRadius.xs)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final i in icons) RedoxIcon(i, color: fg, size: 16)],
      ),
    );
    Widget hint(Widget key, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key,
        const SizedBox(width: 6),
        Text(text, style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant)),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(RedoxRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            hint(const KeyHint('OK', color: fg), 'Kontroller'),
            hint(keyIcons(const [RedoxIcons.expandLess, RedoxIcons.expandMore]), 'Kanal'),
            hint(keyIcons(const [RedoxIcons.chevronLeft]), 'Kanal listesi'),
            if (multiStream) hint(keyIcons(const [RedoxIcons.chevronRight]), 'Sonraki akış'),
            if (previous) hint(const KeyHint('0', color: fg), 'Önceki kanal'),
          ],
        ),
      ),
    );
  }
}
