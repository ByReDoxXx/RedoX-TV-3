import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/favorites.dart';
import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/playback/radio_controller.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/ui/focus_glow.dart';
import '../../core/ui/icon_action_button.dart';
import '../../core/ui/key_hint.dart';
import '../../core/ui/redox_icon.dart';
import '../../core/ui/status_badge.dart';
import 'widgets/radio_dial.dart';
import 'widgets/radio_options.dart';
import 'widgets/sound_wave.dart';

/// Tam ekran radyo: "Kadran" (eski uygulamada seçilen K2; tv-16 görüntüsünün
/// bizim temaya uyarlaması). Üstte durum ve yayın, ortada büyük istasyon adı
/// ve çalan şarkı, altında kadran, ses dalgası ve düğmeler.
///
/// Kumanda: ◄ ► kadranı çevirir, yeni istasyon [tuneDelay] sonra çalar (ses
/// yeni yayın bağlanana kadar kesilmez); OK duraklat/sürdür; ▲ listeye dön;
/// ▼ düğmeler. Geri listeye döner, ses sürer. Telefonda kadran kaydırılır.
class RadioPlayerPage extends StatefulWidget {
  const RadioPlayerPage({super.key, required this.radio, required this.stations, this.favorites, this.clock});

  final RadioController radio;

  /// Kadrandaki istasyonlar (listede seçili tür; sırası listeyle aynı).
  final List<LiveChannel> stations;
  final Favorites? favorites;
  final String? clock;

  static const tuneDelay = Duration(milliseconds: 700);

  static Route<void> route({
    required RadioController radio,
    required List<LiveChannel> stations,
    Favorites? favorites,
    String? clock,
  }) => PageRouteBuilder(
    pageBuilder: (_, _, _) => RadioPlayerPage(radio: radio, stations: stations, favorites: favorites, clock: clock),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  );

