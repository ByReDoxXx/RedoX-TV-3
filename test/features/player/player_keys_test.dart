import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redox_tv/features/player/player_keys.dart';

const _down = PhysicalKeyboardKey(0x70052);

KeyEvent _press(LogicalKeyboardKey key) => KeyDownEvent(physicalKey: _down, logicalKey: key, timeStamp: Duration.zero);

KeyEvent _repeat(LogicalKeyboardKey key) =>
    KeyRepeatEvent(physicalKey: _down, logicalKey: key, timeStamp: Duration.zero);

PlayerKeyState _state({
  PlayerMode mode = PlayerMode.live,
  bool tv = true,
  bool desktop = false,
  bool options = false,
  bool drawer = false,
  bool bar = false,
  bool hints = false,
  bool rootFocused = true,
  bool failed = false,
  bool seekable = false,
}) => PlayerKeyState(
  mode: mode,
  tv: tv,
  desktop: desktop,
  options: options,
  drawer: drawer,
  bar: bar,
  hints: hints,
  rootFocused: rootFocused,
  failed: failed,
  seekable: seekable,
);

void main() {
  PlayerKeyAction act(PlayerKeyState s, LogicalKeyboardKey key) => PlayerKeys.resolve(s, _press(key));

  test('canlı yayın: yön tuşları kanal, liste ve akış; OK çubuk', () {
    final s = _state();
    expect(act(s, LogicalKeyboardKey.arrowUp), PlayerKeyAction.zapNext);
    expect(act(s, LogicalKeyboardKey.channelDown), PlayerKeyAction.zapPrevious);
    expect(act(s, LogicalKeyboardKey.arrowLeft), PlayerKeyAction.openDrawer);
    expect(act(s, LogicalKeyboardKey.arrowRight), PlayerKeyAction.nextStream);
    expect(act(s, LogicalKeyboardKey.select), PlayerKeyAction.showBar);
    expect(act(s, LogicalKeyboardKey.contextMenu), PlayerKeyAction.openOptions);
    expect(act(s, LogicalKeyboardKey.keyQ), PlayerKeyAction.ignore);
  });

  test('sarılabilen içerikte ◄► sarar', () {
    final s = _state(mode: PlayerMode.film, seekable: true);
    expect(act(s, LogicalKeyboardKey.arrowLeft), PlayerKeyAction.seekBack);
    expect(act(s, LogicalKeyboardKey.arrowRight), PlayerKeyAction.seekForward);
  });

  test('filmde kanal tuşları tutulur; dizide ▲ bölüm şeridi', () {
    final film = _state(mode: PlayerMode.film);
    expect(act(film, LogicalKeyboardKey.arrowUp), PlayerKeyAction.consume);
    expect(act(film, LogicalKeyboardKey.digit5), PlayerKeyAction.consume);
    final series = _state(mode: PlayerMode.series);
    expect(act(series, LogicalKeyboardKey.arrowUp), PlayerKeyAction.openEpisodes);
    expect(act(series, LogicalKeyboardKey.arrowDown), PlayerKeyAction.zapPrevious);
    expect(act(_state(mode: PlayerMode.series, tv: false), LogicalKeyboardKey.arrowUp), PlayerKeyAction.zapNext);
  });

  test('rakamlar çift tanınır', () {
    expect(act(_state(), LogicalKeyboardKey.digit7), PlayerKeyAction.digit);
    expect(PlayerKeys.digitOf(LogicalKeyboardKey.digit7), 7);
    expect(PlayerKeys.digitOf(LogicalKeyboardKey.numpad3), 3);
    expect(PlayerKeys.digitOf(LogicalKeyboardKey.arrowUp), isNull);
  });

  test('açık katmanda tuşlar gezintiye kalır; kökteki ilk basış odağı Oynat\'a verir', () {
    expect(act(_state(options: true), LogicalKeyboardKey.select), PlayerKeyAction.ignore);
    expect(act(_state(drawer: true), LogicalKeyboardKey.arrowUp), PlayerKeyAction.ignore);
    expect(act(_state(bar: true), LogicalKeyboardKey.select), PlayerKeyAction.focusPlay);
    expect(act(_state(bar: true, rootFocused: false), LogicalKeyboardKey.select), PlayerKeyAction.ignore);
    expect(act(_state(bar: true, hints: true), LogicalKeyboardKey.arrowUp), PlayerKeyAction.zapNext);
  });

  test('masaüstü: çubuk açıkken de tuşlar çalışır, filmde OK duraklatır', () {
    final s = _state(tv: false, desktop: true, bar: true);
    expect(act(s, LogicalKeyboardKey.arrowUp), PlayerKeyAction.zapNext);
    final film = _state(mode: PlayerMode.film, tv: false, desktop: true);
    expect(act(film, LogicalKeyboardKey.select), PlayerKeyAction.playPause);
  });

  test('açılamadı: ekrandaki düğmelerin tuşları bırakılır, kanal tuşları çalışır', () {
    final s = _state(failed: true);
    expect(act(s, LogicalKeyboardKey.select), PlayerKeyAction.ignore);
    expect(act(s, LogicalKeyboardKey.arrowLeft), PlayerKeyAction.ignore);
    expect(act(s, LogicalKeyboardKey.arrowUp), PlayerKeyAction.zapNext);
    expect(act(s, LogicalKeyboardKey.digit1), PlayerKeyAction.digit);
  });

  test('basılı tutma yalnız ▲▼ için geçerli', () {
    final s = _state();
    expect(PlayerKeys.resolve(s, _repeat(LogicalKeyboardKey.arrowUp)), PlayerKeyAction.zapNext);
    expect(PlayerKeys.resolve(s, _repeat(LogicalKeyboardKey.select)), PlayerKeyAction.consume);
    expect(PlayerKeys.resolve(s, _repeat(LogicalKeyboardKey.arrowLeft)), PlayerKeyAction.consume);
  });
}
