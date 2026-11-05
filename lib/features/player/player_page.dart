import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/content/app_settings.dart';
import '../../core/content/channel_folder.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/tmdb.dart';
import '../../core/content/diagnostics.dart';
import '../../core/content/watch_progress.dart';
import '../../core/layout/form_factor.dart';
import '../../core/platform/device_controls.dart';
import '../../core/platform/full_screen.dart';
import '../../core/platform/picture_in_picture.dart';
import '../../core/theme/redox_metrics.dart';
import '../../core/playback/engine/media_kit_engine.dart';
import '../../core/playback/engine/playback_engine.dart';
import '../../core/playback/playback_session.dart';
import '../../core/playback/sleep_timer.dart';
import '../../core/playback/stream_probe.dart';
import 'player_keys.dart';
import 'vod_progress.dart';
import 'widgets/channel_drawer.dart';
import 'widgets/player_bar.dart';
import 'widgets/player_layers.dart';
import 'widgets/player_options.dart';
import 'widgets/player_overlays.dart';
import 'widgets/seek_bar.dart';
import 'widgets/touch_controls.dart';
import 'widgets/vod_title.dart';
import 'widgets/vod_tv.dart';

export 'player_keys.dart' show PlayerMode;

/// Tam ekran oynatıcı (eski sürümün özellikleriyle). Kumanda:
/// - OK: alt çubuğu açar, odak oynat/duraklatta.
/// - ▲ / ▼ (ve Kanal +/-): sonraki / önceki kanal; dizide ▲ bölüm şeridi.
/// - ◄: hızlı kanal listesi. ►: sonraki akış.
/// - 0-9: kanal numarası (1,5 sn sonra açılır); tek başına 0: önceki kanal.
/// Telefon/tablette Ana ekrana çıkınca resim içinde resim (yalnız görüntü).
/// Seçenekler'de uyku zamanlayıcı (süre dolunca yayın durur, oynatıcı
/// kapanır; son dakikada uyarı) ve yayın bilgisi paneli.
/// - Geri: açık menüyü, listeyi, çubuğu kapatır; hiçbiri açık değilse çıkar.
/// Kanal değişince çubuk ve ipuçları 3,8 sn görünür (eski sürümdeki gibi).
/// Dokunmatikte videoya dokunmak çubuğu açıp kapatır.
/// Oynatılan içerik: [PlayerMode]. Kumanda kuralları [PlayerKeys]'te, izlenen
/// yer [VodProgress]'te, ekran katmanları widgets/player_layers.dart'ta.
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
    this.mode = PlayerMode.live,
    this.progress,
    this.tmdb,
    this.onStuck,
    this.reopened = false,
  });

  /// Oynatıcı çekirdeği takıldı; verilen dizinle yeniden açılabilir. null ise
  /// "açılamadı" ekranında kalır. [route] verir.
  final ValueChanged<int>? onStuck;

  /// Bu sayfa takılan oynatıcının yerine açıldı: ekranda belirtilir.
  final bool reopened;

  final PlayerMode mode;

  /// Film/dizi bilgisi (TV'de duraklatınca afiş ve özet); null ise yalnız ad.
  final Tmdb? tmdb;

  /// Film/dizi: kaldığı yerden devam (yazılır ve okunur); null ise yok.
  final WatchProgress? progress;

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
    PlayerMode mode = PlayerMode.live,
    WatchProgress? progress,
    Tmdb? tmdb,
  }) => MaterialPageRoute(
    builder: (_) => _ReopeningPlayer(
      initialIndex: initialIndex,
      builder: (index, onStuck, {required reopened}) => PlayerPage(
        channels: channels,
        initialIndex: index,
        clock: clock,
        engineFactory: engineFactory,
        rank: rank,
        onWatched: onWatched,
        resolve: resolve,
        mode: mode,
        progress: progress,
        tmdb: tmdb,
        onStuck: onStuck,
        reopened: reopened,
      ),
    ),
  );

  /// Takılan oynatıcı en çok bu kadar yeniden açılır: her biri bir çözücü tutar.
  static const maxReopens = 2;

  /// Kanal değişince çubuğun ve ipuçlarının görünme süresi.
  static const announceDuration = Duration(milliseconds: 3800);

  /// OK ile açılan çubuk, son tuştan bu kadar sonra kapanır.
  static const barTimeout = Duration(seconds: 6);

  /// Numara girişi son rakamdan bu kadar sonra uygulanır.
  static const digitTimeout = Duration(milliseconds: 1500);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

