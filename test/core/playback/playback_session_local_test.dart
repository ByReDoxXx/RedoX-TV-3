import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/playback/engine/playback_engine.dart';
import 'package:redox_tv/core/playback/playback_session.dart';

import '../../support/fake_engine.dart';

const _path = '/storage/6AE9-B46A/Filmler/Film.mkv';
const _file = LiveChannel(name: 'Film', number: 1, category: 'USB', streams: [_path]);
const _web = LiveChannel(name: 'Kanal', number: 2, category: 'TV', streams: ['http://a.test/1.ts']);

/// Hata iletisi gönderen motor (mpv'nin iz açamadığında yaptığı gibi).
class _Engine extends FakeEngine {
  _Engine() {
    autoVideo = false;
  }
}

void main() {
  test('cihazdaki dosya adresleri tanınır', () {
    expect(isLocalMedia(_path), isTrue);
    expect(isLocalMedia('file:///storage/a.mkv'), isTrue);
    expect(isLocalMedia(r'D:\Filmler\a.mkv'), isTrue);
    expect(isLocalMedia('http://a.test/1.ts'), isFalse);
    expect(isLocalMedia('rtsp://a.test/1'), isFalse);
  });

  PlaybackSession session(FakeEngine engine, LiveChannel channel) =>
      PlaybackSession(engine: engine, channels: [channel], initialIndex: 0);

  test('dosyada iz hatası "açılamadı" demez, görüntü gelince oynar', () {
    fakeAsync((time) {
      final engine = _Engine();
      final s = session(engine, _file);
      engine.emitError('Could not open codec.');
      time.flushMicrotasks();
      expect(s.status, PlaybackStatus.loading);
      time.elapse(const Duration(seconds: 20));
      expect(s.status, PlaybackStatus.loading, reason: 'dosya 15 sn sınırına takılmaz');
      engine.showVideo();
      expect(s.status, PlaybackStatus.playing);
      s.dispose();
    });
  });

  test('dosya hiç açılamıyorsa hemen "açılamadı"', () {
    fakeAsync((time) {
      final engine = _Engine();
      final s = session(engine, _file);
      engine.emitError("Cannot open file '$_path': No such file or directory");
      time.flushMicrotasks();
      expect(s.status, PlaybackStatus.failed);
      s.dispose();
    });
  });

  test('süre dolduktan sonra görüntü gelirse uyarı kalkar', () {
    fakeAsync((time) {
      final engine = _Engine();
      final s = session(engine, _file);
      time.elapse(PlaybackSession.localStartupTimeout);
      expect(s.status, PlaybackStatus.failed);
      engine.showVideo();
      expect(s.status, PlaybackStatus.playing);
      s.dispose();
    });
  });

  test('ağ yayınında hata eskisi gibi hemen sonuçlanır', () {
    fakeAsync((time) {
      final engine = _Engine();
      final s = session(engine, _web);
      engine.emitError('tcp: connection refused');
      time.flushMicrotasks();
      expect(s.status, PlaybackStatus.failed);
      s.dispose();
    });
  });

  test('motor açılmadan önceki görüntü geç gelmiş sayılmaz', () {
    fakeAsync((time) {
      final engine = _Engine();
      final s = PlaybackSession(
        engine: engine,
        channels: const [_web],
        initialIndex: 0,
        resolve: (_) async => throw StateError('çözülemedi'),
      );
      time.flushMicrotasks();
      expect(s.status, PlaybackStatus.failed);
      engine.showVideo();
      expect(s.status, PlaybackStatus.failed);
      s.dispose();
    });
  });
}
