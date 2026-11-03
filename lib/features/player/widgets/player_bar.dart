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
import '../../../core/ui/status_badge.dart';

/// Oynatıcının alt çubuğu (eski sürümün düzeni): solda kanal kimliği
/// (logo + numara rozeti, ad, CANLI, çözünürlük, "Akış 1/2"), ortada önceki
/// kanal · oynat/duraklat · sonraki kanal, sağda kanal listesi, sonraki akış
/// ve Seçenekler. Odaktaki düğmenin adı üstünde yazar. Dar ekranda (telefon)
/// kimlik üstte, düğmeler altta iki satırdır.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.channel,
    required this.playing,
    required this.resolution,
    required this.streamIndex,
    required this.streamCount,
    required this.playFocusNode,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onChannelList,
    this.onNextStream,
    this.onOptions,
  });

  final LiveChannel channel;
  final bool playing;

  /// Ölçülen çözünürlük, örn. "720p"; bilinmiyorsa null.
  final String? resolution;
  final int streamIndex;
  final int streamCount;

  /// OK ile çubuk açılınca odak buraya gelir (oynat/duraklat).
  final FocusNode playFocusNode;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onChannelList;
  final VoidCallback? onNextStream;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(icon: RedoxIcons.previous, label: 'Önceki kanal', onPressed: onPreviousChannel),
        const SizedBox(width: 10),
        _BarButton(
          icon: playing ? RedoxIcons.pause : RedoxIcons.play,
          label: playing ? 'Duraklat' : 'Oynat',
          onPressed: onPlayPause,
          focusNode: playFocusNode,
          primary: true,
        ),
        const SizedBox(width: 10),
        _BarButton(icon: RedoxIcons.next, label: 'Sonraki kanal', onPressed: onNextChannel),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BarButton(icon: RedoxIcons.television, label: 'Kanal listesi', onPressed: onChannelList),
        if (streamCount > 1) ...[
          const SizedBox(width: 10),
          _BarButton(icon: RedoxIcons.sync, label: 'Sonraki akış', onPressed: onNextStream),
        ],
        const SizedBox(width: 10),
        _BarButton(icon: RedoxIcons.moreHorizontal, label: 'Seçenekler', onPressed: onOptions),
      ],
    );
    final identity = _Identity(
      channel: channel,
      resolution: resolution,
      streamIndex: streamIndex,
      streamCount: streamCount,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        border: Border.fromBorderSide(RedoxElevation.restingBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, box) => box.maxWidth < 640
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Row(children: [controls, const Spacer(), actions]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: identity),
                    controls,
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: actions),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// TV'de film ve dizi çubuğu (canlı yayının kanal çubuğu yerine): büyük
/// başlık ve sezon/bölüm satırı, tam genişlik sarma çubuğu, altında 10 sn
/// geri · oynat/duraklat · 10 sn ileri ve sağda (dizide) sonraki bölüm,
/// Seçenekler. ◄► çubuk kapalıyken de sarar.
class VodBar extends StatelessWidget {
  const VodBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.seekBar,
    required this.playFocusNode,
    this.resolution,
    this.nextLabel,
    this.onPlayPause,
    this.onSeekBy,
    this.onNext,
    this.onOptions,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final Widget? seekBar;
  final FocusNode playFocusNode;
  final String? resolution;
  final String? nextLabel;
  final VoidCallback? onPlayPause;
  final ValueChanged<int>? onSeekBy;
  final VoidCallback? onNext;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(RedoxRadius.xl),
        border: Border.fromBorderSide(RedoxElevation.restingBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.titleLarge!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall!.copyWith(color: RedoxRoles.tertiary),
                        ),
                    ],
                  ),
                ),
                if (resolution case final r?)
                  Text(r, style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant)),
              ],
            ),
            if (seekBar case final bar?) ...[const SizedBox(height: 6), bar],
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _BarButton(
                  icon: RedoxIcons.replay10,
                  label: '10 sn geri',
                  onPressed: onSeekBy == null ? null : () => onSeekBy!(-1),
                ),
                const SizedBox(width: 10),
                _BarButton(
                  icon: playing ? RedoxIcons.pause : RedoxIcons.play,
                  label: playing ? 'Duraklat' : 'Oynat',
                  onPressed: onPlayPause,
                  focusNode: playFocusNode,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _BarButton(
                  icon: RedoxIcons.forward10,
                  label: '10 sn ileri',
                  onPressed: onSeekBy == null ? null : () => onSeekBy!(1),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (nextLabel case final next?) ...[
                        _BarButton(icon: RedoxIcons.next, label: 'Sonraki bölüm · $next', onPressed: onNext),
                        const SizedBox(width: 10),
                      ],
                      _BarButton(icon: RedoxIcons.moreHorizontal, label: 'Seçenekler', onPressed: onOptions),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RedoxRadius.md),
              child: SizedBox.square(
                dimension: 48,
                child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
              ),
            ),
            Positioned(
              left: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: RedoxRoles.primaryContainer,
                  borderRadius: BorderRadius.circular(RedoxRadius.full),
                ),
                child: Text(
                  '${c.number}',
                  style: RedoxType.labelSm.copyWith(
                    color: RedoxRoles.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    fontFeatures: RedoxType.tabular,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name,
                style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  if (c.live) ...[
                    const SizedBox(
                      height: 16,
                      child: FittedBox(child: StatusBadge(label: 'CANLI', pulse: true)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      meta,
                      style: RedoxType.bodySm.copyWith(
                        color: RedoxRoles.onSurfaceVariant,
                        fontFeatures: RedoxType.tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Çubuk düğmesi: yuvarlak, yalnız ikon; odakta adı üstünde yazar (eski
/// sürümdeki "Duraklat" etiketi). [primary]: büyük kızıl oynat/duraklat;
/// satırda [primaryRowHeight] yer kaplar, çubuğun üstünden ve altından taşar
/// (kullanıcı isteği).
class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, this.onPressed, this.focusNode, this.primary = false});

  final RedoxIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool primary;

  static const primarySize = 92.0;
  static const primaryRowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final size = primary ? primarySize : 40.0;
    final shape = BorderRadius.circular(RedoxRadius.full);
    final button = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: FocusGlow(
        borderRadius: shape,
        builder: (context, active) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Material(
              color: primary
                  ? RedoxRoles.primaryContainer
                  : active
                  ? RedoxRoles.surfaceContainerHighest
                  : RedoxRoles.surfaceContainerHigh,
              // Oynat/duraklatın çevresinde koyu kırmızı çizgi (kullanıcı isteği).
              shape: primary
                  ? const CircleBorder(side: BorderSide(color: RedoxRoles.onPrimaryFixedVariant, width: 4))
                  : const CircleBorder(),
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
                      icon,
                      filled: primary,
                      color: primary ? RedoxRoles.onPrimaryContainer : RedoxRoles.onSurface,
                      size: primary ? 46 : 22,
                    ),
                  ),
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
    if (!primary) return button;
    // Satırda daha az yer kaplar; görünür boyu taşar.
    return SizedBox(
      width: size,
      height: primaryRowHeight,
      child: OverflowBox(maxHeight: size, child: button),
    );
  }
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
