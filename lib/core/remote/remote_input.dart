import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../layout/mouse_mode.dart';
import '../platform/device_controls.dart';
import 'remote_key.dart';

/// Telefon kumandasından gelen tuşu ve yazıyı TV'de Flutter içinde uygular
/// (yerel kod yok; kullanıcı isteği: "Flutter ile yaz").
/// - **Tuşlar:** odaktaki düğümden köke doğru her odağın tuş işleyicisine
///   verilir; FocusManager'ın gerçek tuşta yaptığı gibi. Böylece yön tuşları
///   odağı gezdirir, OK etkinleştirir, oynatıcının ▲▼, rakam ve oynat/duraklat
///   kısayolları aynen çalışır.
/// - **Geri:** Android Geri tuşu gibi: en üstteki sayfa ya da pencere kapanır;
///   sayfanın kendi Geri davranışı (PopScope) aynen çalışır.
/// - **Ses:** cihaz sesi (DeviceControls); **Ana sayfa:** uygulamanın Anasayfası.
/// - **Yazı:** açık yazı penceresine ([textTarget]) ya da odaktaki metin
///   alanına.
abstract final class RemoteInput {
  static const _keys = {
    RemoteKey.up: LogicalKeyboardKey.arrowUp,
    RemoteKey.down: LogicalKeyboardKey.arrowDown,
    RemoteKey.left: LogicalKeyboardKey.arrowLeft,
    RemoteKey.right: LogicalKeyboardKey.arrowRight,
    RemoteKey.ok: LogicalKeyboardKey.select,
    RemoteKey.menu: LogicalKeyboardKey.contextMenu,
    RemoteKey.playPause: LogicalKeyboardKey.mediaPlayPause,
    RemoteKey.channelUp: LogicalKeyboardKey.channelUp,
    RemoteKey.channelDown: LogicalKeyboardKey.channelDown,
    RemoteKey.digit0: LogicalKeyboardKey.digit0,
    RemoteKey.digit1: LogicalKeyboardKey.digit1,
    RemoteKey.digit2: LogicalKeyboardKey.digit2,
    RemoteKey.digit3: LogicalKeyboardKey.digit3,
    RemoteKey.digit4: LogicalKeyboardKey.digit4,
    RemoteKey.digit5: LogicalKeyboardKey.digit5,
    RemoteKey.digit6: LogicalKeyboardKey.digit6,
    RemoteKey.digit7: LogicalKeyboardKey.digit7,
    RemoteKey.digit8: LogicalKeyboardKey.digit8,
    RemoteKey.digit9: LogicalKeyboardKey.digit9,
  };

  /// Ses adımı (0–1).
  static const volumeStep = 1 / 15;

  /// Açık yazı penceresi (telefondan yazı bekleyen); yoksa null.
  static ValueNotifier<String>? textTarget;

  static Future<void> handle(RemoteKey key, {required VoidCallback onHome}) async {
    switch (key) {
      case RemoteKey.home:
        onHome();
      case RemoteKey.back:
        final context = FocusManager.instance.primaryFocus?.context;
        if (context != null && context.mounted) {
          await Navigator.maybeOf(context, rootNavigator: true)?.maybePop();
        }
      case RemoteKey.volumeUp || RemoteKey.volumeDown:
        final now = await DeviceControls.volume();
        if (now == null) return;
        await DeviceControls.setVolume(now + (key == RemoteKey.volumeUp ? volumeStep : -volumeStep));
      default:
        press(key);
    }
  }

  /// Tuşu odaktaki düğüme basılıp bırakılmış gibi verir; işlendiyse true.
  static bool press(RemoteKey key) {
    MouseMode.instance.keyUsed();
    final logical = _keys[key];
    if (logical == null) return false;
    final physical = PhysicalKeyboardKey(logical.keyId);
    final time = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    final character = key.name.startsWith('digit') ? logical.keyLabel : null;
    final down = _dispatch(
      KeyDownEvent(physicalKey: physical, logicalKey: logical, character: character, timeStamp: time),
    );
    _dispatch(KeyUpEvent(physicalKey: physical, logicalKey: logical, timeStamp: time));
    return down;
  }

  static bool _dispatch(KeyEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    for (final node in [focus, ...focus.ancestors]) {
      switch (node.onKeyEvent?.call(node, event)) {
        case KeyEventResult.handled:
          return true;
        case KeyEventResult.skipRemainingHandlers:
          return false;
        case KeyEventResult.ignored || null:
          continue;
      }
    }
    return false;
  }

  /// Telefon klavyesi: yazı açık yazı penceresinin ya da odaktaki metin
  /// alanının içeriği olur; ikisi de yoksa false.
  static bool type(String text) {
    if (textTarget case final target?) {
      target.value = text;
      return true;
    }
    final editable = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return false;
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    return true;
  }
}
