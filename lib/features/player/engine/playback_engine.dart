import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
  );
}

/// Oynatma motoru: arayüz, kullanılan kütüphaneden (media_kit) bağımsızdır.
/// Testler sahte bir motorla koşar (yerel video kütüphanesi test ortamında
/// yoktur).
abstract class PlaybackEngine {
  ValueListenable<EngineState> get state;

  /// Oynatma hataları (açılamayan adres, desteklenmeyen biçim...).
  Stream<String> get errors;

  /// Adresi açar ve oynatmaya başlar; önceki yayın kapanır.
  Future<void> open(String url);

  Future<void> playOrPause();

  Future<void> selectVideoTrack(String id);
  Future<void> selectAudioTrack(String id);
  Future<void> selectSubtitleTrack(String id);

  /// Görüntü yüzeyi.
  Widget view({BoxFit fit = BoxFit.contain});

  Future<void> dispose();
}