/// Takılan oynatıcının yerine aynı rotada yenisini açar (yeni anahtar: yeni motor,
/// film kaldığı yerden sürer). Rota kapanmaz: açan sayfa oynatıcı bitti sanıp kare
/// almaya başlamasın.
class _ReopeningPlayer extends StatefulWidget {
  const _ReopeningPlayer({required this.initialIndex, required this.builder});

  final int initialIndex;
  final PlayerPage Function(int index, ValueChanged<int>? onStuck, {required bool reopened}) builder;

  @override
  State<_ReopeningPlayer> createState() => _ReopeningPlayerState();
}

class _ReopeningPlayerState extends State<_ReopeningPlayer> {
  late int _index = widget.initialIndex;
  int _reopens = 0;

  void _reopen(int index) {
    if (!mounted) return;
    Diagnostics.instance.log('oynatıcı', 'takılan oynatıcının yerine yenisi açılıyor');
    setState(() {
      _index = index;
      _reopens++;
    });
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey(_reopens),
    child: widget.builder(_index, _reopens < PlayerPage.maxReopens ? _reopen : null, reopened: _reopens > 0),
  );
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

  /// Kumanda tuşlarını alan kök. Yön gezintisinde aday değildir: bütün
  /// ekranı kapladığı için çubukta sağa basınca odak Seçenekler yerine köke
  /// kaçıyordu (Chromecast: "seçeneklere gelemiyorum").
  final _rootFocus = FocusNode(debugLabel: 'oynatıcı', skipTraversal: true);
  final _playFocus = FocusNode(debugLabel: 'oynat/duraklat');
  final _optionsKey = GlobalKey<PlayerOptionsState>();

  bool _bar = false;
  bool _hints = false;
  bool _options = false;
  bool _drawer = false;
  bool _stats = false;
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

  /// Uyku zamanlayıcı: süre dolunca oynatıcı kapanır.
  late final _sleep = SleepTimer(_onSleep);
  Timer? _sleepWarning;

  bool get _keys => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.tv;

