import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/late_closer.dart';

void main() {
  setUp(() => LateCloser.open = 0);

  test('çekirdek yanıt verince oynatıcı kapanır, sayaç geri iner', () {
    fakeAsync((async) {
      final ready = Completer<void>();
      var closed = 0;
      bool? result;
      unawaited(
        LateCloser.closeWhenReady(ready: () => ready.future, close: () async => closed++).then((r) => result = r),
      );
      async.flushMicrotasks();
      expect(LateCloser.open, 1);
      expect(closed, 0, reason: 'meşgul çekirdekte kapatılmaz');

      async.elapse(const Duration(minutes: 1));
      ready.complete();
      async.flushMicrotasks();
      expect(closed, 1);
      expect(result, isTrue);
      expect(LateCloser.open, 0);
    });
  });

  test('süre dolarsa oynatıcı kapatılmaz, açık sayılır', () {
    fakeAsync((async) {
      var closed = 0;
      bool? result;
      unawaited(
        LateCloser.closeWhenReady(
          ready: () => Completer<void>().future,
          close: () async => closed++,
        ).then((r) => result = r),
      );
      async.elapse(const Duration(minutes: 3));
      expect(closed, 0);
      expect(result, isFalse);
      expect(LateCloser.open, 1);
    });
  });

  test('okuma hatasında yine kapatılır; kapatma hatası düşürmez', () async {
    final result = await LateCloser.closeWhenReady(
      ready: () async => throw StateError('okunamadı'),
      close: () async => throw StateError('kapalı'),
    );
    expect(result, isTrue);
    expect(LateCloser.open, 0);
  });
}
