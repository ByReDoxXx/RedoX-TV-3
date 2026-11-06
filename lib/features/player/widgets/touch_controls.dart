import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/content/live_channel.dart';
import '../../../core/platform/device_controls.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/channel_logo.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/ui/status_badge.dart';
import 'seek_bar.dart';

/// Dokunmatik oynatıcı katmanı (telefon, tablet, açık katlanabilir telefon;
/// kullanıcı isteği: "play/ileri/geri ortada olsun, tema televizyondan farklı
/// olsun"). TV'nin kızıl alt çubuğu yerine görüntünün üstünde ve altında
/// karartma; düğmeler beyaz cam daireler, oynat/duraklat ortada kızıl dolu.
/// Üstte kapat, kanal kimliği, kanal listesi ve Seçenekler; ortada önceki
/// kanal · oynat/duraklat · sonraki kanal (yalnız görüntü gelince, yoksa
/// ortada yükleniyor/hata durur); altta ölçek, akış ve çözünürlük.
class TouchControls extends StatelessWidget {
  const TouchControls({
    super.key,
    required this.channel,
    required this.playing,
    required this.showCenter,
    required this.resolution,
    required this.streamIndex,
    required this.streamCount,
    required this.scaleLabel,
    this.clock,
    this.onClose,
    this.onPlayPause,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onChannelList,
    this.onNextStream,
    this.onScale,
    this.onOptions,
    this.seekBar,
    this.onSeekBy,
  });

  /// Film/dizi: alt satırın üstünde sarma çubuğu; canlı yayında null.
  final Widget? seekBar;

  /// Film/dizi: ortadaki düğmeler kanal yerine ±10 sn sarar (-1/+1).
  final ValueChanged<int>? onSeekBy;

  final LiveChannel channel;
  final bool playing;

  /// Ortadaki düğmeler: görüntü gelince (yüklenirken/açılamayınca orta
  /// durum katmanınındır).
  final bool showCenter;
  final String? resolution;
  final int streamIndex;
  final int streamCount;
  final String scaleLabel;
  final String? clock;
  final VoidCallback? onClose;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onChannelList;
  final VoidCallback? onNextStream;
  final VoidCallback? onScale;
  final VoidCallback? onOptions;

