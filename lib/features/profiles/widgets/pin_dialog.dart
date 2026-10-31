import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/content/profiles.dart';
import '../../../core/theme/redox_colors.dart';
import '../../../core/theme/redox_shapes.dart';
import '../../../core/ui/focus_glow.dart';
import '../../../core/ui/redox_icon.dart';

/// Ebeveyn PIN'i ister (4 hane). [check] verilirse doğrulanana kadar sorar
/// ve true döner; [create] ise iki kez girilen yeni PIN'i döner. Vazgeçilirse
/// null/false. Ekran tuş takımı ve kumandanın/klavyenin rakam tuşları çalışır.
Future<bool> verifyPin(BuildContext context, {required Future<bool> Function(String) check, String? reason}) async =>
    await showDialog<String>(
      context: context,
      builder: (_) => PinDialog(title: 'Ebeveyn PIN\'i', subtitle: reason, check: check),
    ) !=
    null;

Future<String?> createPin(BuildContext context) => showDialog<String>(
  context: context,
  builder: (_) => const PinDialog(
    title: 'Ebeveyn PIN\'i belirleyin',
    subtitle: 'Çocuk profilinden çıkmak ve profilleri düzenlemek için sorulur.',
    confirm: true,
  ),
);

class PinDialog extends StatefulWidget {
  const PinDialog({super.key, required this.title, this.subtitle, this.check, this.confirm = false});

  final String title;
  final String? subtitle;

  /// PIN'i doğrular; yanlışsa pencere açık kalır.
  final Future<bool> Function(String)? check;

  /// Yeni PIN: ikinci kez girilir, eşleşmezse baştan.
  final bool confirm;

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _digits = '';
  String? _first;
  String? _error;
  bool _busy = false;

  static final _keys = {
    for (var i = 0; i <= 9; i++) ...{
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i): '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i): '$i',
    },
  };

  String get _prompt => switch ((widget.confirm, _first)) {
    (true, null) => 'Yeni PIN',
    (true, _) => 'PIN\'i tekrar girin',
    _ => 'PIN',
  };

  void _type(String d) {
    if (_busy || _digits.length >= ProfileStore.pinLength) return;
    setState(() {
      _digits += d;
      _error = null;
    });
    if (_digits.length == ProfileStore.pinLength) _complete();
  }

  void _erase() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _complete() async {
    final pin = _digits;
    if (widget.confirm) {
      final first = _first;
      if (first == null) {
        setState(() {
          _first = pin;
          _digits = '';
        });
      } else if (first == pin) {
        Navigator.pop(context, pin);
      } else {
        setState(() {
          _first = null;
          _digits = '';
          _error = 'PIN\'ler eşleşmedi, baştan girin.';
        });
      }
      return;
    }
    final check = widget.check;
    if (check == null) {
      Navigator.pop(context, pin);
      return;
    }
    setState(() => _busy = true);
    final ok = await check(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, pin);
    } else {
      setState(() {
        _busy = false;
        _digits = '';
        _error = 'PIN yanlış.';
      });
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_keys[e.logicalKey] case final d?) {
      _type(d);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _erase();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: RedoxRoles.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedoxRadius.xl)),
      child: Focus(
        onKeyEvent: _onKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RedoxIcon(RedoxIcons.lock, filled: true, color: RedoxRoles.tertiary, size: 28),
                  const SizedBox(height: 8),
                  Text(widget.title, style: t.headlineSmall!.copyWith(color: RedoxRoles.onSurface)),
                  if (widget.subtitle case final s?) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        s,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium!.copyWith(color: RedoxRoles.onSurfaceVariant),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(_prompt, style: t.titleMedium!.copyWith(color: RedoxRoles.onSurface)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < ProfileStore.pinLength; i++)
                        Container(
                          key: ValueKey('pin-$i'),
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _digits.length ? RedoxSeeds.amber : Colors.transparent,
                            border: Border.all(color: RedoxRoles.outline, width: 2),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: Text(_error ?? '', style: t.bodyMedium!.copyWith(color: RedoxRoles.error)),
                    ),
                  ),
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [for (final d in row) _Key(label: d, autofocus: d == '5', onPressed: () => _type(d))],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Key(icon: RedoxIcons.close, onPressed: () => Navigator.pop(context)),
                      _Key(label: '0', onPressed: () => _type('0')),
                      _Key(icon: RedoxIcons.backspace, onPressed: _erase),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuş takımının yuvarlak tuşu; odakta amber.
class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onPressed, this.autofocus = false});

  final String? label;
  final RedoxIcons? icon;
  final VoidCallback onPressed;
  final bool autofocus;

  static const size = 52.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: FocusGlow(
        borderRadius: BorderRadius.circular(size / 2),
        builder: (context, active) {
          final fg = active ? RedoxSeeds.obsidian : RedoxRoles.onSurface;
          return Material(
            color: active ? RedoxSeeds.amber : RedoxAccent.glassFill,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              autofocus: autofocus,
              customBorder: const CircleBorder(),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  child: switch ((label, icon)) {
                    (final l?, _) => Text(l, style: t.titleLarge!.copyWith(color: fg)),
                    (_, final i?) => RedoxIcon(i, color: fg),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
