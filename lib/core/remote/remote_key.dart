/// Telefon kumandasının tuşları; TV'de nasıl işlendikleri: RemoteInput.
enum RemoteKey {
  up,
  down,
  left,
  right,
  ok,
  back,
  menu,
  playPause,
  channelUp,
  channelDown,
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  volumeUp,
  volumeDown,
  home;

  static RemoteKey digit(int d) => values[RemoteKey.digit0.index + d];

  static RemoteKey? byName(String name) => values.asNameMap()[name];
}
