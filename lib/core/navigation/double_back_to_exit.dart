import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout/form_factor.dart';

/// Kök sayfada Geri: ilk basışta uyarı, [window] içinde ikinci basışta
/// uygulamadan çıkılır (kullanıcı isteği: Geri doğrudan çıkmasın).
///
/// Alt ağaçtaki bir bileşen Geri'yi önce kendisi işlemek isterse (ör. yazma
/// kipindeki arama kutusu) [DoubleBackToExitState.addHandler] ile kaydolur.
/// Geri'de son kaydolan önce sorulur; `true` dönen Geri'yi tüketir.
/// (Flutter 3.47'de `didPopRoute` gözlemcileri kayıt sırasıyla sorulur ve
/// Navigator önce gelir; bu yüzden ayrı gözlemci işe yaramaz.)
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({super.key, required this.child, this.window = const Duration(seconds: 2), this.onBack});

  final Widget child;
  final Duration window;

  /// Kayıtlı işleyicilerden sonra, çıkış uyarısından önce sorulur; `true`
  /// Geri'yi tüketir (ör. kök kabuk: başka bölümdeyken Anasayfa'ya döner).
  final bool Function()? onBack;

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
    if (widget.onBack?.call() ?? false) return;
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) <= widget.window) {
      // SystemNavigator.pop masaüstünde uygulamayı kapatmaz.
      if (FormFactor.current == FormFactor.desktop) {
        unawaited(ServicesBinding.instance.exitApplication(AppExitType.required));
      } else {
        SystemNavigator.pop();
      }
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

/// Geri'yi sayfanın önce işlemesi (ör. alt klasörden üst klasöre, ayar
/// bölümünden bölüm listesine): [active] iken Geri [onBack]'i çağırır ve
/// tüketilir. Kök kabuğun içindeyse [DoubleBackToExit]'e kaydolur; kendi
/// PopScope'u olsaydı kabuğun Geri'si de çalışır, sayfa Anasayfa'ya dönerdi
/// (Pixel'de görüldü). Kabuk dışındaki rotada (açılan sayfa) PopScope kullanır.
class BackInterceptor extends StatefulWidget {
  const BackInterceptor({super.key, required this.active, required this.onBack, required this.child});

  final bool active;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<BackInterceptor> createState() => _BackInterceptorState();
}

class _BackInterceptorState extends State<BackInterceptor> {
  DoubleBackToExitState? _shell;
  bool _looked = false;

  bool _handle() {
    if (!widget.active) return false;
    widget.onBack();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_looked) return;
    _looked = true;
    _shell = DoubleBackToExit.maybeOf(context)?..addHandler(_handle);
  }

  @override
  void dispose() {
    _shell?.removeHandler(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shell != null) return widget.child;
    return PopScope(
      canPop: !widget.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active) widget.onBack();
      },
      child: widget.child,
    );
  }
}
