import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kök sayfada Geri: ilk basışta uyarı, [window] içinde ikinci basışta
/// uygulamadan çıkılır (kullanıcı isteği: Geri doğrudan çıkmasın).
///
/// Alt ağaçtaki bir bileşen Geri'yi önce kendisi işlemek isterse (ör. yazma
/// kipindeki arama kutusu) [DoubleBackToExitState.addHandler] ile kaydolur.
/// Geri'de son kaydolan önce sorulur; `true` dönen Geri'yi tüketir.
/// (Flutter 3.47'de `didPopRoute` gözlemcileri kayıt sırasıyla sorulur ve
/// Navigator önce gelir; bu yüzden ayrı gözlemci işe yaramaz.)
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child, this.window = const Duration(seconds: 2)});

  final Widget child;
  final Duration window;

  static const message = 'Çıkmak için tekrar Geri\'ye basın';

  static DoubleBackToExitState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<DoubleBackToExitState>();

  @override
  State<DoubleBackToExit> createState() => DoubleBackToExitState();
}

class DoubleBackToExitState extends State<DoubleBackToExit> {
  final _handlers = <bool Function()>[];
  DateTime? _last;

  void addHandler(bool Function() handler) => _handlers.add(handler);

  void removeHandler(bool Function() handler) => _handlers.remove(handler);

  void _onPop(bool didPop, Object? _) {
    if (didPop) return;
    // Kopya üzerinde: işleyici kendini listeden çıkarabilir.
    for (final handler in _handlers.reversed.toList()) {
      if (handler()) return;
    }
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) <= widget.window) {
      SystemNavigator.pop();
      return;
    }
    _last = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: const Text(DoubleBackToExit.message), duration: widget.window));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, onPopInvokedWithResult: _onPop, child: widget.child);
  }
}
