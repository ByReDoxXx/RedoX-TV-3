import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/playback/engine/mpv_probe.dart';
import 'package:redox_tv/core/playback/playback_session.dart';

import '../../support/fake_engine.dart';

const _channel = LiveChannel(name: 'Bölüm 1', number: 1, category: 'Dizi', streams: ['a', 'b']);

void main() {
  group('bekçi', () {
    test('yanıt gelirse sessiz; yanıt gelmezse bir kez bildirir ve durur', () {
      fakeAsync((time) {
        var stuck = 0;
        var pings = 0;
        var answer = true;
        final dog = EngineWatchdog(
          ping: () {
            pings++;
            return answer ? Future<void>.value() : Completer<void>().future;
          },
          onStuck: () => stuck++,
        )..start();
        time.elapse(const Duration(seconds: 20));
        expect(stuck, 0);
        expect(pings, 5);

        answer = false;
        time.elapse(const Duration(seconds: 4));
        expect(stuck, 0, reason: 'süre dolmadan bildirmez');
        time.elapse(EngineWatchdog.defaultTimeout);
        expect(stuck, 1);

        final before = pings;
        time.elapse(const Duration(minutes: 1));
        expect(stuck, 1);
        expect(pings, before, reason: 'takılınca yoklama biter');
        dog.stop();
      });
    });

    test('süren yoklama varken yenisi başlamaz; okuma hatası takılma sayılmaz', () {
      fakeAsync((time) {
        var stuck = 0;
        var pings = 0;
        final slow = Completer<void>();
        final dog = EngineWatchdog(
          ping: () {
            pings++;
            return slow.future;
          },
          onStuck: () => stuck++,
        )..start();
        time.elapse(const Duration(seconds: 7));
        expect(pings, 1);
        slow.completeError(StateError('kapandı'));
        time.elapse(const Duration(seconds: 1));
        expect(stuck, 0);
        dog.stop();
      });
    });

    test('durdurulunca yoklamaz', () {
      fakeAsync((time) {
        var pings = 0;
        EngineWatchdog(ping: () async => pings++, onStuck: () {})
          ..start()
          ..stop();
        time.elapse(const Duration(minutes: 1));
        expect(pings, 0);
      });
    });
  });

  group('oturum', () {
    test('motor takılınca yayın açılamadı olur, yedek akışa geçmez, yeniden deneme motora gitmez', () {
      final engine = FakeEngine();
      final session = PlaybackSession(engine: engine, channels: const [_channel], initialIndex: 0);
      addTearDown(session.dispose);
      expect(session.status, PlaybackStatus.playing);
      final opened = List.of(engine.opened);

      engine.freeze();
      expect(session.status, PlaybackStatus.failed);
      expect(engine.opened, opened, reason: 'yedek akış aynı motorda açılmaz');

      session.retry();
      expect(session.status, PlaybackStatus.failed);
      expect(engine.opened, opened);
      session.zap(1);
      expect(session.status, PlaybackStatus.failed);
      expect(engine.opened, opened);
    });
  });
}
