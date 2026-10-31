import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/theme/redox_colors.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/theme/redox_shapes.dart';
import '../../core/theme/redox_type.dart';
import '../../core/ui/redox_buttons.dart';
import '../../core/ui/redox_icon.dart';
import 'engine/media_kit_engine.dart';
import 'engine/playback_engine.dart';
import 'playback_session.dart';
import 'widgets/channel_drawer.dart';
import 'widgets/player_bar.dart';
import 'widgets/player_options.dart';

/// Tam ekran oynatıcı (eski sürümün özellikleriyle). Kumanda:
/// - OK: alt çubuğu açar, odak oynat/duraklatta.
/// - ▲ / ▼ (ve Kanal +/-): sonraki / önceki kanal.
/// - ◄: hızlı kanal listesi. ►: sonraki akış.
/// - 0-9: kanal numarası (1,5 sn sonra açılır); tek başına 0: önceki kanal.
/// - Geri: açık menüyü, listeyi, çubuğu kapatır; hiçbiri açık değilse çıkar.
/// Kanal değişince çubuk ve ipuçları 3,8 sn görünür (eski sürümdeki gibi).
/// Dokunmatikte videoya dokunmak çubuğu açıp kapatır.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.channels,
    required this.initialIndex,
    required this.clock,
    this.engineFactory,
  });

  final List<LiveChannel> channels;
  final int initialIndex;
  final String clock;

  /// Testlerde sahte motor; null ise media_kit.
  final PlaybackEngine Function()? engineFactory;

  static Route<void> route({
    required List<LiveChannel> channels,
    required int initialIndex,
    required String clock,
    PlaybackEngine Function()? engineFactory,
  }) => MaterialPageRoute(
    builder: (_) =>
        PlayerPage(channels: channels, initialIndex: initialIndex, clock: clock, engineFactory: engineFactory),
  );

  /// Kanal değişince çubuğun ve ipuçlarının görünme süresi.
  static const announceDuration = Duration(milliseconds: 3800);

  /// OK ile açılan çubuk, son tuştan bu kadar sonra kapanır.
  static const barTimeout = Duration(seconds: 6);

  /// Numara girişi son rakamdan bu kadar sonra uygulanır.
  static const digitTimeout = Duration(milliseconds: 1500);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlaybackEngine _engine = (widget.engineFactory ?? MediaKitEngine.new)();
  late final PlaybackSession _session = PlaybackSession(
    engine: _engine,
    channels: widget.channels,
    initialIndex: widget.initialIndex,
  );

  final _rootFocus = FocusNode(debugLabel: 'oynatıcı');
  final _playFocus = FocusNode(debugLabel: 'oynat/duraklat');
  final _optionsKey = GlobalKey<PlayerOptionsState>();

  bool _bar = false;
  bool _hints = false;
  bool _options = false;
  bool _drawer = false;
  String _digits = '';
  String? _notice;
  VideoScale _scale = VideoScale.original;
  int _shownIndex = -1;
  int _shownStream = -1;

  Timer? _barTimer;
  Timer? _digitTimer;
  Timer? _noticeTimer;

  bool get _keys => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    _barTimer?.cancel();
    _digitTimer?.cancel();
    _noticeTimer?.cancel();
    _session.removeListener(_onSession);
    _session.dispose();
    unawaited(_engine.dispose());
    _rootFocus.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  /// Kanal veya akış değişince çubuğu ve ipuçlarını kısa süre göster.
  void _onSession() {
    if (!mounted) return;
    if (_session.index != _shownIndex || _session.streamIndex != _shownStream) {
      _shownIndex = _session.index;
      _shownStream = _session.streamIndex;
      if (!_options && !_drawer) {
        setState(() {
          _bar = true;
          _hints = _keys;
        });
        _restartBarTimer(PlayerPage.announceDuration);
      }
    }
    setState(() {});
  }

  void _restartBarTimer([Duration duration = PlayerPage.barTimeout]) {
    _barTimer?.cancel();
    _barTimer = Timer(duration, () {
      if (mounted && !_options && !_drawer) _hideBar();
    });
  }

  void _showBar({bool focus = false}) {
    setState(() {
      _bar = true;
      _hints = false;
    });
    if (focus) WidgetsBinding.instance.addPostFrameCallback((_) => _playFocus.requestFocus());
    _restartBarTimer();
  }

  void _hideBar() {
    setState(() {
      _bar = false;
      _hints = false;
    });
    _rootFocus.requestFocus();
  }

  void _openDrawer() {
    _barTimer?.cancel();
    setState(() {
      _drawer = true;
      _bar = false;
      _hints = false;
    });
  }

  void _closeDrawer() {
    setState(() => _drawer = false);
    _rootFocus.requestFocus();
  }

  void _openOptions() {
    _barTimer?.cancel();
    setState(() {
      _options = true;
      _bar = true;
      _hints = false;
    });
  }

  void _closeOptions() {
    setState(() => _options = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playFocus.requestFocus());
    _restartBarTimer();
  }

  void _notify(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _digit(int n) {
    if (_digits.isEmpty && n == 0) {
      if (!_session.openPrevious()) _notify('Önceki kanal yok');
      return;
    }
    _digitTimer?.cancel();
    setState(() => _digits = '$_digits$n'.substring(_digits.length >= 4 ? 1 : 0));
    _digitTimer = Timer(PlayerPage.digitTimeout, () {
      final number = int.parse(_digits);
      setState(() => _digits = '');
      if (!_session.openNumber(number)) _notify('$number numaralı kanal yok');
    });
  }

  static final _digitKeys = {
    for (var n = 0; n <= 9; n++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + n): n,
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + n): n,
    },
  };

  /// Hiçbir katman açık değilken kumanda tuşları. Katman açıkken tuşlar
  /// odak gezintisine bırakılır (çubuk, menü, liste düğmeleri).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_bar && !_hints) _restartBarTimer();
    if (_options || _drawer || (_bar && !_hints) || _session.status == PlaybackStatus.failed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event is KeyRepeatEvent && key != LogicalKeyboardKey.arrowUp && key != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.handled;
    }
    final digit = _digitKeys[key];
    if (digit != null) {
      _digit(digit);
    } else if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _showBar(focus: true);
    } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) {
      _session.zap(1);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      _session.zap(-1);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _openDrawer();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _session.nextStream();
    } else if (key == LogicalKeyboardKey.mediaPlayPause || key == LogicalKeyboardKey.space) {
      unawaited(_engine.playOrPause());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Geri: en üstteki katmanı kapatır; hiçbiri yoksa oynatıcıdan çıkar.
  void _back() {
    if (_options) {
      if (_optionsKey.currentState?.handleBack() ?? false) return;
      _closeOptions();
    } else if (_drawer) {
      _closeDrawer();
    } else if (_digits.isNotEmpty) {
      _digitTimer?.cancel();
      setState(() => _digits = '');
    } else if (_bar) {
      _barTimer?.cancel();
      _hideBar();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context)},
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Scaffold(
            backgroundColor: RedoxSeeds.obsidian,
            body: ValueListenableBuilder<EngineState>(
              valueListenable: _engine.state,
              builder: (context, e, _) => Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _bar ? _hideBar() : _showBar(),
                    child: _engine.view(fit: _scale.fit),
                  ),
                  if (s.status != PlaybackStatus.playing) _Status(session: s),
                  if (_bar) ...[
                    Positioned(top: 16, right: 24, child: _Clock(widget.clock)),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_options) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                                  child: FocusScope(
                                    child: PlayerOptions(
                                      key: _optionsKey,
                                      engine: e,
                                      scale: _scale,
                                      onScale: (v) => setState(() => _scale = v),
                                      streamLabel: 'Akış ${s.streamIndex + 1}/${s.streamCount}',
                                      onVideoTrack: (id) => unawaited(_engine.selectVideoTrack(id)),
                                      onAudioTrack: (id) => unawaited(_engine.selectAudioTrack(id)),
                                      onSubtitleTrack: (id) => unawaited(_engine.selectSubtitleTrack(id)),
                                      previousChannelName: s.previousChannel?.name,
                                      onPreviousChannel: () {
                                        _closeOptions();
                                        s.openPrevious();
                                      },
                                      onExit: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_hints) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: PlayerHints(multiStream: s.streamCount > 1),
                              ),
                              const SizedBox(height: 10),
                            ],
                            PlayerBar(
                              channel: s.channel,
                              playing: e.playing,
                              resolution: e.hasVideo ? '${e.height}p' : null,
                              streamIndex: s.streamIndex,
                              streamCount: s.streamCount,
                              playFocusNode: _playFocus,
                              onPlayPause: () => unawaited(_engine.playOrPause()),
                              onPreviousChannel: () => s.zap(-1),
                              onNextChannel: () => s.zap(1),
                              onChannelList: _openDrawer,
                              onNextStream: s.nextStream,
                              onOptions: _openOptions,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_drawer)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: FocusScope(
                        child: ChannelDrawer(
                          channels: s.channels,
                          currentIndex: s.index,
                          onSelect: (i) {
                            _closeDrawer();
                            s.openAt(i);
                          },
                        ),
                      ),
                    ),
                  if (_digits.isNotEmpty) Positioned(top: 24, left: 24, child: _Digits(_digits)),
                  if (_notice != null) Positioned(top: 24, left: 0, right: 0, child: Center(child: _Notice(_notice!))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yükleniyor / açılamadı durumu (görüntünün üstünde ortada).
class _Status extends StatelessWidget {
  const _Status({required this.session});

  final PlaybackSession session;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = session;
    final stream = s.streamCount > 0 ? ' · Akış ${s.streamIndex + 1}/${s.streamCount}' : '';
    if (s.status == PlaybackStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 40,
              child: CircularProgressIndicator(color: RedoxRoles.primaryContainer, strokeWidth: 3),
            ),
            const SizedBox(height: 12),
            Text('Yükleniyor$stream', style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant)),
          ],
        ),
      );
    }
    // Açılamadı: odak "Tekrar dene"de (yeni odak alanı, kendiliğinden odak).
    return Center(
      child: FocusScope(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: RedoxRoles.surfaceContainer,
            borderRadius: BorderRadius.circular(RedoxRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${s.channel.name} açılamadı',
                textAlign: TextAlign.center,
                style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                s.streamCount == 0 ? 'Bu kanalın yayın adresi yok.' : 'Bütün akışlar denendi, yanıt gelmedi.',
                textAlign: TextAlign.center,
                style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryButton(label: 'Tekrar dene', icon: RedoxIcons.sync, autofocus: true, onPressed: s.retry),
                  GlassButton(label: 'Sonraki kanal', icon: RedoxIcons.next, onPressed: () => s.zap(1)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Clock extends StatelessWidget {
  const _Clock(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(RedoxRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RedoxIcon(RedoxIcons.clock, color: RedoxRoles.tertiary, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface, fontFeatures: RedoxType.tabular),
        ),
      ],
    ),
  );
}

/// Girilen kanal numarası (sol üstte, büyük).
class _Digits extends StatelessWidget {
  const _Digits(this.digits);

  final String digits;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerLowest.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(RedoxRadius.md),
      border: Border.all(color: RedoxRoles.tertiary, width: 2),
    ),
    child: Text(
      digits,
      style: Theme.of(context).textTheme.headlineMedium!
          .copyWith(color: RedoxRoles.tertiary, fontWeight: FontWeight.w800, fontFeatures: RedoxType.tabular),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: RedoxRoles.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(RedoxRadius.full),
    ),
    child: Text(text, style: RedoxType.labelLg.copyWith(color: RedoxRoles.onSurface)),
  );
}