  @override
  State<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends State<RadioPlayerPage> {
  late int _tuned = _indexOfCurrent();
  Timer? _tune;
  bool _dialFocused = false;
  double _drag = 0;

  RadioController get _radio => widget.radio;
  List<LiveChannel> get _list => widget.stations;

  int _indexOfCurrent() {
    final i = _radio.current == null ? -1 : _list.indexOf(_radio.current!);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _tune?.cancel();
    super.dispose();
  }

  /// Kadranı [step] istasyon çevirir; durunca çalar.
  void _turn(int step) {
    if (_list.isEmpty) return;
    setState(() => _tuned = (_tuned + step) % _list.length);
    _radio.tuning();
    _tune?.cancel();
    _tune = Timer(RadioPlayerPage.tuneDelay, _playTuned);
  }

  void _playTuned() {
    _tune?.cancel();
    final s = _list[_tuned];
    if (s != _radio.current) unawaited(_radio.play(s));
  }

  /// OK: kadran başka istasyondaysa hemen onu çalar; değilse duraklat/sürdür.
  void _ok() {
    if (_list.isNotEmpty && _list[_tuned] != _radio.current) {
      _playTuned();
    } else {
      unawaited(_radio.toggle());
    }
  }

  KeyEventResult _onDialKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _turn(-1);
      case LogicalKeyboardKey.arrowRight:
        _turn(1);
      case LogicalKeyboardKey.arrowUp:
        Navigator.maybePop(context);
      case LogicalKeyboardKey.select || LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (e is KeyDownEvent) _ok();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Future<void> _options() async {
    final closed = await showRadioOptions(context, radio: _radio, favorites: widget.favorites);
    if ((closed ?? false) && mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final metrics = Theme.of(context).extension<RedoxMetrics>()!;
    final phone = metrics.formFactor == FormFactor.phone;
    return Scaffold(
      backgroundColor: RedoxSeeds.obsidian,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.1,
            colors: [Color(0x55D7232C), Color(0x00D7232C)],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([_radio, ?widget.favorites]),
            builder: (context, _) => LayoutBuilder(builder: (context, box) => _body(context, box, phone)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, BoxConstraints box, bool phone) {
    final t = Theme.of(context).textTheme;
    final current = _radio.current;
    final tuned = _list.isEmpty ? current : _list[_tuned];
    // Gezinirken eski istasyon çalar; üstteki ad kadrandaki istasyondur, solar.
    final browsing = tuned != null && tuned != current;
    final status = _radio.status;
    final (n, m) = _radio.streamPosition;
    final badge = switch (status) {
      RadioStatus.playing => const StatusBadge(label: 'ÇALIYOR', pulse: true),
      RadioStatus.connecting => const StatusBadge(label: 'BAĞLANIYOR', tone: BadgeTone.amber),
      RadioStatus.paused => const StatusBadge(label: 'DURAKLATILDI', tone: BadgeTone.neutral),
      RadioStatus.failed => const StatusBadge(label: 'YAYIN AÇILMADI', tone: BadgeTone.neutral),
      RadioStatus.idle => const StatusBadge(label: 'RADYO', tone: BadgeTone.neutral),
    };
    final info = [?tuned?.category, if (m > 0) 'yayın $n/$m'].join(' · ');
    final sleep = _radio.sleepLeft;
    final dialHeight = (box.maxHeight * (phone ? 0.24 : 0.3)).clamp(120.0, 200.0);
    final fav = tuned != null && (widget.favorites?.hasRadio(tuned.number) ?? false);
    final playing = status == RadioStatus.playing || status == RadioStatus.connecting;
    final pad = phone ? 16.0 : 40.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, phone ? 8 : 20, pad, phone ? 16 : 20),
      child: Column(
        children: [
          // Üst şerit: bölüm adı, durum, saat.
          Row(
            children: [
              if (phone)
                IconActionButton(icon: RedoxIcons.expandMore, onPressed: () => Navigator.maybePop(context))
              else ...[
                const RedoxIcon(RedoxIcons.radio, color: RedoxSeeds.crimson),
                const SizedBox(width: 10),
                Text('RADYO', style: t.titleMedium!.copyWith(color: RedoxRoles.onSurfaceVariant, letterSpacing: 2)),
              ],
              const Spacer(),
              if (sleep != null) ...[
                const RedoxIcon(RedoxIcons.clock, color: RedoxSeeds.gold, size: 18),
                const SizedBox(width: 6),
                Text(RadioOptions.sleepLabel(sleep), style: t.labelLarge!.copyWith(color: RedoxSeeds.gold)),
                const SizedBox(width: 16),
              ],
              if (widget.clock case final c? when !phone)
                Text(
                  c,
                  style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
                ),
              if (phone) IconActionButton(icon: RedoxIcons.moreHorizontal, onPressed: _options),
            ],
          ),
          const Spacer(),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              badge,
              if (info.isNotEmpty) Text(info, style: t.titleSmall!.copyWith(color: RedoxRoles.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: browsing ? 0.55 : 1,
            duration: const Duration(milliseconds: 200),
            child: Text(
              tuned?.name ?? 'İstasyon seçin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (phone ? t.headlineLarge : t.displaySmall)!.copyWith(
                color: RedoxRoles.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            browsing ? 'OK ile hemen çal' : (_radio.title ?? (playing ? 'Şarkı bilgisi yok' : '')),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: t.titleLarge!.copyWith(
              color: browsing || _radio.title == null ? RedoxRoles.onSurfaceVariant : RedoxSeeds.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            // Telefonda kadran kaydırılır: her ~80 dp bir istasyon.
            onHorizontalDragUpdate: (d) {
              _drag += d.delta.dx;
              while (_drag.abs() > 80) {
                _turn(_drag > 0 ? -1 : 1);
                _drag -= _drag.sign * 80;
              }
            },
            onHorizontalDragEnd: (_) => _drag = 0,
            child: Focus(
              autofocus: true,
              onKeyEvent: _onDialKey,
              onFocusChange: (v) => setState(() => _dialFocused = v),
              child: Semantics(
                label: 'Kadran: ${tuned?.name ?? ''}',
                child: RadioDial(stations: _list, index: _tuned, active: _dialFocused, height: dialHeight),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (phone)
            Text(
              'Kadranı kaydırarak istasyon değiştirin',
              style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
            )
          else
            const _Hints(),
          const SizedBox(height: 12),
          SoundWave(active: status == RadioStatus.playing, height: phone ? 32 : 28),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.favorites != null && tuned != null) ...[
                _ToggleIcon(
                  icon: RedoxIcons.favorites,
                  filled: fav,
                  onPressed: () => widget.favorites!.toggleRadio(tuned.number),
                ),
                const SizedBox(width: 16),
              ],
              IconActionButton(icon: RedoxIcons.previous, onPressed: () => _turnAndPlay(-1)),
              const SizedBox(width: 16),
              _PlayButton(playing: playing, onPressed: _ok),
              const SizedBox(width: 16),
              IconActionButton(icon: RedoxIcons.next, onPressed: () => _turnAndPlay(1)),
              if (!phone) ...[
                const SizedBox(width: 16),
                IconActionButton(icon: RedoxIcons.moreHorizontal, onPressed: _options),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Önceki/sonraki düğmesi: beklemeden çalar.
  void _turnAndPlay(int step) {
    if (_list.isEmpty) return;
    setState(() => _tuned = (_tuned + step) % _list.length);
    _playTuned();
  }
}

/// Tuş ipuçları (TV): ◄ ► istasyon, OK duraklat, ▲ liste, ▼ düğmeler. Oklar
/// SVG ikondur: Sora'da ok karakterleri yok (kutu çiziliyordu).
class _Hints extends StatelessWidget {
  const _Hints();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget cap(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: RedoxRoles.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(RedoxRadius.xs),
      ),
      child: child,
    );
    Widget arrows(List<RedoxIcons> icons) => cap(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final i in icons) RedoxIcon(i, color: RedoxRoles.onSurface, size: 16)],
      ),
    );
    Widget hint(Widget key, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        key,
        const SizedBox(width: 6),
        Text(label, style: t.labelMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: RedoxRoles.surfaceContainer,
        borderRadius: BorderRadius.circular(RedoxRadius.full),
      ),
      child: Wrap(
        spacing: 20,
        children: [
          hint(arrows(const [RedoxIcons.chevronLeft, RedoxIcons.chevronRight]), 'İstasyon'),
          hint(const KeyHint('OK', color: RedoxRoles.onSurface), 'Duraklat'),
          hint(arrows(const [RedoxIcons.expandLess]), 'Liste'),
          hint(arrows(const [RedoxIcons.expandMore]), 'Düğmeler'),
        ],
      ),
    );
  }
}

/// Kızıl, büyük oynat/duraklat düğmesi.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  static const size = 64.0;

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      borderRadius: BorderRadius.circular(size / 2),
      builder: (context, active) => Material(
        color: active ? RedoxSeeds.amber : RedoxSeeds.crimson,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: RedoxIcon(
                playing ? RedoxIcons.pause : RedoxIcons.play,
                filled: true,
                size: 34,
                color: active ? RedoxSeeds.obsidian : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dolu/boş ikon düğmesi (favori yıldızı).
class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({required this.icon, required this.filled, required this.onPressed});

  final RedoxIcons icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final size = Theme.of(context).extension<RedoxMetrics>()!.iconButtonSize;
    return FocusGlow(
      borderRadius: BorderRadius.circular(size / 2),
      builder: (context, active) => Material(
        color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
        shape: CircleBorder(side: active ? BorderSide.none : const BorderSide(color: RedoxAccent.glassBorder)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Semantics(
            button: true,
            toggled: filled,
            label: filled ? 'Favorilerden çıkar' : 'Favorilere ekle',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: RedoxIcon(
                  icon,
                  filled: filled,
                  color: active ? RedoxSeeds.obsidian : (filled ? RedoxSeeds.crimson : RedoxRoles.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
