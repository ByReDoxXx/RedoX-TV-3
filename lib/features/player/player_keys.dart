import 'package:flutter/services.dart';

/// Oynatılan içerik: canlı yayın, film ya da dizi bölümü (film ve dizide
/// oynatıcı tasarımı farklıdır ve izlenen yer saklanır).
enum PlayerMode { live, film, series }

/// Kumanda tuşunun oynatıcıdaki karşılığı.
enum PlayerKeyAction {
  /// Tuş odak gezintisine bırakılır.
  ignore,

  /// Tuş tutulur, bir şey yapılmaz.
  consume,
  openEpisodes,
  focusPlay,
  digit,
  showBar,
  playPause,
  zapNext,
  zapPrevious,
  seekBack,
  seekForward,
  openDrawer,
  nextStream,
  openOptions,

  /// Masaüstü: M sesi kapatır/açar.
  toggleMute,

  /// Masaüstü: A ses ve altyazı paneli.
  openTracks,
}

/// Tuş anında oynatıcının durumu.
class PlayerKeyState {
  const PlayerKeyState({
    required this.mode,
    required this.tv,
    required this.desktop,
    required this.options,
    required this.drawer,
    required this.bar,
    required this.hints,
    required this.rootFocused,
    required this.failed,
    required this.seekable,
  });

  final PlayerMode mode;
  final bool tv;

  /// Masaüstü: çubuk açıkken de tuşlar oynatıcınındır (çubuk fareyle kullanılır).
  final bool desktop;
  final bool options;
  final bool drawer;
  final bool bar;
  final bool hints;

  /// Odak oynatıcının kökünde.
  final bool rootFocused;
  final bool failed;
  final bool seekable;
}

/// Kumanda tuşlarının kuralları; yan etkisi yoktur, ekransız sınanır. Bölüm
/// şeridi açıkken ve tuş bırakılırken çağrılmaz (o tuşlar oynatıcının değil).
abstract final class PlayerKeys {
  static final _digits = {
    for (var n = 0; n <= 9; n++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + n): n,
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + n): n,
    },
  };

  /// Rakam tuşunun değeri; rakam değilse null.
  static int? digitOf(LogicalKeyboardKey key) => _digits[key];

  static PlayerKeyAction resolve(PlayerKeyState s, KeyEvent event) {
    final key = event.logicalKey;
    final down = event is KeyDownEvent;
    if (s.mode == PlayerMode.series && s.tv && !s.options && !s.drawer && down && key == LogicalKeyboardKey.arrowUp) {
      return PlayerKeyAction.openEpisodes;
    }
    // Çubuk kendiliğinden açıkken (açılışta, bölüm değişince) odak kökte
    // kalıyordu: tuşlar ne oynatıcıya ne çubuğa gidiyordu (Chromecast;
    // kullanıcı: "seçeneklere gelemiyorum"). İlk basış odağı Oynat'a verir.
    if (s.tv && s.bar && !s.hints && !s.options && !s.drawer && s.rootFocused && down) {
      return PlayerKeyAction.focusPlay;
    }
    // Masaüstü klavye kısayolları (çubuktaki ipuçlarında yazar); kanal
    // listesi açıkken de çalışır (L listeyi kapatır).
    if (s.desktop && !s.options && down) {
      if (key == LogicalKeyboardKey.keyM) return PlayerKeyAction.toggleMute;
      if (key == LogicalKeyboardKey.keyA) return PlayerKeyAction.openTracks;
      if (key == LogicalKeyboardKey.keyL && s.mode != PlayerMode.film) return PlayerKeyAction.openDrawer;
    }
    // Katman açıkken tuşlar odak gezintisine bırakılır (çubuk, menü, liste).
    if (s.options || s.drawer || (s.bar && !s.hints && !s.desktop)) return PlayerKeyAction.ignore;
    // Açılamadı: ◄► ve OK ekrandaki "Tekrar dene" / "Sonraki kanal"
    // düğmelerinindir; ▲▼ ve rakamlar yine kanal değiştirir (yoksa kullanıcı
    // açılmayan kanalda kalıyordu).
    final zapKey =
        _digits.containsKey(key) ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.channelDown;
    // Filmde kanal değiştirme yok (▲▼ ve rakamlar başka filme atlamasın).
    if (s.mode == PlayerMode.film && zapKey) return PlayerKeyAction.consume;
    if (s.failed && !zapKey) return PlayerKeyAction.ignore;
    if (event is KeyRepeatEvent && key != LogicalKeyboardKey.arrowUp && key != LogicalKeyboardKey.arrowDown) {
      return PlayerKeyAction.consume;
    }
    if (_digits.containsKey(key)) return PlayerKeyAction.digit;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      return s.desktop && s.mode != PlayerMode.live ? PlayerKeyAction.playPause : PlayerKeyAction.showBar;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.channelUp) return PlayerKeyAction.zapNext;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.channelDown) {
      return PlayerKeyAction.zapPrevious;
    }
    // Film/dizi: ◄► 10 sn geri/ileri (kanal listesi çubuktaki düğmede).
    if (key == LogicalKeyboardKey.arrowLeft) return s.seekable ? PlayerKeyAction.seekBack : PlayerKeyAction.openDrawer;
    if (key == LogicalKeyboardKey.arrowRight) {
      return s.seekable ? PlayerKeyAction.seekForward : PlayerKeyAction.nextStream;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause || key == LogicalKeyboardKey.space) return PlayerKeyAction.playPause;
    // Menü (telefon kumandası, klavye): Seçenekler.
    if (key == LogicalKeyboardKey.contextMenu) return PlayerKeyAction.openOptions;
    return PlayerKeyAction.ignore;
  }
}
