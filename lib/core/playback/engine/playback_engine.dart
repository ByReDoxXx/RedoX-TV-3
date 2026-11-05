import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Adres cihazdaki bir dosya mı (USB, SSD, SD kart, dahili depolama)?
bool isLocalMedia(String url) =>
    url.startsWith('/') ||
    url.startsWith('file:') ||
    url.startsWith('content:') ||
    url.startsWith('fd:') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(url);

/// Seçilebilir iz (kalite, ses, altyazı).
@immutable
class MediaTrack {
  const MediaTrack(this.id, this.label);

  final String id;

  /// Kullanıcıya görünen ad, örn. "720p", "English".
  final String label;

  @override
  bool operator ==(Object other) => other is MediaTrack && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Ses izi çözülemedi: oynatıcı [to] izine geçti; null ise çalınabilen ses izi
/// yok, görüntü sessiz sürüyor.
@immutable
class AudioFallback {
  const AudioFallback(this.to);

  final MediaTrack? to;
}

/// Motorun anlık durumu. Seçili iz kimlikleri: [autoTrack] (otomatik),
/// [noTrack] (kapalı) veya listedeki bir iz.
@immutable
class EngineState {
  const EngineState({
    this.playing = false,
    this.buffering = false,
    this.width,
    this.height,
    this.videoTracks = const [],
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.videoTrack = autoTrack,
    this.audioTrack = autoTrack,
    this.subtitleTrack = autoTrack,
    this.duration = Duration.zero,
    this.stuck = false,
  });

  static const autoTrack = 'auto';
  static const noTrack = 'no';

  final bool playing;
  final bool buffering;

  /// Ölçülen görüntü boyutu; görüntü gelene kadar null.
  final int? width;
  final int? height;

  final List<MediaTrack> videoTracks;
  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;
  final String videoTrack;
  final String audioTrack;
  final String subtitleTrack;

  /// Yayının süresi; canlı yayında sıfır (sarılamaz).
  final Duration duration;

  /// Oynatıcı yanıt vermiyor (donanım çözücü takıldı): yayın durdu, bu motorla
  /// yeni yayın açılamaz. Yeni motor (oynatıcıya yeniden giriş) çalışır.
  final bool stuck;

  /// Sarılabilir mi (film, dizi bölümü; canlı yayın değil). Canlı HLS son
  /// birkaç saniyelik penceresini süre olarak bildirir (TRT 1: 0:17;
  /// Chromecast'te görüldü): 3 dakikadan kısa süre canlı sayılır.
  bool get seekable => duration >= minSeekable;

  static const minSeekable = Duration(minutes: 3);

  /// Görüntü geldi mi (yayın gerçekten açıldı mı).
  bool get hasVideo => (width ?? 0) > 0 && (height ?? 0) > 0;

  EngineState copyWith({
    bool? playing,
    bool? buffering,
    int? Function()? width,
    int? Function()? height,
    List<MediaTrack>? videoTracks,
    List<MediaTrack>? audioTracks,
    List<MediaTrack>? subtitleTracks,
    String? videoTrack,
    String? audioTrack,
    String? subtitleTrack,
    Duration? duration,
    bool? stuck,
  }) => EngineState(
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    width: width == null ? this.width : width(),
    height: height == null ? this.height : height(),
    videoTracks: videoTracks ?? this.videoTracks,
    audioTracks: audioTracks ?? this.audioTracks,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    videoTrack: videoTrack ?? this.videoTrack,
    audioTrack: audioTrack ?? this.audioTrack,
    subtitleTrack: subtitleTrack ?? this.subtitleTrack,
    duration: duration ?? this.duration,
    stuck: stuck ?? this.stuck,
  );
}

/// Yayın bilgisi paneli (Seçenekler › Yayın bilgisi): motorun ölçtükleri;
/// bilinmeyen değer null.
@immutable
class StreamStats {
  const StreamStats({
    this.videoCodec,
    this.audioCodec,
    this.decoder,
    this.fps,
    this.videoBitrate,
    this.audioBitrate,
    this.cache,
    this.droppedFrames,
  });

  final String? videoCodec;
  final String? audioCodec;

  /// Donanım çözücü ("mediacodec"); yazılımla çözülüyorsa "yazılım".
  final String? decoder;
  final double? fps;

  /// Bit hızı (bit/sn).
  final int? videoBitrate;
  final int? audioBitrate;

  /// Ön bellekteki süre (ileriye okunan).
  final Duration? cache;
  final int? droppedFrames;
}

/// Oynatma motoru: arayüz, kullanılan kütüphaneden (media_kit) bağımsızdır.
/// Testler sahte bir motorla koşar (yerel video kütüphanesi test ortamında
/// yoktur).
abstract class PlaybackEngine {
  ValueListenable<EngineState> get state;

  /// Oynatma hataları (açılamayan adres, desteklenmeyen biçim...).
  Stream<String> get errors;

  /// Çözülemeyen ses izinden kendiliğinden geçiş.
  Stream<AudioFallback> get audioFallbacks;

  /// Adresi açar ve oynatmaya başlar; önceki yayın kapanır.
  Future<void> open(String url);

  Future<void> playOrPause();

  /// Oynatma konumu (sık değişir: durumdan ayrı, yalnız sarma çubuğu dinler).
  ValueListenable<Duration> get position;

  /// Konuma sar (süre içinde kırpılır).
  Future<void> seek(Duration to);

  /// Sesi kapatır/açar (Bölünmüş Ekran: yalnız odaktaki karo duyulur).
  Future<void> setMuted(bool muted);

  Future<void> selectVideoTrack(String id);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String id);

  /// Anlık yayın bilgisi (panel saniyede bir sorar).
  Future<StreamStats> stats();

  /// Görüntü yüzeyi.
  Widget view({BoxFit fit = BoxFit.contain});

  Future<void> dispose();
}
