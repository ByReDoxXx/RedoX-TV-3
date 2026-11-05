import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/audio_fallback.dart';

const _truehdEn = AudioCandidate('1', codec: 'truehd', language: 'eng');
const _ac3Tr = AudioCandidate('2', codec: 'ac3', language: 'tur');
const _ac3En = AudioCandidate('3', codec: 'ac3', language: 'eng');

void main() {
  AudioFallbackStep next(List<AudioCandidate> tracks, String selected, Set<String> failed) =>
      AudioFallbackRule.next(tracks: tracks, selected: selected, failed: failed);

  test('mpv iletisinden kodek okunur', () {
    expect(AudioFallbackRule.failedCodec("Failed to initialize a decoder for codec 'truehd'."), 'truehd');
    expect(AudioFallbackRule.failedCodec("Dune (2021): Failed to initialize a decoder for codec 'DTS'."), 'dts');
    expect(AudioFallbackRule.failedCodec('Cannot open file'), isNull);
  });

  test('mpv seçmişse aynı dildeki sağlam ize geçilir', () {
    final step = next([_truehdEn, _ac3Tr, _ac3En], 'auto', {'truehd'});
    expect(step, isA<SwitchAudio>().having((s) => s.id, 'id', '3'));
  });

  test('aynı dilde iz yoksa ilk sağlam iz', () {
    final step = next([_truehdEn, _ac3Tr], 'auto', {'truehd'});
    expect(step, isA<SwitchAudio>().having((s) => s.id, 'id', '2'));
  });

  test('kullanıcının seçtiği iz çözülemezse geçilir', () {
    final step = next([_ac3Tr, _truehdEn, _ac3En], '1', {'truehd'});
    expect(step, isA<SwitchAudio>().having((s) => s.id, 'id', '3'));
  });

  test('yedek iz de çözülemezse sıradakine geçilir', () {
    const dts = AudioCandidate('4', codec: 'dts', language: 'eng');
    final step = next([_truehdEn, dts, _ac3En], '4', {'truehd', 'dts'});
    expect(step, isA<SwitchAudio>().having((s) => s.id, 'id', '3'));
  });

  test('sağlam iz çalıyorsa, ses kapalıysa ya da kodek sese ait değilse dokunulmaz', () {
    expect(next([_truehdEn, _ac3Tr], '2', {'truehd'}), isA<KeepAudio>());
    expect(next([_truehdEn, _ac3Tr], 'no', {'truehd'}), isA<KeepAudio>());
    expect(next([_truehdEn, _ac3Tr], 'auto', {'hevc'}), isA<KeepAudio>());
    expect(next([_truehdEn, _ac3Tr], 'auto', {}), isA<KeepAudio>());
    expect(next(const [], 'auto', {'truehd'}), isA<KeepAudio>());
  });

  test('bütün izler çözülemezse ses yok', () {
    expect(next([_truehdEn], 'auto', {'truehd'}), isA<NoPlayableAudio>());
  });
}
