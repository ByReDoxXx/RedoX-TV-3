import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/content/live_channel.dart';
import 'package:redox_tv/core/playback/radio_controller.dart';

import '../../support/fake_radio_audio.dart';

const _a = LiveChannel(name: 'A FM', number: 1, category: 'Pop', streams: ['a1', 'a2']);
const _b = LiveChannel(name: 'B Radyo', number: 2, category: 'Pop', streams: ['b1']);
const _c = LiveChannel(name: 'C Türkü', number: 3, category: 'Türkü & Halk', streams: ['c1']);

(RadioController, FakeRadioAudio) _radio({Set<String> failing = const {}, bool autoPlay = true}) {
  final audio = FakeRadioAudio(failing: failing, autoPlay: autoPlay);
  final radio = RadioController(
    stations: ValueNotifier(const [_a, _b, _c]),
    audio: () => audio,
    connectTimeout: const Duration(seconds: 5),
  );
  addTearDown(radio.dispose);
  return (radio, audio);
}

void main() {
  test('istasyon çalar; ses gelince durum "çalıyor"', () async {
    final (radio, audio) = _radio();
    await radio.play(_a);
    expect(audio.opened, ['a1']);
    expect(radio.current, _a);
    expect(radio.status, RadioStatus.playing);
    expect(radio.streamPosition, (1, 2));
  });

  test('yayın açılmazsa yedeğe geçer; hiçbiri açılmazsa "açılmadı"', () async {
    final (radio, audio) = _radio(failing: {'a1'});
    await radio.play(_a);
    await pumpEventQueue();
    expect(audio.opened, ['a1', 'a2']);
    expect(radio.status, RadioStatus.playing);
    expect(radio.streamPosition, (2, 2));

    final (radio2, audio2) = _radio(failing: {'b1'});
    await radio2.play(_b);
    await pumpEventQueue();
    expect(audio2.opened, ['b1']);
    expect(radio2.status, RadioStatus.failed);
  });

  test('bağlanma süresi dolunca sıradaki yayın denenir', () {
    fakeAsync((async) {
      final (radio, audio) = _radio(autoPlay: false);
      radio.play(_a);
      async.flushMicrotasks();
      expect(radio.status, RadioStatus.connecting);
      async.elapse(const Duration(seconds: 6));
      expect(audio.opened, ['a1', 'a2']);
    });
  });

  test('duraklat/sürdür ve kapat', () async {
    final (radio, _) = _radio();
    await radio.play(_b);
    await radio.toggle();
    expect(radio.status, RadioStatus.paused);
    await radio.toggle();
    expect(radio.status, RadioStatus.playing);
    await radio.stop();
    expect(radio.status, RadioStatus.idle);
  });

  test('çalan şarkı yayının üst verisinden gelir', () async {
    final (radio, audio) = _radio();
    await radio.play(_c);
    audio.icy = 'Neşet Ertaş - Gönül Dağı';
    expect(radio.title, 'Neşet Ertaş - Gönül Dağı');
  });

  test('komşu istasyon listede sarar', () async {
    final (radio, _) = _radio();
    await radio.play(_c);
    expect(radio.neighbour(const [_a, _b, _c], 1), _a);
    expect(radio.neighbour(const [_a, _b, _c], -1), _b);
  });

  test('uyku zamanlayıcısı süre dolunca radyoyu kapatır', () {
    fakeAsync((async) {
      final (radio, _) = _radio();
      radio.play(_a);
      async.flushMicrotasks();
      radio.setSleep(30);
      expect(radio.sleepLeft, isNotNull);
      async.elapse(const Duration(minutes: 31));
      expect(radio.status, RadioStatus.idle);
      expect(radio.sleepLeft, isNull);
    });
  });

  group('radyo cızırtısı', () {
    test('bağlanırken çalar, ses gelince susar', () {
      fakeAsync((async) {
        final (radio, audio) = _radio(autoPlay: false);
        radio.play(_a);
        async.flushMicrotasks();
        expect(audio.noise, isTrue, reason: 'bağlanıyor');
        audio.autoPlay = true;
        radio.toggle();
        async.flushMicrotasks();
        expect(audio.noise, isFalse);
      });
    });

    test('kadran çevrilince kısa süre çalar; kapalıysa hiç çalmaz', () {
      fakeAsync((async) {
        final (radio, audio) = _radio();
        radio.tuning();
        async.flushMicrotasks();
        expect(audio.noise, isTrue);
        async.elapse(RadioController.tuneNoise + const Duration(milliseconds: 100));
        expect(audio.noise, isFalse);

        radio.noise = false;
        radio.tuning();
        radio.play(_b);
        async.flushMicrotasks();
        expect(audio.noiseStarts, 1, reason: 'seçenek kapalı');
      });
    });
  });
}