  /// Masaüstü: çubuk açıkken de tuşlar oynatıcınındır (çubuk fareyle kullanılır).
  bool get _desktop => Theme.of(context).extension<RedoxMetrics>()!.formFactor == FormFactor.desktop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(FullScreen.enter());
    if (_vod) {
      _progress = VodProgress(
        engine: _engine,
        session: () => _session,
        store: widget.progress,
        series: widget.mode == PlayerMode.series,
        onResumed: (at) => _notify('Kaldığın yerden: ${SeekBar.format(at)}'),
      )..start();
    }
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
    if (widget.reopened) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notify('Oynatıcı takıldı, yeniden açıldı', duration: const Duration(seconds: 5));
      });
    }
    _audioFallbacks = _engine.audioFallbacks.listen(_onAudioFallback);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
    // Telefon/tablet: Ana ekrana çıkınca yayın küçük pencerede sürer.
    if (_pip) unawaited(PictureInPicture.setEnabled(true));
  }

  /// Resim içinde resim (TV'de yok).
  final bool _pip = FormFactor.current != FormFactor.tv;

  @override
  void dispose() {
    // Jestle değişen parlaklık oynatıcıyla sınırlı: sistemin değerine dön
    // (değişmediyse etkisiz; dispose'da tema okunamaz, biçime bakılmaz).
    unawaited(DeviceControls.setBrightness(null));
    if (_pip) unawaited(PictureInPicture.setEnabled(false));
    WidgetsBinding.instance.removeObserver(this);
    unawaited(FullScreen.leave());
    _progress?.stop();
    if (_landscape) unawaited(SystemChrome.setPreferredOrientations(const []));
    _barTimer?.cancel();
    _digitTimer?.cancel();
    _noticeTimer?.cancel();
    _seekTimer?.cancel();
    _sleep.cancel();
    _sleepWarning?.cancel();
    unawaited(_audioFallbacks.cancel());
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

  bool get _vod => widget.mode != PlayerMode.live;

  /// Film/dizide izlenen yer; canlı yayında null.
  VodProgress? _progress;

  /// Seçenekler › Uyku zamanlayıcı: sıradaki süre.
  void _cycleSleep() {
    final minutes = SleepTimer.next(_sleep.left);
    _sleep.set(minutes);
    _sleepWarning?.cancel();
    if (minutes != null) {
      _sleepWarning = Timer(Duration(minutes: minutes - 1), () {
        if (mounted) _notify('Oynatıcı 1 dk sonra kapanacak');
      });
    }
    setState(() {});
    _notify(minutes == null ? 'Uyku zamanlayıcı kapalı' : '$minutes dk sonra kapanacak');
  }

  void _onSleep() {
    if (!mounted) return;
    if (_engine.state.value.playing) unawaited(_engine.playOrPause());
    Navigator.of(context).pop();
  }

  /// Baştan izle (Seçenekler).
  void _restart() {
    unawaited(_engine.seek(Duration.zero));
    _notify('Baştan başlatıldı');
  }

  /// Dizide sıradaki bölümün kısa adı ("S2 · B4"); filmde ya da son bölümde null.
  String? _nextLabel(PlaybackSession s) {
    if (widget.mode != PlayerMode.series || s.index + 1 >= s.channels.length) return null;
    final next = s.channels[s.index + 1];
    final e = ChannelFolder.parseEpisode(next.name);
    return e == null ? next.name : 'S${e.season} · B${e.episode}';
  }

  Widget? _vodSeekBar(EngineState e) => e.seekable
      ? SeekBar(
          position: _engine.position,
          duration: e.duration,
          onSeek: (to) {
            _restartBarTimer();
            unawaited(_engine.seek(to));
          },
          onDragging: (dragging) => dragging ? _barTimer?.cancel() : _restartBarTimer(),
        )
      : null;

  Widget _vodTouch(EngineState e, PlaybackSession s) {
    final t = vodTitle(s.channel, series: widget.mode == PlayerMode.series);
    return VodTouchControls(
      title: t.title,
      subtitle: t.subtitle,
      playing: e.playing,
      showCenter: s.status == PlaybackStatus.playing,
      seekBar: _vodSeekBar(e),
      scaleLabel: _scale.label,
      resolution: e.hasVideo ? '${e.height}p' : null,
      nextLabel: _nextLabel(s),
      onClose: () => Navigator.of(context).pop(),
      onPlayPause: () {
        _restartBarTimer();
        unawaited(_engine.playOrPause());
      },
      onSeekBy: e.seekable ? _seekBy : null,
      onNext: () => s.zap(1),
      onScale: () => _setScale(VideoScale.values[(_scale.index + 1) % VideoScale.values.length]),
      onOptions: _openOptions,
    );
  }

  Widget _vodBar(EngineState e, PlaybackSession s) {
    return VodBar(
      playing: e.playing,
      seekBar: e.seekable ? SeekBar(position: _engine.position, duration: e.duration, remaining: true) : null,
      playFocusNode: _playFocus,
      resolution: e.hasVideo ? '${e.height}p' : null,
      nextLabel: _nextLabel(s),
      onPlayPause: () => unawaited(_engine.playOrPause()),
      onSeekBy: e.seekable ? _seekBy : null,
      onNext: () => s.zap(1),
      onOptions: _openOptions,
    );
  }

  /// Film/dizi: 10 sn ileri (+1) ya da geri (-1) sar.
  void _seekBy(int direction) {
    if (_bar) _restartBarTimer();
    unawaited(_engine.seek(_engine.position.value + PlayerGestures.seekStep * direction));
  }

  /// TV: ◄► ile sarılırken altta kısa süre sarma çubuğu.
  bool _seekShown = false;
  Timer? _seekTimer;

  void _keySeek(int direction) {
    _seekBy(direction);
    _seekTimer?.cancel();
    setState(() => _seekShown = true);
    _seekTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _seekShown = false);
    });
  }

  /// Kanal veya akış değişince çubuğu ve ipuçlarını kısa süre göster.
  bool _reopening = false;

  void _onSession() {
    if (!mounted) return;
    if (_engine.state.value.stuck && !_reopening && widget.onStuck != null) {
      _reopening = true;
      widget.onStuck!(_session.index);
      return;
    }
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
          _hints = _keys && !_vod;
        });
        _restartBarTimer(PlayerPage.announceDuration);
      }
    }
    setState(() {});
  }

  void _restartBarTimer([Duration duration = PlayerPage.barTimeout]) {
    _barTimer?.cancel();
    _barTimer = Timer(duration, () {
      if (mounted && !_options && !_drawer && !_episodes) _hideBar();
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

  /// Dizi (TV): ▲ ile bölüm şeridi; çubuk açık kalır.
  bool _episodes = false;

  void _openEpisodes() {
    _barTimer?.cancel();
    setState(() {
      _episodes = true;
      _bar = true;
      _hints = false;
    });
  }

  void _closeEpisodes() {
    setState(() => _episodes = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _playFocus.requestFocus());
    _restartBarTimer();
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

  late final StreamSubscription<AudioFallback> _audioFallbacks;

  void _onAudioFallback(AudioFallback f) {
    if (!mounted) return;
    final to = f.to;
    _notify(
      to == null ? 'Bu dosyanın sesi çözülemiyor' : 'Ses çözülemedi, “${to.label}” izine geçildi',
      duration: const Duration(seconds: 5),
    );
  }

  void _notify(String text, {Duration duration = const Duration(seconds: 2)}) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(duration, () {
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

  /// Hiçbir katman açık değilken kumanda tuşları (kurallar: [PlayerKeys]).
  /// Bölüm şeridinde tuşlar şeridin (◄► gezinme, OK, ▼ kapatır).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _episodes) return KeyEventResult.ignored;
    final action = PlayerKeys.resolve(
      PlayerKeyState(
        mode: widget.mode,
        tv: _keys,
        desktop: _desktop,
        options: _options,
        drawer: _drawer,
        bar: _bar,
        hints: _hints,
        rootFocused: node.hasPrimaryFocus,
        failed: _session.status == PlaybackStatus.failed,
        seekable: _engine.state.value.seekable,
      ),
      event,
    );
    if (action != PlayerKeyAction.openEpisodes && _bar && !_hints) _restartBarTimer();
    switch (action) {
      case PlayerKeyAction.ignore:
        return KeyEventResult.ignored;
      case PlayerKeyAction.consume:
        break;
      case PlayerKeyAction.openEpisodes:
        _openEpisodes();
      case PlayerKeyAction.focusPlay:
        _playFocus.requestFocus();
      case PlayerKeyAction.digit:
        _digit(PlayerKeys.digitOf(event.logicalKey)!);
      case PlayerKeyAction.showBar:
        _showBar(focus: true);
      case PlayerKeyAction.playPause:
        unawaited(_engine.playOrPause());
      case PlayerKeyAction.zapNext:
        _session.zap(1);
      case PlayerKeyAction.zapPrevious:
        _session.zap(-1);
      case PlayerKeyAction.seekBack:
        _keySeek(-1);
      case PlayerKeyAction.seekForward:
        _keySeek(1);
      case PlayerKeyAction.openDrawer:
        _openDrawer();
      case PlayerKeyAction.nextStream:
        _session.nextStream();
      case PlayerKeyAction.openOptions:
        _openOptions();
    }
    return KeyEventResult.handled;
  }

  /// Geri: en üstteki katmanı kapatır; hiçbiri yoksa oynatıcıdan çıkar.
  void _back() {
    if (_episodes) {
      _closeEpisodes();
    } else if (_options) {
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
      // Film/dizide "Önceki kanal" yerine "Baştan başla".
      previousChannelName: _vod ? null : s.previousChannel?.name,
      onRestart: _vod
          ? () {
              _closeOptions();
              _restart();
            }
          : null,
      onPreviousChannel: () {
        _closeOptions();
        s.openPrevious();
      },
      sleepLabel: SleepTimer.label(_sleep.left),
      onSleep: _cycleSleep,
      statsShown: _stats,
      onStats: () => setState(() => _stats = !_stats),
      onExit: () => Navigator.of(context).pop(),
    ),
  );

  @override
  Widget build(BuildContext context) {
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
            body: ListenableBuilder(
              listenable: Listenable.merge([_engine.state, PictureInPicture.active]),
              builder: (context, _) => _layers(context, _engine.state.value, PictureInPicture.active.value),
            ),
          ),
        ),
      ),
    );
  }

  /// Canlı yayın, dokunmatik denetimler.
  Widget _liveTouch(EngineState e, PlaybackSession s) => TouchControls(
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
    onSeekBy: e.seekable ? _seekBy : null,
    seekBar: _vodSeekBar(e),
  );

  /// Canlı yayın, TV çubuğu.
  Widget _liveBar(EngineState e, PlaybackSession s) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (e.seekable) ...[SeekBar(position: _engine.position, duration: e.duration), const SizedBox(height: 8)],
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
  );

  /// Görüntü: dokunma ve (dokunmatikte) hareketler.
  Widget _surface(EngineState e, PlaybackSession s) {
    void toggleBar() => _bar ? _hideBar() : _showBar();
    final view = _engine.view(fit: _scale.fit);
    if (_keys) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: toggleBar, child: view);
    }
    return PlayerGestures(
      onTap: toggleBar,
      // Ayarlar › Dokunma hareketleri kapalıysa yalnız dokunma.
      onDoubleTap: !_gestures
          ? null
          : () => _setScale(_scale == VideoScale.fill ? VideoScale.original : VideoScale.fill),
      onPinch: !_gestures ? null : (bigger) => _setScale(bigger ? VideoScale.fill : VideoScale.original),
      onZap: _gestures && widget.mode != PlayerMode.film ? s.zap : null,
      adjust: _gestures,
      // Film/dizi: sağa/sola çift dokunma ±10 sn.
      onSeekSide: _gestures && e.seekable ? _seekBy : null,
      child: view,
    );
  }

  /// Görüntü ve üstündeki katmanlar; küçük pencerede ([pip]) yalnız görüntü.
  Widget _layers(BuildContext context, EngineState e, bool pip) {
    final s = _session;
    return Stack(
      fit: StackFit.expand,
      children: [
        _surface(e, s),
        Visibility(
          visible: !pip,
          maintainState: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (s.status != PlaybackStatus.playing) PlayerStatus(session: s),
              if (_bar && !_keys) _vod ? _vodTouch(e, s) : _liveTouch(e, s),
              if (_bar && !_keys && _options)
                TouchOptionsLayer(panel: _optionsPanel(e, s, closable: true), onClose: _closeOptions),
              if (_keys && _seekShown && !_bar && e.seekable)
                TvSeekToast(
                  seekBar: SeekBar(position: _engine.position, duration: e.duration),
                ),
              if (_keys && _vod && s.status == PlaybackStatus.playing && (_bar || !e.playing))
                TvVodInfoLayer(
                  channel: s.channel,
                  series: widget.mode == PlayerMode.series,
                  tmdb: widget.tmdb,
                  playing: e.playing,
                ),
              if (_bar && _keys)
                TvPlayerPanel(
                  clock: widget.clock,
                  options: _options ? _optionsPanel(e, s) : null,
                  hints: _hints
                      ? PlayerHints(multiStream: s.streamCount > 1, previous: s.previousChannel != null)
                      : null,
                  episodes: _episodes
                      ? FocusScope(
                          child: EpisodeStrip(
                            episodes: s.channels,
                            current: s.index,
                            progress: widget.progress,
                            onClose: _closeEpisodes,
                            onSelect: (i) {
                              _closeEpisodes();
                              if (i != s.index) s.openAt(i);
                            },
                          ),
                        )
                      : null,
                  bar: _vod ? _vodBar(e, s) : _liveBar(e, s),
                ),
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
              if (_stats)
                Positioned(
                  top: _keys ? 64 : 72,
                  right: 24,
                  child: SafeArea(
                    child: PlayerStats(engine: _engine, stream: 'Akış ${s.streamIndex + 1}/${s.streamCount}'),
                  ),
                ),
              if (_digits.isNotEmpty) Positioned(top: 24, left: 24, child: PlayerDigits(_digits)),
              if (_notice != null) Positioned(top: 24, left: 0, right: 0, child: Center(child: PlayerNotice(_notice!))),
            ],
          ),
        ),
      ],
    );
  }
}
