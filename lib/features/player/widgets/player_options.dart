import 'package:flutter/material.dart';

import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_elevation.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/theme/redox_type.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';
import '../../../core/playback/engine/playback_engine.dart';

/// Görüntü ölçeği seçenekleri.
enum VideoScale {
  original('16:9 Orijinal', BoxFit.contain),
  fill('Ekranı doldur', BoxFit.cover),
  stretch('Uzat', BoxFit.fill);

  const VideoScale(this.label, this.fit);

  final String label;
  final BoxFit fit;
}

/// Oynatıcı Seçenekler menüsü (eski sürümden): Kalite, Ses, Altyazı, Ölçek,
/// Önceki kanal, Oynatıcıdan çık; altta ölçülen çözünürlük. Seçimli satır
/// alt listeye geçer; Geri alt listeden ana listeye, ana listeden kapatır
/// ([handleBack]). Uyku zamanlayıcı ve yayın bilgisi tek satırda değişir.
/// Eski sürümdeki gece modu, küçük pencere, 2×2, kanalı gizle
/// sonraki aşamadadır: işlevi olmayan satır gösterilmez.
class PlayerOptions extends StatefulWidget {
  const PlayerOptions({
    super.key,
    required this.engine,
    required this.scale,
    required this.onScale,
    required this.streamLabel,
    required this.onVideoTrack,
    required this.onAudioTrack,
    required this.onSubtitleTrack,
    this.previousChannelName,
    this.onPreviousChannel,
    this.onExit,
    this.onClose,
    this.onRestart,
    this.sleepLabel,
    this.onSleep,
    this.statsShown = false,
    this.onStats,
  });

  /// Uyku zamanlayıcı ("Kapalı", "28 dk"); satıra basmak sıradaki süreye
  /// geçer (Kapalı → 30 → 60 → 90 → Kapalı).
  final String? sleepLabel;
  final VoidCallback? onSleep;

  /// Yayın bilgisi paneli açık mı; satır açar/kapatır.
  final bool statsShown;
  final VoidCallback? onStats;

  final EngineState engine;
  final VideoScale scale;
  final ValueChanged<VideoScale> onScale;

  /// Örn. "Akış 1/2".
  final String streamLabel;

  /// Önceki kanalın adı; yoksa satır yazılmaz.
  final String? previousChannelName;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onExit;

  /// Film/dizi: "Baştan başla" (kaldığı yerden açılınca).
  final VoidCallback? onRestart;

  /// Menüyü kapatır; verilirse ana listenin başında "Kapat" satırı olur
  /// (dokunmatik: kumandadaki Geri'nin karşılığı).
  final VoidCallback? onClose;

  /// Kalite, ses ve altyazı seçimleri (iz kimliği).
  final ValueChanged<String> onVideoTrack;
  final ValueChanged<String> onAudioTrack;
  final ValueChanged<String> onSubtitleTrack;

  @override
  State<PlayerOptions> createState() => PlayerOptionsState();
}

/// Alt listedeki seçenek.
class _Choice {
  const _Choice(this.id, this.label);

  final String id;
  final String label;
}

/// Seçimli satırların türü.
enum _Menu { quality, audio, subtitle, scale }

class PlayerOptionsState extends State<PlayerOptions> {
  _Menu? _open;

  /// Geri: alt listedeyse ana listeye döner (true); ana listedeyse false
  /// (menüyü sayfa kapatır).
  bool handleBack() {
    if (_open == null) return false;
    setState(() => _open = null);
    return true;
  }

  EngineState get _e => widget.engine;

  static String _labelOf(List<MediaTrack> tracks, String id, {required String auto, String? off}) => switch (id) {
    EngineState.autoTrack => auto,
    EngineState.noTrack => off ?? auto,
    _ => tracks.where((t) => t.id == id).firstOrNull?.label ?? auto,
  };

  List<_Choice> _choices(_Menu menu) => switch (menu) {
    _Menu.quality => [
      const _Choice(EngineState.autoTrack, 'Otomatik'),
      for (final t in _e.videoTracks) _Choice(t.id, t.label),
    ],
    _Menu.audio => [
      const _Choice(EngineState.autoTrack, 'Otomatik'),
      for (final t in _e.audioTracks) _Choice(t.id, t.label),
    ],
    _Menu.subtitle => [
      const _Choice(EngineState.noTrack, 'Kapalı'),
      for (final t in _e.subtitleTracks) _Choice(t.id, t.label),
    ],
    _Menu.scale => [for (final s in VideoScale.values) _Choice(s.name, s.label)],
  };

  String _selected(_Menu menu) => switch (menu) {
    _Menu.quality => _e.videoTrack,
    _Menu.audio => _e.audioTrack,
    // mpv'de altyazı "auto" iken çoğu yayında gösterilmez: "Kapalı" sayılır.
    _Menu.subtitle => _e.subtitleTrack == EngineState.autoTrack ? EngineState.noTrack : _e.subtitleTrack,
    _Menu.scale => widget.scale.name,
  };

