import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/playback/frame_grabber.dart';

const _a = LiveChannel(name: 'A', number: 1, category: 'Ulusal', streams: ['a1', 'a2']);
const _b = LiveChannel(name: 'B', number: 2, category: 'Ulusal', streams: ['b1']);
const _none = LiveChannel(name: 'Yok', number: 3, category: 'Ulusal');

Uint8List _jpeg(int n) => Uint8List.fromList([0xFF, 0xD8, n]);

void main() {
  test('kareler sırayla alınır; açılmayan ilk akışta ikincisi denenir', () async {
    final calls = <String>[];
    final store = FrameStore(
      grabber: (url) async {
        calls.add(url);
        return url == 'a1' ? null : _jpeg(url.codeUnitAt(0));
      },
    );
    store.request(const [_a, _b, _none]);
    await pumpEventQueue();
    expect(calls, ['a1', 'a2', 'b1'], reason: 'akışsız kanal atlanır');
    expect(store.frameOf(_a), _jpeg('a'.codeUnitAt(0)));
    expect(store.frameOf(_b), isNotNull);
    expect(store.frameOf(_none), isNull);
  });

  test('aynı anda tek kare alınır', () async {
    var running = 0, peak = 0;
    final store = FrameStore(
      grabber: (url) async {
        peak = ++running > peak ? running : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
        return _jpeg(1);
      },
    );
    store.request(const [_a, _b]);
    store.request(const [_a, _b]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(peak, 1);
  });

  test('taze kare yeniden alınmaz; süresi dolunca alınır', () async {
    var now = DateTime(2026, 11, 1, 2);
    var calls = 0;
    final store = FrameStore(
      clock: () => now,
      grabber: (url) async {
        calls++;
        return _jpeg(calls);
      },
    );
    store.request(const [_b]);
    await pumpEventQueue();
    store.request(const [_b]);
    await pumpEventQueue();
    expect(calls, 1);
    now = now.add(const Duration(minutes: 11));
    store.request(const [_b]);
    await pumpEventQueue();
    expect(calls, 2);
    expect(store.frameOf(_b), _jpeg(2));
  });

  test('pause: o an alınan biter, sıradaki alınmaz', () async {
    final gate = Completer<Uint8List?>();
    final calls = <String>[];
    final store = FrameStore(
      grabber: (url) {
        calls.add(url);
        return url == 'a1' ? gate.future : Future.value(_jpeg(2));
      },
    );
    store.request(const [_a, _b]);
    await pumpEventQueue();
    store.pause();
    gate.complete(_jpeg(1));
    await pumpEventQueue();
    expect(calls, ['a1']);
    expect(store.frameOf(_a), isNotNull);
    expect(store.frameOf(_b), isNull);
  });

  test('pause: kesilen alımda ikinci akış denenmez', () async {
    final gate = Completer<Uint8List?>();
    final calls = <String>[];
    const channel = LiveChannel(name: 'A', number: 9, category: 'TV', streams: ['x1', 'x2']);
    final store = FrameStore(
      grabber: (url) {
        calls.add(url);
        return gate.future;
      },
    );
    store.request(const [channel]);
    await pumpEventQueue();
    store.pause();
    gate.complete(null);
    await pumpEventQueue();
    expect(calls, ['x1']);
  });

  test('kare gelince dinleyiciler haber alır', () async {
    final store = FrameStore(grabber: (url) async => _jpeg(1));
    var notified = 0;
    store.addListener(() => notified++);
    store.request(const [_a]);
    await pumpEventQueue();
    expect(notified, 1);
  });
}
