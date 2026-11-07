import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/core/playback/engine/display_rate.dart';

void main() {
  // Chromecast'in Philips ekrandan okuduğu modların bir kısmı.
  const k60 = DisplayMode(id: 104, width: 3840, height: 2160, refreshRate: 60.000004);
  const k5994 = DisplayMode(id: 103, width: 3840, height: 2160, refreshRate: 59.94006);
  const k50 = DisplayMode(id: 105, width: 3840, height: 2160, refreshRate: 50);
  const k23976 = DisplayMode(id: 109, width: 3840, height: 2160, refreshRate: 23.976025);
  const k24 = DisplayMode(id: 110, width: 3840, height: 2160, refreshRate: 24.000002);
  const hd23976 = DisplayMode(id: 115, width: 1920, height: 1080, refreshRate: 23.976025);
  const modes = [DisplayMode.auto, k60, k5994, k50, k23976, k24, hd23976];

  test('23,976 fps film aynı çözünürlükte 23,976 Hz alır', () {
    expect(pickRate(modes, k60, 23.976024), same(k23976));
  });

  test('25 fps yayın 50 Hz, 29,97 fps 59,94 Hz alır', () {
    expect(pickRate(modes, k60, 25), same(k50));
    expect(pickRate(modes, k60, 29.97003), same(k5994));
  });

  test('24 ve 23,976 birbirine karışmaz', () {
    expect(pickRate(modes, k60, 24), same(k24));
  });

  test('uygun mod yoksa (yalnız 60 Hz) null', () {
    expect(pickRate(const [DisplayMode.auto, k60], k60, 23.976), isNull);
    expect(pickRate(modes, k60, 0), isNull);
  });
}
