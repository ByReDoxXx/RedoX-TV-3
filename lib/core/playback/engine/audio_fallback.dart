import 'package:flutter/foundation.dart';

/// Seçilebilir ses izi.
@immutable
class AudioCandidate {
  const AudioCandidate(this.id, {this.codec, this.language});

  final String id;
  final String? codec;
  final String? language;
}

/// Ses izi çözülemeyince yapılacak iş.
sealed class AudioFallbackStep {
  const AudioFallbackStep();
}

/// Yapılacak bir şey yok: çalan iz sağlam ya da ses elle kapatılmış.
final class KeepAudio extends AudioFallbackStep {
  const KeepAudio();
}

final class SwitchAudio extends AudioFallbackStep {
  const SwitchAudio(this.id);

  final String id;
}

/// Bütün izler çözülemedi: görüntü sessiz sürer.
final class NoPlayableAudio extends AudioFallbackStep {
  const NoPlayableAudio();
}

/// mpv ses izini çözemeyince sesi kapatıp görüntüyle sürer, başka ize kendisi
/// geçmez (Philips TV, TrueHD'li 4K film: ses gelmedi, elle iz seçilene kadar
/// sessiz kaldı; günlükte görüldü). Kurallar burada; yan etkisi yoktur.
abstract final class AudioFallbackRule {
  static final _failure = RegExp(r"Failed to initialize a decoder for codec '([^']+)'");

  /// mpv iletisinde çözülemediği söylenen kodek; başka iletide null. İleti
  /// sesi mi görüntüyü mü kastettiğini söylemez, izlerle karşılaştırılır.
  static String? failedCodec(String error) => _failure.firstMatch(error)?.group(1)?.toLowerCase();

  /// [selected]: seçili iz, "auto" (mpv seçti) ya da "no" (kapalı). [failed]:
  /// çözülemeyen kodekler, küçük harfle. Yedek iz çözülemeyen izle aynı dilde
  /// olanlardan seçilir, yoksa listedeki ilk sağlam iz.
  static AudioFallbackStep next({
    required List<AudioCandidate> tracks,
    required String selected,
    required Set<String> failed,
  }) {
    bool broken(AudioCandidate t) => failed.contains(t.codec?.toLowerCase());
    if (selected == 'no') return const KeepAudio();
    final current = tracks.where((t) => t.id == selected).firstOrNull;
    if (current != null && !broken(current)) return const KeepAudio();
    final lost = current ?? tracks.where(broken).firstOrNull;
    if (lost == null) return const KeepAudio();
    final healthy = tracks.where((t) => !broken(t)).toList();
    if (healthy.isEmpty) return const NoPlayableAudio();
    final same = healthy.where((t) => t.language != null && t.language == lost.language).firstOrNull;
    return SwitchAudio((same ?? healthy.first).id);
  }
}
