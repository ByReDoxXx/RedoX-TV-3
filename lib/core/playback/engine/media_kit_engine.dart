import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../content/app_settings.dart';
import '../../content/diagnostics.dart';
import '../../layout/form_factor.dart';
import '../subtitle_look.dart';
import 'mpv_probe.dart';
import 'playback_engine.dart';

/// media_kit (libmpv) ile oynatma. Uygulama başında
/// `MediaKit.ensureInitialized()` çağrılmış olmalı (main.dart).
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() {
    // Görüntü denetleyicisi yayın açılmadan kurulur: donanım çözücü ve
    // kopyasız çıkış ayarı mpv'ye ilk yayından önce verilsin. Önceden ilk
    // çizimde kuruluyordu, yayın ondan önce açıldığı için telefonda 4K HEVC
    // bile yazılımla çözülüyordu (hwdec-current=no; Pixel'de görüldü).
    _video = VideoController(_player, configuration: _android ? _zeroCopy : const VideoControllerConfiguration());
    unawaited(_tune());
    if (_android) {
      unawaited(_watchSurface());
      _watchdog = EngineWatchdog(ping: _ping, onStuck: _markStuck)..start();
    }
    final s = _player.stream;
    _subscriptions.addAll([
      s.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
      s.buffering.listen((v) => _update(_state.value.copyWith(buffering: v))),
      s.width.listen((v) => unawaited(_onWidth(v))),
      s.height.listen((v) => _update(_state.value.copyWith(height: () => v))),
      s.duration.listen((v) => _update(_state.value.copyWith(duration: v))),
      s.position.listen((v) => _position.value = v),
      s.tracks.listen(_onTracks),
      s.track.listen(
        (t) => _update(
          _state.value.copyWith(videoTrack: t.video.id, audioTrack: t.audio.id, subtitleTrack: t.subtitle.id),
        ),
      ),
      s.error.listen((e) {
        if (!_transient(e)) _errors.add(e);
      }),
    ]);
  }

  final _player = Player();
  late final VideoController _video;
  EngineWatchdog? _watchdog;

  /// Oynatıcı çekirdeği yanıt vermiyor: ona dokunan her çağrı arayüzü
  /// dondurur, çağrılmaz (motor kapanırken de).
  bool _stuck = false;
  bool _disposed = false;

  /// Süren ayrı isolate okumaları: oynatıcı kapatılmadan biter (kapanmış
  /// oynatıcıyı okumak uygulamayı düşürür).
  final _reads = <Future<Object?>>{};

  /// Bilgi okumalarının süresi; takılı çekirdekte boşuna beklenmez.
  static const _readTimeout = Duration(seconds: 8);

  /// mpv özellikleri, arayüzü dondurmadan ([MpvProbe]). Okunamayan değer null;
  /// takılı ya da kapanmış oynatıcıda ve süre aşılınca boş.
  Future<Map<String, String?>> _read(List<String> names) async {
    if (_stuck || _disposed) return const {};
    if (!_android) {
      final native = _player.platform;
      if (native is! NativePlayer) return const {};
      return {
        for (final name in names)
          name: await native.getProperty(name).then<String?>((v) => v, onError: (Object _) => null),
      };
    }
    final handle = await _player.handle;
    if (_stuck || _disposed) return const {};
    final read = MpvProbe.read(library: 'libmpv.so', handle: handle, names: names);
    _reads.add(read);
    unawaited(read.then<void>((_) {}, onError: (Object _) {}).whenComplete(() => _reads.remove(read)));
    try {
      return await read.timeout(_readTimeout);
    } on TimeoutException {
      return const {};
    }
  }

  /// Bekçinin yoklaması: görüntü yokken (yayın açılırken) yoklanmaz.
  Future<void> _ping() async {
    if (_stuck || _disposed || !_state.value.hasVideo) return;
    final handle = await _player.handle;
    final read = MpvProbe.read(library: 'libmpv.so', handle: handle, names: const ['time-pos']);
    _reads.add(read);
    unawaited(read.then<void>((_) {}, onError: (Object _) {}).whenComplete(() => _reads.remove(read)));
    await read;
  }

  void _markStuck() {
    if (_stuck || _disposed) return;
    _stuck = true;
    Diagnostics.instance.log('görüntü', 'oynatıcı yanıt vermiyor (donanım çözücü takılmış olabilir)');
    _update(_state.value.copyWith(stuck: true));
  }

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// TV sürümü (zayıf kutu: kopyalı yol yalnız gerektiğinde).
  static bool get _tv => FormFactor.current == FormFactor.tv;

  /// Android'de donanım çözücü kareyi doğrudan yüzeye çizer (kopyasız).
  /// Varsayılan yol (vo=gpu, mediacodec-copy) her kareyi belleğe kopyalıyordu:
  /// Chromecast with Google TV'de 1080p/1440p yayınlar saniyede 5–8 kare
  /// atladı, görüntü 40 sn'de sesin 10–24 sn gerisine düştü ("kasma"; ölçüldü).
  /// Kopyasız yolda aynı kanallarda atlama 0, ses-görüntü farkı 0, işlemci yükü
  /// yarıya indi. Hafif ölçekleme (bilinear) ve 1080p sınırı denendi, etkisiz.
  static const _zeroCopy = VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec');

  /// Yayını düşürmeyen mpv iletileri: media_kit yüzey bağlanınca çözücüyü
  /// yeniden kurar ve oynatma konumuna atlar; canlı yayında atlama "Cannot
  /// seek" verir, kopyasız kipte ilk açılış "Could not open codec." verebilir.
  /// Bunlar hata sayılsaydı oturum çalışan akışı bırakıp yedeğe geçerdi.
  /// Gerçekten açılmayan akışı açılış süresi yakalar.
  static bool _transient(String e) =>
      e.contains('Cannot seek') || e.contains('force-seekable') || (_android && e.contains('Could not open codec'));

  /// Canlı yayında açılışı hızlandırır: ffmpeg yayın biçimini varsayılan 5 sn
  /// yerine 1 sn çözümler (IPTV akışlarında yeterli). Ağ beklemesi 10 sn.
  /// Ayarlar › Oynatıcı: ön bellek (ileriye okunan süre) ve tercih edilen ses
  /// ve altyazı dili (mpv alang/slang; altyazı "Kapalı" ise hiç seçilmez).
  Future<void> _tune() async {
    final native = _player.platform;
    if (native is! NativePlayer) return;
    await native.setProperty('demuxer-lavf-analyzeduration', '1');
    await native.setProperty('network-timeout', '10');
    final settings = AppSettings.instance;
    if (settings.buffer.seconds case final s?) {
      await native.setProperty('cache', 'yes');
      await native.setProperty('cache-secs', '$s');
      await native.setProperty('demuxer-readahead-secs', '$s');
    }
    if (settings.audio.codes.isNotEmpty) await native.setProperty('alang', settings.audio.codes);
    // Gece modu: ffmpeg acompressor (eşiğin üstünü 4'te bire sıkıştırır,
    // kazançla kısık sesleri yükseltir).
    if (settings.nightMode) {
      await native.setProperty('af', 'lavfi=[acompressor=threshold=0.125:ratio=4:attack=20:release=250:makeup=2]');
    }
    switch (settings.subtitles) {
      case TrackLanguage.off:
        await native.setProperty('sid', 'no');
      case final TrackLanguage l when l.codes.isNotEmpty:
        await native.setProperty('slang', l.codes);
      default:
        break;
    }
  }

  /// Yayının görüntü biçimi tanılama günlüğüne (yayın başına bir kez, ilk
  /// boyut gelince): kodek, çözücü, renk aktarımı (HDR: pq/hlg), renk uzayı
  /// ve Dolby Vision profili. Kopyasız yolda kareler mpv'den geçmediği için
  /// bilgiler parça listesinden ve çözücü parametrelerinden okunur. Renk
  /// sorunlarını (pembe/yeşil görüntü) ayırt etmek için.
  bool _videoLogged = false;

  Future<void> _logVideo(int? width) async {
    if (_videoLogged || (width ?? 0) == 0) return;
    _videoLogged = true;
    // Görüntü yüzeyi bağlanınca media_kit çıkışı ve çözücüyü yeniden kurar:
    // ölçüm ondan sonra.
    await Future<void>.delayed(const Duration(seconds: 6));
    const names = [
      'video-codec',
      'current-vo',
      'hwdec',
      'hwdec-current',
      'current-tracks/video/codec',
      'current-tracks/video/dolby-vision-profile',
      'video-dec-params/gamma',
      'video-dec-params/primaries',
      'video-dec-params/colormatrix',
      'video-dec-params/pixelformat',
      'video-params/gamma',
      'video-format',
      'file-format',
    ];
    final values = await _read(names);
    if (_disposed) return;
    final parts = [
      for (final name in names)
        '$name=${switch (values[name]) {
          null => '?',
          '' => '-',
          final v => v,
        }}',
    ];
    Diagnostics.instance.log('görüntü', '${width}p-genişlik ${parts.join(' ')}');
    unawaited(_logDrops());
  }

  /// İlk görüntü boyutu geldi. Android'de önce yayının HDR olup olmadığına
  /// bakılır; HDR ise yol SDR'ye çevrilir. "Görüntü geldi" (boyut) bundan
  /// sonra bildirilir: oynatıcı o ana kadar yükleniyor gösterir, pembe ilk
  /// kareler görünmez (önce 6 sn pembe kalıyordu).
  bool _hdrChecked = false;

  Future<void> _onWidth(int? width) async {
    if (_android && !_hdrChecked && (width ?? 0) > 0) {
      _hdrChecked = true;
      final native = _player.platform;
      if (native is NativePlayer) await _hdrToSdr();
    }
    _update(_state.value.copyWith(width: () => width));
    unawaited(_logVideo(width));
  }

  /// HDR yayında kopyasız yol pembe görüntü veriyordu (Pixel'de görüldü):
  /// donanım çözücü HDR10/HLG kareleri (10-bit, BT.2020, PQ) doğrudan
  /// Flutter'ın görüntü yüzeyine yazıyor, yüzey onları SDR sanıyor. HDR
  /// yayında yol kopyalıya geçer: kareler mpv'ye gelir, mpv HDR'yi SDR'ye
  /// ton eşler (bt.2390) ve yüzeye çizer. Daha çok işlemci ister; yalnız
  /// HDR yayında.
  bool _sdrPath = false;

  /// Kopyalı yolun çözücüsü: "mediacodec-copy" (HDR, HEVC) ya da "no"
  /// (yazılım; eski MPEG-4 Part 2 / Xvid / DivX, [_legacy]).
  String _copyHwdec = 'mediacodec-copy';

  /// Donanım çözücüsünde kare atlatan eski kodekler: Pixel'in (Exynos) MPEG-4
  /// çözücüsü Xvid AVI dizilerde 10 sn'de 40 kare atlattı ("Arrow kasıyor";
  /// günlükte görüldü). Bu yayınlar düşük çözünürlüklü, yazılımla rahat çözülür.
  static bool _legacy(String codec) => RegExp(r'mpeg4|mpeg-4 part 2|msmpeg4|h263|divx|xvid').hasMatch(codec);

  /// media_kit'in Android denetleyicisi (yüzey ve kilit); dışa açık türü
  /// yok, alanlarına dinamik erişilir. Bulunamazsa null.
  dynamic _android0;

  /// media_kit görüntü yüzeyi yeniden kurulunca (arka plandan dönüş, yüzey
  /// değişimi) çıkışı yapılandırmadaki kopyasız yola döndürür; HDR
  /// yayındaysak SDR yolu kendi kilidinde, onun ardından yeniden kurulur.
  Future<void> _watchSurface() async {
    try {
      final dynamic android = await _video.platform.future;
      _android0 = android;
      (android.wid as ValueNotifier<int?>).addListener(() {
        if (_sdrPath) unawaited(_locked(_applySdrPath));
      });
    } on Object {
      // media_kit iç yapısı değişti: HDR yolu yalnız açılışta kurulur.
    }
  }

  /// Yüzey hazır mı: mpv'nin kendi "wid" değerinden okunur. Değilken
  /// çıkış kurulursa libmpv uygulamayı kapatır ("WinID != 0" doğrulaması;
  /// Pixel'de görüldü: media_kit'in Dart tarafındaki yüzey değeri mpv'ye
  /// geçmeden doluyordu). Hazır değilse yüzey gelince dinleyici kurar.
  Future<bool> _surfaceReady(NativePlayer native) async {
    try {
      final wid = (await native.getProperty('wid')).trim();
      return wid.isNotEmpty && wid != '0' && wid != '-1';
    } on Object {
      return false;
    }
  }

  /// media_kit'in kendi kilidinde çalıştırır (çıkış ayarları onun yüzey
  /// dinleyicisiyle çakışmasın); denetleyici bulunamazsa çalıştırmaz.
  Future<void> _locked(Future<void> Function() body) async {
    final android = _android0;
    if (android == null) return;
    try {
      await (android.lock.synchronized(body) as Future<void>);
    } on NoSuchMethodError {
      // media_kit iç yapısı değişti.
    }
  }

  Future<void> _hdrToSdr() async {
    // TV'de kopyalı yol yok: Chromecast 4K HDR'de 10 sn'de 15 kare atladı,
    // ses görüntünün önüne geçti (kullanıcı: "kasıyor, ses önden gidiyor").
    // TV kutusu HDR'yi donanımla doğrudan ekrana verir (HDR10/HLG destekli
    // televizyonda renk doğru); pembe görüntü yalnız telefonda görüldü.
    if (!_android || _tv || _sdrPath) return;
    final values = await _read(const ['video-dec-params/gamma', 'video-codec']);
    final gamma = values['video-dec-params/gamma'];
    final hdr = gamma == 'pq' || gamma == 'hlg';
    // Telefon/tablette HEVC de: kopyasız yol bazı HEVC filmlerde (SDR,
    // BT.709 bildiren) yeşil-mor görüntü veriyordu; kopyalı yolda doğru
    // (Pixel'de görüldü, 0 kare atlama). TV'de kopyalı yol 1080p'de bile
    // kare atlattığı için (Chromecast) yalnız HDR'de.
    final codec = (values['video-codec'] ?? '').toLowerCase();
    final hevc = codec.contains('hevc');
    final legacy = _legacy(codec);
    if (!hdr && !hevc && !legacy) return;
    _sdrPath = true;
    _copyHwdec = legacy ? 'no' : 'mediacodec-copy';
    Diagnostics.instance.log('görüntü', switch ((hdr, hevc)) {
      (true, _) => "HDR ($gamma): SDR'ye ton eşlemeli kopyalı yola geçildi",
      (_, true) => 'HEVC: renk için kopyalı yola geçildi',
      _ => 'Eski MPEG-4 (Xvid/DivX): yazılımla çözülüyor',
    });
    // Yüzey henüz yoksa media_kit yüzeyi bağlayınca dinleyici uygular.
    await _locked(_applySdrPath);
  }

  /// Oynatmanın yükü: 10 sn sonra atlanan kareler günlüğe (takılma
  /// şikâyetlerini ayırt etmek için; her yayında bir kez).
  Future<void> _logDrops() async {
    await Future<void>.delayed(const Duration(seconds: 10));
    final values = await _read(const ['frame-drop-count', 'decoder-frame-drop-count', 'estimated-vf-fps']);
    if (_disposed || values.isEmpty) return;
    final drops = values['frame-drop-count'];
    final decoderDrops = values['decoder-frame-drop-count'];
    final fps = values['estimated-vf-fps'];
    final path = !_sdrPath ? 'kopyasız' : (_copyHwdec == 'no' ? 'yazılım' : 'kopyalı');
    Diagnostics.instance.log('görüntü', '$path yol 10 sn: atlanan kare $drops, çözücü $decoderDrops, fps $fps');
  }

  /// HDR/HEVC için kopyalı, ton eşlemeli yol; eski MPEG-4'te yazılım çözücüyle.
  Future<void> _applySdrPath() async {
    final native = _player.platform;
    if (native is! NativePlayer || !await _surfaceReady(native)) return;
    await native.setProperty('vo', 'null');
    await native.setProperty('hwdec', _copyHwdec);
    await native.setProperty('tone-mapping', 'bt.2390');
    await native.setProperty('target-trc', 'srgb');
    await native.setProperty('target-prim', 'bt.709');
    await native.setProperty('vo', 'gpu');
    await native.setProperty('vid', 'auto');
    await _player.seek(_player.state.position);
  }

  /// Yeni yayın açılmadan HDR yolundan kopyasız yola dönüş.
  Future<void> _leaveSdrPath() async {
    final native = _player.platform;
    if (native is! NativePlayer || !await _surfaceReady(native)) return;
    await native.setProperty('vo', 'null');
    await native.setProperty('hwdec', _zeroCopy.hwdec!);
    await native.setProperty('vo', _zeroCopy.vo!);
  }

  /// Ayarlar › Kalite sınırı: yayın birden çok kalite verdiyse (HLS ana
  /// listesi) sınırın altındaki en yüksek kalite seçilir; kullanıcı
  /// Seçenekler'den kalite seçerse ona dokunulmaz. Yayın başına bir kez.
  bool _capped = false;

  void _applyCap(Tracks t) {
    final max = AppSettings.instance.quality.maxHeight;
    if (_capped || max == null) return;
    final fitting = [
      for (final v in t.video)
        if (_real(v.id) && v.h != null && v.h! <= max) v,
    ]..sort((a, b) => b.h! - a.h!);
    final tallest = t.video.where((v) => _real(v.id) && v.h != null).fold<int>(0, (m, v) => v.h! > m ? v.h! : m);
    if (fitting.isEmpty || tallest <= max) return;
    _capped = true;
    unawaited(_player.setVideoTrack(fitting.first));
  }

  final _state = ValueNotifier(const EngineState());
  final _errors = StreamController<String>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  Tracks _tracks = const Tracks();

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Stream<String> get errors => _errors.stream;

  void _update(EngineState next) {
    if (!_disposed) _state.value = next;
  }

  /// mpv'nin "auto"/"no" sözde izleri listeye alınmaz (arayüz "Otomatik" ve
  /// "Kapalı"yı kendisi ekler).
  static bool _real(String id) => id != EngineState.autoTrack && id != EngineState.noTrack;

  void _onTracks(Tracks t) {
    _tracks = t;
    _applyCap(t);
    String lang(String? title, String? language, String fallback) =>
        [title, language].whereType<String>().where((s) => s.isNotEmpty).firstOrNull ?? fallback;
    _update(
      _state.value.copyWith(
        // Yüksekten düşüğe (yayın sırası karışık geliyordu: 720p, 184p, 1080p...).
        videoTracks: [
          for (final v in t.video.where((v) => _real(v.id)).toList()..sort((a, b) => (b.h ?? 0) - (a.h ?? 0)))
            MediaTrack(v.id, v.h != null ? '${v.h}p' : lang(v.title, v.language, 'Görüntü ${v.id}')),
        ],
        audioTracks: [
          for (final a in t.audio.where((a) => _real(a.id))) MediaTrack(a.id, lang(a.title, a.language, 'Ses ${a.id}')),
        ],
        subtitleTracks: [
          for (final s in t.subtitle.where((s) => _real(s.id)))
            MediaTrack(s.id, lang(s.title, s.language, 'Altyazı ${s.id}')),
        ],
      ),
    );
  }

  @override
  Future<void> open(String url) async {
    if (_stuck) return;
    // Yeni yayında boyut ve izler sıfırlanır: "görüntü geldi" yeniden ölçülür.
    _update(const EngineState());
    _capped = false;
    _videoLogged = false;
    _hdrChecked = false;
    if (_sdrPath) {
      _sdrPath = false;
      await _locked(_leaveSdrPath);
    }
    await _player.open(Media(url));
  }

  @override
  Future<void> playOrPause() async {
    if (!_stuck) await _player.playOrPause();
  }

  final _position = ValueNotifier(Duration.zero);

  @override
  ValueListenable<Duration> get position => _position;

  @override
  Future<void> seek(Duration to) async {
    if (_stuck) return;
    final end = _state.value.duration;
    final clamped = to < Duration.zero ? Duration.zero : (end > Duration.zero && to > end ? end : to);
    _position.value = clamped;
    await _player.seek(clamped);
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (!_stuck) await _player.setVolume(muted ? 0 : 100);
  }

  @override
  Future<void> selectVideoTrack(String id) async {
    if (_stuck) return;
    _capped = true;
    await _player.setVideoTrack(switch (id) {
      EngineState.autoTrack => VideoTrack.auto(),
      EngineState.noTrack => VideoTrack.no(),
      _ => _tracks.video.firstWhere((v) => v.id == id, orElse: VideoTrack.auto),
    });
  }

  @override
  Future<void> selectAudioTrack(String id) async {
    if (_stuck) return;
    await _player.setAudioTrack(switch (id) {
      EngineState.autoTrack => AudioTrack.auto(),
      EngineState.noTrack => AudioTrack.no(),
      _ => _tracks.audio.firstWhere((a) => a.id == id, orElse: AudioTrack.auto),
    });
  }

  @override
  Future<void> selectSubtitleTrack(String id) async {
    if (_stuck) return;
    await _player.setSubtitleTrack(switch (id) {
      EngineState.autoTrack => SubtitleTrack.auto(),
      EngineState.noTrack => SubtitleTrack.no(),
      _ => _tracks.subtitle.firstWhere((s) => s.id == id, orElse: SubtitleTrack.auto),
    });
  }

  @override
  Future<StreamStats> stats() async {
    final values = await _read(const [
      'hwdec-current',
      'demuxer-cache-duration',
      'video-codec',
      'audio-codec-name',
      'estimated-vf-fps',
      'video-bitrate',
      'audio-bitrate',
      'frame-drop-count',
    ]);
    if (values.isEmpty) return const StreamStats();
    String? get(String name) => switch (values[name]?.trim()) {
      null || '' => null,
      final v => v,
    };

    final hwdec = get('hwdec-current');
    final cache = double.tryParse(get('demuxer-cache-duration') ?? '');
    return StreamStats(
      videoCodec: get('video-codec'),
      audioCodec: get('audio-codec-name'),
      decoder: hwdec == null || hwdec == 'no' ? 'yazılım' : hwdec,
      fps: double.tryParse(get('estimated-vf-fps') ?? ''),
      videoBitrate: double.tryParse(get('video-bitrate') ?? '')?.round(),
      audioBitrate: double.tryParse(get('audio-bitrate') ?? '')?.round(),
      cache: cache == null ? null : Duration(milliseconds: (cache * 1000).round()),
      droppedFrames: int.tryParse(get('frame-drop-count') ?? ''),
    );
  }

  @override
  Widget view({BoxFit fit = BoxFit.contain}) =>
      // Denetimler uygulamanındır (alt çubuk); media_kit'inkiler kapalı.
      Video(
        controller: _video,
        controls: NoVideoControls,
        fit: fit,
        // Ayarlar › Altyazı: boyut, renk, arka plan, konum, kalınlık.
        subtitleViewConfiguration: SubtitleViewConfiguration(
          style: SubtitleLook.style(AppSettings.instance),
          padding: SubtitleLook.padding(AppSettings.instance),
        ),
      );

  @override
  Future<void> dispose() async {
    _watchdog?.stop();
    // Kapatmadan önce çekirdek yanıt veriyor mu: takılıysa kapatma çağrısı da
    // arayüzü dondurur (Geri ile çıkarken). O zaman oynatıcı bırakılır; uygulama
    // yeniden açılınca sistem temizler.
    if (_android && !_stuck) {
      try {
        await Future.wait([
          ..._reads,
          MpvProbe.read(library: 'libmpv.so', handle: await _player.handle, names: const ['time-pos']),
        ]).timeout(_disposeProbe);
      } on TimeoutException {
        _stuck = true;
        Diagnostics.instance.log('görüntü', 'oynatıcı kapanırken yanıt vermedi, bırakıldı');
      } on Object {
        // Okuma hatası takılma değildir.
      }
    }
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _errors.close();
    _state.dispose();
    _position.dispose();
    if (!_stuck) await _player.dispose();
  }

  static const _disposeProbe = Duration(seconds: 2);
}
