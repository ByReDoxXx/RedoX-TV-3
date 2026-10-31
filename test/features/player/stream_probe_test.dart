import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/features/player/playback_session.dart';
import 'package:redox_tv/features/player/stream_probe.dart';

import '../../support/fake_engine.dart';

StreamInfo _ok(String url, int ms, [int? bitrate]) => StreamInfo(
  url,
  latency: Duration(milliseconds: ms),
  bitrate: bitrate,
);

void main() {
  group('StreamProbe.order', () {
    test('hızlı açılanlar içinde bit hızı yüksek olan önde', () {
      expect(
        StreamProbe.order([
          _ok('yavas-yuksek', 4000, 9000000),
          _ok('hizli-dusuk', 400, 1500000),
          _ok('hizli-yuksek', 900, 6000000),
        ]),
        ['hizli-yuksek', 'hizli-dusuk', 'yavas-yuksek'],
      );
    });

    test('bit hızı bilinmeyen hızlılar arasında sona, eşitlikte hızlı olan önde', () {
      expect(StreamProbe.order([_ok('bilinmez', 300), _ok('a', 600, 3000000), _ok('b', 500, 3000000)]), [
        'b',
        'a',
        'bilinmez',
      ]);
    });

    test('açılmayanlar en sonda, liste sırasıyla; hiçbiri açılmazsa sıra korunur', () {
      expect(StreamProbe.order([const StreamInfo('x'), _ok('a', 500, 1), const StreamInfo('y')]), ['a', 'x', 'y']);
      expect(StreamProbe.order([const StreamInfo('x'), const StreamInfo('y')]), ['x', 'y']);
    });

    test('hızlı sınırı: en hızlının iki katı ya da +0,7 sn (büyüğü)', () {
      // En hızlı 200 ms: sınır 900 ms (iki katı 400 ms'den büyük).
      expect(StreamProbe.order([_ok('a', 200, 1), _ok('b', 900, 9), _ok('c', 950, 99)]), ['b', 'a', 'c']);
      // En hızlı 2 sn: sınır 4 sn.
      expect(StreamProbe.order([_ok('a', 2000, 1), _ok('b', 3900, 9)]), ['b', 'a']);
    });
  });

  group('StreamProbe.parsePlaylist', () {
    final base = Uri.parse('https://cdn.example/kanal/index.m3u8');

    test('ana liste: en yüksek BANDWIDTH, parça yoklanmaz', () {
      final p = StreamProbe.parsePlaylist('''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
low.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
high.m3u8
''', base);
      expect(p.bandwidth, 5000000);
      expect(p.segment, isNull);
    });

    test('tek kaliteli liste: ilk parçanın adresi (göreli) ve süresi', () {
      final p = StreamProbe.parsePlaylist('''#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:5.560000,
parca-1094.ts
#EXTINF:6.0,
parca-1095.ts
''', base);
      expect(p.bandwidth, isNull);
      expect(p.segment, Uri.parse('https://cdn.example/kanal/parca-1094.ts'));
      expect(p.duration, 5.56);
    });
  });

  group('StreamProbe.rank', () {
    test('tek akışta yoklamaz; sonuç kanal başına saklanır', () async {
      var probes = 0;
      var now = DateTime(2026, 10, 31, 20);
      final probe = StreamProbe(
        probe: (url) async {
          probes++;
          return _ok(url, url == 'b' ? 100 : 500, url == 'b' ? 5 : 1);
        },
        clock: () => now,
      );
      expect(await probe.rank(['tek']), ['tek']);
      expect(probes, 0);
      expect(await probe.rank(['a', 'b']), ['b', 'a']);
      expect(probes, 2);
      expect(await probe.rank(['a', 'b']), ['b', 'a']);
      expect(probes, 2, reason: 'saklanan sonuç');
      now = now.add(const Duration(minutes: 31));
      await probe.rank(['a', 'b']);
      expect(probes, 4, reason: '30 dk sonra yeniden yoklanır');
    });
  });

  group('PlaybackSession + sıralama', () {
    const a = LiveChannel(name: 'A', number: 1, category: 'Ulusal', streams: ['a1', 'a2', 'a3']);
    const b = LiveChannel(name: 'B', number: 2, category: 'Ulusal', streams: ['b1', 'b2']);

    test('ilk açılan akış sıralamanın başı; yedek sırası da sıralamadan', () async {
      final engine = FakeEngine();
      final s = PlaybackSession(
        engine: engine,
        channels: const [a, b],
        initialIndex: 0,
        rank: (streams) async => streams.reversed.toList(),
      );
      expect(s.status, PlaybackStatus.loading);
      await pumpEventQueue();
      expect(engine.opened, ['a3']);
      expect(s.streamCount, 3);
      s.nextStream();
      expect(engine.opened.last, 'a2');
      s.dispose();
    });

    test('kanal hızla değişirse eski kanalın geç gelen sıralaması yok sayılır', () async {
      final engine = FakeEngine();
      final slow = Completer<List<String>>();
      final s = PlaybackSession(
        engine: engine,
        channels: const [a, b],
        initialIndex: 0,
        rank: (streams) => streams.first == 'a1' ? slow.future : Future.value(streams),
      );
      s.zap(1);
      await pumpEventQueue();
      expect(engine.opened, ['b1']);
      slow.complete(['a2', 'a1', 'a3']);
      await pumpEventQueue();
      expect(engine.opened, ['b1'], reason: 'A artık açık değil');
      expect(s.channel, b);
      s.dispose();
    });

    test('sıralama hata verirse liste sırasıyla açılır', () async {
      final engine = FakeEngine();
      final s = PlaybackSession(
        engine: engine,
        channels: const [a],
        initialIndex: 0,
        rank: (_) async => throw StateError('ağ yok'),
      );
      await pumpEventQueue();
      expect(engine.opened, ['a1']);
      s.dispose();
    });
  });
}
