import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/seek_queue.dart';

void main() {
  test('sürerken gelenlerden yalnız sonuncusu yapılır', () async {
    final gates = <Completer<void>>[];
    final done = <int>[];
    final queue = SeekQueue((to) {
      done.add(to.inSeconds);
      final gate = Completer<void>();
      gates.add(gate);
      return gate.future;
    });
    unawaited(queue.seek(const Duration(seconds: 10)));
    await queue.seek(const Duration(seconds: 20));
    await queue.seek(const Duration(seconds: 30));
    expect(done, [10]);

    gates[0].complete();
    await pumpEventQueue();
    expect(done, [10, 30]);

    gates[1].complete();
    await pumpEventQueue();
    await queue.seek(const Duration(seconds: 40));
    expect(done, [10, 30, 40]);
    gates[2].complete();
  });

  test('hata sırayı kilitlemez', () async {
    var calls = 0;
    final queue = SeekQueue((to) async {
      calls++;
      if (calls == 1) throw StateError('olmadı');
    });
    await expectLater(queue.seek(Duration.zero), throwsStateError);
    await queue.seek(const Duration(seconds: 1));
    expect(calls, 2);
  });
}
