import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/mpv_log_ring.dart';

void main() {
  test('yalnız son satırlar kalır, sıra korunur', () {
    final ring = MpvLogRing(limit: 2)
      ..add('a')
      ..add('b')
      ..add('c');
    expect(ring.lines, ['b', 'c']);
  });
}