  static const _titles = {_Menu.quality: 'Kalite', _Menu.audio: 'Ses', _Menu.subtitle: 'Altyazı', _Menu.scale: 'Ölçek'};

  @override
  Widget build(BuildContext context) {
    final open = _open;
    final size = _e.hasVideo ? '${_e.width}×${_e.height}' : '—';
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(RedoxRadius.lg),
        border: Border.fromBorderSide(RedoxElevation.restingBorder),
      ),
      padding: const EdgeInsets.all(8),
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Çok izli yayında liste uzar: menü kayar (yüksekliği sayfa sınırlar).
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: open == null ? _main() : _sub(open),
                ),
              ),
            ),
            const Divider(height: 16, color: RedoxRoles.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$size · ${widget.streamLabel}',
                style: RedoxType.bodySm.copyWith(color: RedoxRoles.onSurfaceVariant, fontFeatures: RedoxType.tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _main() => [
    if (widget.onClose case final close?) _Row(icon: RedoxIcons.close, label: 'Kapat', onPressed: close),
    _Row(
      icon: RedoxIcons.quality,
      label: 'Kalite',
      value: _labelOf(_e.videoTracks, _e.videoTrack, auto: 'Otomatik'),
      autofocus: true,
      onPressed: () => setState(() => _open = _Menu.quality),
    ),
    _Row(
      icon: RedoxIcons.volume,
      label: 'Ses',
      value: _labelOf(_e.audioTracks, _e.audioTrack, auto: 'Otomatik', off: 'Kapalı'),
      onPressed: () => setState(() => _open = _Menu.audio),
    ),
    _Row(
      icon: RedoxIcons.subtitles,
      label: 'Altyazı',
      value: _labelOf(_e.subtitleTracks, _selected(_Menu.subtitle), auto: 'Kapalı', off: 'Kapalı'),
      onPressed: () => setState(() => _open = _Menu.subtitle),
    ),
    _Row(
      icon: RedoxIcons.aspectRatio,
      label: 'Ölçek',
      value: widget.scale.label,
      onPressed: () => setState(() => _open = _Menu.scale),
    ),
    if (widget.onRestart case final restart?)
      _Row(icon: RedoxIcons.replay10, label: 'Baştan başla', onPressed: restart),
    if (widget.previousChannelName != null)
      _Row(
        icon: RedoxIcons.previous,
        label: 'Önceki kanal',
        value: widget.previousChannelName!,
        onPressed: widget.onPreviousChannel,
      ),
    if (widget.onSleep case final sleep?)
      _Row(icon: RedoxIcons.clock, label: 'Uyku zamanlayıcı', value: widget.sleepLabel, onPressed: sleep),
    if (widget.onStats case final stats?)
      _Row(
        icon: RedoxIcons.info,
        label: 'Yayın bilgisi',
        value: widget.statsShown ? 'Açık' : 'Kapalı',
        onPressed: stats,
      ),
    _Row(icon: RedoxIcons.close, label: 'Oynatıcıdan çık', onPressed: widget.onExit),
  ];

  List<Widget> _sub(_Menu menu) {
    final selected = _selected(menu);
    return [
      _Row(icon: RedoxIcons.chevronLeft, label: _titles[menu]!, onPressed: () => setState(() => _open = null)),
      const Divider(height: 8, color: RedoxRoles.outlineVariant),
      for (final c in _choices(menu))
        _Row(
          label: c.label,
          checked: c.id == selected,
          autofocus: c.id == selected,
          onPressed: () {
            _apply(menu, c.id);
            setState(() => _open = null);
          },
        ),
    ];
  }

  void _apply(_Menu menu, String id) {
    switch (menu) {
      case _Menu.quality:
        widget.onVideoTrack(id);
      case _Menu.audio:
        widget.onAudioTrack(id);
      case _Menu.subtitle:
        widget.onSubtitleTrack(id);
      case _Menu.scale:
        widget.onScale(VideoScale.values.byName(id));
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    this.icon,
    this.value,
    this.checked = false,
    this.autofocus = false,
    this.onPressed,
  });

  final RedoxIcons? icon;
  final String label;
  final String? value;
  final bool checked;
  final bool autofocus;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(RedoxRadius.md);
    return FocusGlow(
      borderRadius: radius,
      scale: 1,
      builder: (context, active) {
        final fg = checked ? RedoxRoles.tertiary : RedoxRoles.onSurface;
        return Material(
          color: active ? RedoxRoles.surfaceContainerHigh : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: onPressed,
            autofocus: autofocus,
            borderRadius: radius,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  if (icon != null) ...[
                    RedoxIcon(icon!, color: RedoxRoles.onSurfaceVariant, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: RedoxType.labelLg.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (value != null)
                    Flexible(
                      child: Text(
                        value!,
                        style: RedoxType.labelMd.copyWith(color: RedoxRoles.secondary, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  if (checked) const RedoxIcon(RedoxIcons.check, color: RedoxRoles.tertiary, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
