import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/seek_gate.dart';

void main() {
  test('açıkken sarma hemen yapılır', () async {
    final done = <int>[];
    final gate = SeekGate((to) async => done.add(to.inSeconds));
    await gate.seek(const Duration(seconds: 5));
    expect(done, [5]);
    expect(gate.holding, isFalse);
  });

  test('kapalıyken yalnız sonuncusu saklanır, açılınca yapılır', () async {
    final done = <int>[];
    final gate = SeekGate((to) async => done.add(to.inSeconds))..close();
    await gate.seek(const Duration(seconds: 5));
    await gate.seek(const Duration(seconds: 9));
    expect(done, isEmpty);
    expect(gate.holding, isTrue);

    await gate.open();
    expect(done, [9]);
    expect(gate.holding, isFalse);
    expect(gate.closed, isFalse);
  });

  test('bekleyen sarma yoksa açılınca sarılmaz', () async {
    final done = <int>[];
    final gate = SeekGate((to) async => done.add(to.inSeconds))..close();
    await gate.open();
    expect(done, isEmpty);
  });

  test('yeni açılış eski yayının sarmasını atar', () async {
    final done = <int>[];
    final gate = SeekGate((to) async => done.add(to.inSeconds))..close();
    await gate.seek(const Duration(seconds: 5));
    gate.close();
    await gate.open();
    expect(done, isEmpty);
  });
}
