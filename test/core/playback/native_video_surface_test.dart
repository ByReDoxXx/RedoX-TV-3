import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/native_video_surface.dart';

void main() {
  const screen = Size(1920, 1080);

  test('sığdır: geniş film üstte ve altta boşluk bırakır, ortalanır', () {
    expect(videoRect(screen, const Size(1920, 804), BoxFit.contain), const Rect.fromLTWH(0, 138, 1920, 804));
  });

  test('doldur: ekranı kaplar, taşan kısım ekran dışında kalır', () {
    final rect = videoRect(screen, const Size(1920, 804), BoxFit.cover);
    expect(rect.height, 1080);
    expect(rect.left, lessThan(0));
    expect(rect.center, screen.center(Offset.zero));
  });

  test('germe: tam ekran', () {
    expect(videoRect(screen, const Size(1920, 804), BoxFit.fill), Offset.zero & screen);
  });

  test('boyut bilinmiyorsa tam ekran', () {
    expect(videoRect(screen, null, BoxFit.contain), Offset.zero & screen);
    expect(videoRect(screen, Size.zero, BoxFit.contain), Offset.zero & screen);
  });
}