  static const _scrim = Color(0xB3000000);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = channel;
    final program = c.programTitle;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Karartma: üstte ve altta koyu, ortası açık (görüntü görünsün).
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_scrim, Color(0x33000000), Color(0x33000000), _scrim],
                stops: [0, 0.3, 0.7, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    GlassCircle(icon: RedoxIcons.expandMore, label: 'Kapat', onPressed: onClose),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RedoxRadius.md),
                      child: SizedBox.square(
                        dimension: 40,
                        child: ChannelLogo(name: c.name, logoUrl: c.logoUrl, size: 1, alignment: Alignment.center),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.number}  ${c.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          if (program != null)
                            Text(
                              program,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall!.copyWith(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    if (clock case final clock?) ...[
                      Text(
                        clock,
                        style: t.titleSmall!.copyWith(color: Colors.white, fontFeatures: RedoxType.tabular),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GlassCircle(icon: RedoxIcons.television, label: 'Kanal listesi', onPressed: onChannelList),
                    const SizedBox(width: 8),
                    GlassCircle(icon: RedoxIcons.more, label: 'Seçenekler', onPressed: onOptions),
                  ],
                ),
                const Spacer(),
                if (showCenter)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (onSeekBy case final seekBy?)
                        GlassCircle(
                          icon: RedoxIcons.replay10,
                          label: '10 sn geri',
                          size: 56,
                          onPressed: () => seekBy(-1),
                        )
                      else
                        GlassCircle(
                          icon: RedoxIcons.previous,
                          label: 'Önceki kanal',
                          size: 56,
                          onPressed: onPreviousChannel,
                        ),
                      const SizedBox(width: 32),
                      GlassCircle(
                        icon: playing ? RedoxIcons.pause : RedoxIcons.play,
                        label: playing ? 'Duraklat' : 'Oynat',
                        size: 80,
                        solid: true,
                        onPressed: onPlayPause,
                      ),
                      const SizedBox(width: 32),
                      if (onSeekBy case final seekBy?)
                        GlassCircle(
                          icon: RedoxIcons.forward10,
                          label: '10 sn ileri',
                          size: 56,
                          onPressed: () => seekBy(1),
                        )
                      else
                        GlassCircle(icon: RedoxIcons.next, label: 'Sonraki kanal', size: 56, onPressed: onNextChannel),
                    ],
                  ),
                const Spacer(),
                if (seekBar case final bar?) ...[bar, const SizedBox(height: 4)],
                Row(
                  children: [
                    if (c.live) ...[
                      const SizedBox(
                        height: 18,
                        child: FittedBox(child: StatusBadge(label: 'CANLI', pulse: true)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (resolution case final r?) _Chip(label: r),
                    const Spacer(),
                    if (streamCount > 1) ...[
                      _Chip(
                        label: 'Akış ${streamIndex + 1}/$streamCount',
                        icon: RedoxIcons.sync,
                        onPressed: onNextStream,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _Chip(label: scaleLabel, icon: RedoxIcons.aspectRatio, onPressed: onScale),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Film ve dizi oynatıcısı (dokunmatik; kullanıcı isteği: "Film ve Dizi
/// kısmında oynatıcı tasarımı farklı olsun"): sinema düzeni. Üstte kapat,
/// büyük başlık ve sezon/bölüm satırı, Ses/Altyazı, Seçenekler; ortada 10 sn geri ·
/// oynat/duraklat · 10 sn ileri; altta tam genişlik sarma çubuğu (kalan süreyle),
/// altında (dizide) Bölümler ve sonraki bölüm, sağda hız, kilit ve ölçek. Kanal
/// numarası, CANLI ve kanal listesi yok.
class VodTouchControls extends StatelessWidget {
  const VodTouchControls({
    super.key,
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.showCenter,
    required this.seekBar,
    required this.scaleLabel,
    this.poster,
    this.nextLabel,
    this.speedLabel,
    this.onClose,
    this.onPlayPause,
    this.onSeekBy,
    this.onNext,
    this.onScale,
    this.onOptions,
    this.onTracks,
    this.onEpisodes,
    this.onSpeed,
    this.onLock,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final bool showCenter;
  final Widget? seekBar;
  final String scaleLabel;
  final String? poster;

  /// "1,25x"; sarılamayan yayında null.
  final String? speedLabel;
  final VoidCallback? onTracks;

  /// Dizi: bölüm paneli; yoksa düğme yok.
  final VoidCallback? onEpisodes;
  final VoidCallback? onSpeed;

  /// Ekran kilidi; yoksa düğme yok (masaüstü).
  final VoidCallback? onLock;

  /// Dizide sonraki bölümün kısa adı ("S2 · B4"); yoksa düğme yok.
  final String? nextLabel;
  final VoidCallback? onClose;
  final VoidCallback? onPlayPause;
  final ValueChanged<int>? onSeekBy;
  final VoidCallback? onNext;
  final VoidCallback? onScale;
  final VoidCallback? onOptions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Color(0x22000000), Color(0x22000000), Color(0xE6000000)],
                stops: [0, 0.32, 0.6, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCircle(icon: RedoxIcons.back, label: 'Kapat', onPressed: onClose),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.headlineSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
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
                    const SizedBox(width: 8),
                    GlassCircle(icon: RedoxIcons.subtitles, label: 'Ses ve altyazı', onPressed: onTracks),
                    const SizedBox(width: 8),
                    GlassCircle(icon: RedoxIcons.more, label: 'Seçenekler', onPressed: onOptions),
                  ],
                ),
                const Spacer(),
                if (showCenter)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlassCircle(
                        icon: RedoxIcons.replay10,
                        label: '10 sn geri',
                        size: 60,
                        onPressed: onSeekBy == null ? null : () => onSeekBy!(-1),
                      ),
                      const SizedBox(width: 40),
                      GlassCircle(
                        icon: playing ? RedoxIcons.pause : RedoxIcons.play,
                        label: playing ? 'Duraklat' : 'Oynat',
                        size: 84,
                        solid: true,
                        onPressed: onPlayPause,
                      ),
                      const SizedBox(width: 40),
                      GlassCircle(
                        icon: RedoxIcons.forward10,
                        label: '10 sn ileri',
                        size: 60,
                        onPressed: onSeekBy == null ? null : () => onSeekBy!(1),
                      ),
                    ],
                  ),
                const Spacer(),
                ?seekBar,
                const SizedBox(height: 6),
                // Dar ekranda (dikey telefon) düğmeler sığmazsa kayar.
                LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: box.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEpisodes case final episodes?) ...[
                                _Chip(label: 'Bölümler', icon: RedoxIcons.series, onPressed: episodes),
                                const SizedBox(width: 8),
                              ],
                              if (nextLabel case final next?)
                                _Chip(label: 'Sonraki: $next', icon: RedoxIcons.next, onPressed: onNext),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (speedLabel case final speed?) ...[
                                _Chip(label: 'Hız $speed', onPressed: onSpeed),
                                const SizedBox(width: 8),
                              ],
                              if (onLock case final lock?) ...[
                                _Chip(label: 'Kilit', icon: RedoxIcons.lock, onPressed: lock),
                                const SizedBox(width: 8),
                              ],
                              _Chip(label: scaleLabel, icon: RedoxIcons.aspectRatio, onPressed: onScale),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cam daire düğme: yarı saydam beyaz zemin, beyaz ikon. [solid]: kızıl dolu,
/// koyu kırmızı 4 dp kenarlı, beyaz ikon (oynat/duraklat; kullanıcı isteği:
/// TV'deki gibi kırmızı, kenarı daha kırmızı).
class GlassCircle extends StatelessWidget {
  const GlassCircle({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.size = 44,
    this.solid = false,
  });

  final RedoxIcons icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: solid ? RedoxRoles.primaryContainer : Colors.white.withValues(alpha: 0.14),
        shape: CircleBorder(
          side: solid
              ? const BorderSide(color: RedoxRoles.onPrimaryFixedVariant, width: 4)
              : BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: RedoxIcon(icon, filled: true, size: size * 0.5, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.onPressed});

  final String label;
  final RedoxIcons? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: onPressed == null ? 4 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon case final i?) ...[RedoxIcon(i, size: 18, color: Colors.white), const SizedBox(width: 6)],
              Text(
                label,
                style: t.labelLarge!.copyWith(color: Colors.white, fontFeatures: RedoxType.tabular),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yatay kaydırmayla sarma (film/dizi).
class ScrubTarget {
  const ScrubTarget({required this.position, required this.duration, required this.onSeek});

  final ValueListenable<Duration> position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
}

/// Oynatıcı jestleri (dokunmatik): dokunma katmanı açar/kapar; çift dokunma
/// ve iki parmakla açma/kapama ekranı doldurur/sığdırır (film/dizide sağa
/// çift dokunma 10 sn ileri, sola geri sarar); yatay kaydırma canlıda
/// kanal değiştirir (sola: sonraki), film/dizide gidilecek zamanı gösterip
/// bırakınca sarar; solda dikey kaydırma parlaklık, sağda
/// ses (cihaz sesi, [DeviceControls]). Ayarlanan değer ortada gösterilir.
class PlayerGestures extends StatefulWidget {
  const PlayerGestures({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onZap,
    this.onPinch,
    this.adjust = true,
    this.onSeekSide,
    this.scrub,
  });

  /// Verilirse yatay kaydırma sarar ([onZap] yerine).
  final ScrubTarget? scrub;

  /// Ekran genişliğince kaydırmanın sardığı süre.
  static const scrubRange = Duration(minutes: 2);

  /// Film/dizi: ekranın sağ üçte birine çift dokunma ileri (+1), sol üçte
  /// birine geri (-1) sarar; ortası [onDoubleTap]. Null ise her yer
  /// [onDoubleTap].
  final ValueChanged<int>? onSeekSide;

  /// Bir çift dokunmanın sardığı süre.
  static const seekStep = Duration(seconds: 10);

  /// Dikey kaydırma ses ve parlaklığı değiştirir (Ayarlar › Dokunma
  /// hareketleri kapalıysa false).
  final bool adjust;

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// +1: sonraki kanal, -1: önceki.
  final ValueChanged<int>? onZap;

  /// true: büyüt (doldur), false: küçült (sığdır).
  final ValueChanged<bool>? onPinch;

  /// Kanal değiştiren yatay kaydırma (dp).
  static const zapDistance = 80.0;

  /// Yönü belirleyen ilk hareket (dp).
  static const slop = 16.0;

  @override
  State<PlayerGestures> createState() => PlayerGesturesState();
}

enum _Drag { none, horizontal, brightness, volume, pinch, ignored }

@visibleForTesting
class PlayerGesturesState extends State<PlayerGestures> {
  _Drag _drag = _Drag.none;
  Offset _start = Offset.zero;
  Offset _total = Offset.zero;
  double? _base;
  double _scale = 1;

  /// Gösterilen seviye (ses ya da parlaklık); null: gösterge yok.
  ({RedoxIcons icon, double value})? level;
  Timer? _hide;

  /// Çift dokunmanın yeri; son sarma göstergesi (yön ve art arda toplam).
  Offset? _doubleTapAt;
  ({int side, int seconds})? seekFlash;
  Timer? _seekHide;

  /// Kaydırmanın başındaki konum ve gidilecek yer.
  Duration? _scrubFrom;
  Duration? scrubTo;

  void _onDoubleTap() {
    final side = widget.onSeekSide;
    final at = _doubleTapAt;
    final width = context.size?.width ?? 0;
    final dir = at == null || width == 0
        ? 0
        : at.dx < width / 3
        ? -1
        : at.dx > width * 2 / 3
        ? 1
        : 0;
    if (side == null || dir == 0) {
      widget.onDoubleTap?.call();
      return;
    }
    side(dir);
    // Art arda çift dokunmalar toplanır: "+30 sn".
    final step = PlayerGestures.seekStep.inSeconds;
    final previous = seekFlash;
    _seekHide?.cancel();
    setState(
      () => seekFlash = (side: dir, seconds: previous != null && previous.side == dir ? previous.seconds + step : step),
    );
    _seekHide = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => seekFlash = null);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    _seekHide?.cancel();
    super.dispose();
  }

  void _onStart(ScaleStartDetails d) {
    _drag = d.pointerCount > 1 ? _Drag.pinch : _Drag.none;
    _start = d.localFocalPoint;
    _total = Offset.zero;
    _scale = 1;
    _base = null;
  }

  Future<void> _onUpdate(ScaleUpdateDetails d) async {
    if (d.pointerCount > 1) {
      _drag = _Drag.pinch;
      _scale = d.scale;
      return;
    }
    final size = context.size ?? const Size(1, 1);
    _total += d.focalPointDelta;
    if (_drag == _Drag.none && _total.distance > PlayerGestures.slop) {
      final width = size.width;
      _drag = _total.dx.abs() > _total.dy.abs()
          ? _Drag.horizontal
          : _start.dx < width / 2
          ? _Drag.brightness
          : _Drag.volume;
      if (!widget.adjust && _drag != _Drag.horizontal) _drag = _Drag.ignored;
      if (_drag == _Drag.horizontal) _scrubFrom = widget.scrub?.position.value;
      if (_drag == _Drag.brightness || _drag == _Drag.volume) {
        final v = _drag == _Drag.volume ? await DeviceControls.volume() : await DeviceControls.brightness();
        _base = v ?? 0.5;
      }
    }
    if (_drag == _Drag.horizontal) {
      final scrub = widget.scrub;
      final from = _scrubFrom;
      if (scrub == null || from == null) return;
      final to = from + PlayerGestures.scrubRange * (_total.dx / size.width);
      setState(() => scrubTo = to < Duration.zero ? Duration.zero : (to > scrub.duration ? scrub.duration : to));
      return;
    }
    final base = _base;
    if (base == null || !(_drag == _Drag.brightness || _drag == _Drag.volume)) return;
    // Ekran yüksekliğinin %80'i: en kısıktan en açığa.
    final value = (base - _total.dy / (size.height * 0.8)).clamp(0.0, 1.0);
    if (_drag == _Drag.volume) {
      unawaited(DeviceControls.setVolume(value));
    } else {
      unawaited(DeviceControls.setBrightness(value));
    }
    _hide?.cancel();
    setState(() => level = (icon: _drag == _Drag.volume ? RedoxIcons.volume : RedoxIcons.brightness, value: value));
  }

  void _onEnd(ScaleEndDetails d) {
    final to = scrubTo;
    if (to != null) {
      setState(() => scrubTo = null);
      if ((to - _scrubFrom!).abs() >= const Duration(seconds: 1)) widget.scrub?.onSeek(to);
    }
    switch (_drag) {
      case _Drag.horizontal when widget.scrub == null && _total.dx.abs() >= PlayerGestures.zapDistance:
        widget.onZap?.call(_total.dx < 0 ? 1 : -1);
      case _Drag.pinch when _scale > 1.15 || _scale < 0.87:
        widget.onPinch?.call(_scale > 1);
      case _Drag.brightness || _Drag.volume:
        _hide = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => level = null);
        });
      default:
        break;
    }
    _drag = _Drag.none;
  }

  @override
  Widget build(BuildContext context) {
    final l = level;
    final to = scrubTo;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: widget.onDoubleTap == null && widget.onSeekSide == null ? null : _onDoubleTap,
      onScaleStart: _onStart,
      onScaleUpdate: (d) => unawaited(_onUpdate(d)),
      onScaleEnd: _onEnd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (seekFlash case final f?)
            Align(
              alignment: f.side < 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 1 / 3,
                heightFactor: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: f.side < 0 ? Alignment.centerLeft : Alignment.centerRight,
                        radius: 1,
                        colors: const [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RedoxIcon(
                            f.side < 0 ? RedoxIcons.replay10 : RedoxIcons.forward10,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${f.side < 0 ? '−' : '+'}${f.seconds} sn',
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (to != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(RedoxRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      SeekBar.format(to),
                      style: Theme.of(context).textTheme.headlineSmall!
                          .copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontFeatures: RedoxType.tabular),
                    ),
                    Text(
                      '${to < _scrubFrom! ? '−' : '+'}${SeekBar.format((to - _scrubFrom!).abs())}',
                      style: Theme.of(context).textTheme.titleSmall!
                          .copyWith(color: Colors.white70, fontFeatures: RedoxType.tabular),
                    ),
                  ],
                ),
              ),
            ),
          if (l != null)
            Center(
              child: Container(
                width: 160,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xCC000000),
                  borderRadius: BorderRadius.circular(RedoxRadius.lg),
                ),
                child: Row(
                  children: [
                    RedoxIcon(l.icon, filled: true, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(RedoxRadius.full),
                        child: LinearProgressIndicator(
                          value: l.value,
                          minHeight: 6,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
