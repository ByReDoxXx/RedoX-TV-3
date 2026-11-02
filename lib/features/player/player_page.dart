import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/app_settings.dart';
import '../../core/content/live_channel.dart';
import '../../core/layout/form_factor.dart';
import '../../core/platform/device_controls.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/playback/engine/media_kit_engine.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../../core/playback/playback_session.dart';
import '../../core/playback/stream_probe.dart';
import 'widgets/channel_drawer.dart';
import 'widgets/player_bar.dart';
import 'widgets/player_options.dart';
import 'widgets/player_overlays.dart';
import 'widgets/touch_controls.dart';

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
    this.rank,
    this.onWatched,
    this.resolve,
  });

  final List<LiveChannel> channels;
  final int initialIndex;
  final String clock;

  /// Testlerde sahte motor; null ise media_kit.
  final PlaybackEngine Function()? engineFactory;

  /// Akış sıralayıcı (StreamProbe.rank); null ise listedeki sıra.
  final StreamRanker? rank;

  /// Kanal görüntü verince (izleme geçmişi): kanal başına bir kez, kanal
  /// değişince yeniden.
  final ValueChanged<LiveChannel>? onWatched;

  /// Açmadan önce adres çözücü (STB portalı); null ise adres olduğu gibi.
  final Future<String> Function(String url)? resolve;

  static Route<void> route({
    required List<LiveChannel> channels,
    required int initialIndex,
    required String clock,
    PlaybackEngine Function()? engineFactory,
    StreamRanker? rank,
    ValueChanged<LiveChannel>? onWatched,
    Future<String> Function(String url)? resolve,
  }) => MaterialPageRoute(
    builder: (_) => PlayerPage(
      channels: channels,
      initialIndex: initialIndex,
      clock: clock,
      engineFactory: engineFactory,
      rank: rank,
      onWatched: onWatched,
      resolve: resolve,
    ),
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

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final PlaybackEngine _engine = (widget.engineFactory ?? MediaKitEngine.new)();
  late final PlaybackSession _session = PlaybackSession(
    engine: _engine,
    channels: widget.channels,
    initialIndex: widget.initialIndex,
    rank: widget.rank,
    resolve: widget.resolve,
    failover: AppSettings.instance.failover,
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

  final bool _gestures = AppSettings.instance.gestures;

  /// Telefonda oynatıcı yatayda (biçim FormFactor.current: tema henüz yok).
  final bool _landscape = AppSettings.instance.landscapePlayer && FormFactor.current == FormFactor.phone;

  /// Açılışta Ayarlar › Oynatıcı › Görüntü ölçeği.
  VideoScale _scale = VideoScale.values.byName(AppSettings.instance.scale.name);
  int _shownIndex = -1;

  /// Geçmişe en son yazılan kanal (aynı kanal tekrar yazılmasın).
  int? _watched;
  int _shownStream = -1;

  Timer? _barTimer;
  Timer? _digitTimer;
  Timer? _noticeTimer;

  bool get _keys => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ayarlar › Telefonda yatay oynatıcı: telefon çevrilince görüntü yüzeyi
    // yeniden kurulup donuyordu (Pixel'de görüldü); oynatıcı yatayda kalır.
    if (_landscape) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    _session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    // Jestle değişen parlaklık oynatıcıyla sınırlı: sistemin değerine dön
    // (değişmediyse etkisiz; dispose'da tema okunamaz, biçime bakılmaz).
    unawaited(DeviceControls.setBrightness(null));
    WidgetsBinding.instance.removeObserver(this);
    if (_landscape) unawaited(SystemChrome.setPreferredOrientations(const []));
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

  /// Ayarlar › Arka planda ses kapalıysa: uygulamadan çıkınca ya da ekran
  /// kapanınca yayın duraklar, dönünce sürer.
  bool _pausedInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (AppSettings.instance.backgroundAudio) return;
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden when _engine.state.value.playing:
        _pausedInBackground = true;
        unawaited(_engine.playOrPause());
      case AppLifecycleState.resumed when _pausedInBackground:
        _pausedInBackground = false;
        unawaited(_engine.playOrPause());
      default:
        break;
    }
  }

  /// Kanal veya akış değişince çubuğu ve ipuçlarını kısa süre göster.
  void _onSession() {
    if (!mounted) return;
    if (_session.status == PlaybackStatus.playing && _session.channel.number != _watched) {
      _watched = _session.channel.number;
      widget.onWatched?.call(_session.channel);
    }
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
    if (_options || _drawer || (_bar && !_hints)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Açılamadı: ◄► ve OK ekrandaki "Tekrar dene" / "Sonraki kanal"
    // düğmelerinindir; ▲▼ ve rakamlar yine kanal değiştirir (yoksa kullanıcı
    // açılmayan kanalda kalıyordu).
    final zapKey =
        _digitKeys.containsKey(key) ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown;
    if (_session.status == PlaybackStatus.failed && !zapKey) return KeyEventResult.ignored;
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
    } else if (key == LogicalKeyboardKey.contextMenu) {
      // Menü (telefon kumandası, klavye): Seçenekler.
      _openOptions();
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

  void _setScale(VideoScale v) {
    setState(() => _scale = v);
    _notify(v.label);
  }

  /// [closable]: dokunmatikte panelde "Kapat" satırı (kumandada Geri kapatır).
  Widget _optionsPanel(EngineState e, PlaybackSession s, {bool closable = false}) => FocusScope(
    child: PlayerOptions(
      key: _optionsKey,
      onClose: closable ? _closeOptions : null,
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
  );

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: ValueListenableBuilder<EngineState>(
              valueListenable: _engine.state,
              builder: (context, e, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (_keys)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _bar ? _hideBar() : _showBar(),
                      child: _engine.view(fit: _scale.fit),
                    )
                  else
                    PlayerGestures(
                      onTap: () => _bar ? _hideBar() : _showBar(),
                      // Ayarlar › Dokunma hareketleri kapalıysa yalnız dokunma.
                      onDoubleTap: !_gestures
                          ? null
                          : () => _setScale(_scale == VideoScale.fill ? VideoScale.original : VideoScale.fill),
                      onPinch: !_gestures
                          ? null
                          : (bigger) => _setScale(bigger ? VideoScale.fill : VideoScale.original),
                      onZap: _gestures ? s.zap : null,
                      adjust: _gestures,
                      child: _engine.view(fit: _scale.fit),
                    ),
                  if (s.status != PlaybackStatus.playing) PlayerStatus(session: s),
                  if (_bar && !_keys)
                    TouchControls(
                      channel: s.channel,
                      playing: e.playing,
                      showCenter: s.status == PlaybackStatus.playing,
                      resolution: e.hasVideo ? '${e.height}p' : null,
                      streamIndex: s.streamIndex,
                      streamCount: s.streamCount,
                      scaleLabel: _scale.label,
                      clock: widget.clock,
                      onClose: () => Navigator.of(context).pop(),
                      onPlayPause: () {
                        _restartBarTimer();
                        unawaited(_engine.playOrPause());
                      },
                      onPreviousChannel: () => s.zap(-1),
                      onNextChannel: () => s.zap(1),
                      onChannelList: _openDrawer,
                      onNextStream: s.nextStream,
                      onScale: () => _setScale(VideoScale.values[(_scale.index + 1) % VideoScale.values.length]),
                      onOptions: _openOptions,
                    ),
                  // Dokunmatikte panelin dışına dokunmak Seçenekler'i kapatır
                  // (önceden kapatacak yer yoktu).
                  if (_bar && !_keys && _options)
                    Positioned.fill(
                      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeOptions),
                    ),
                  if (_bar && !_keys && _options)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: SafeArea(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                            maxWidth: math.min(360, MediaQuery.sizeOf(context).width - 32),
                          ),
                          child: _optionsPanel(e, s, closable: true),
                        ),
                      ),
                    ),
                  if (_bar && _keys) ...[
                    Positioned(top: 16, right: 24, child: PlayerClock(widget.clock)),
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
                                  child: _optionsPanel(e, s),
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
                  if (_digits.isNotEmpty) Positioned(top: 24, left: 24, child: PlayerDigits(_digits)),
                  if (_notice != null)
                    Positioned(top: 24, left: 0, right: 0, child: Center(child: PlayerNotice(_notice!))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
