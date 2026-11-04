import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _GetC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

/// libmpv özelliklerini ayrı isolate'ta okur. `mpv_get_property_string` mpv'nin
/// çekirdeğinden yanıt gelene dek bekler; Android'de Dart ana iş parçacığında
/// çalıştığından çekirdek takılınca uygulama donuyor, sistem de kapatıyordu
/// (Philips Google TV'de HEVC bölümde görüldü). Burada takılan yalnız bu isolate
/// olur; arayüz çalışmaya devam eder.
abstract final class MpvProbe {
  /// [names] özelliklerinin değerleri; okunamayan null. [handle] oynatıcının
  /// `mpv_handle` adresi. Çekirdek takılıysa dönmez: çağıran süre koyar.
  static Future<Map<String, String?>> read({
    required String library,
    required int handle,
    required List<String> names,
  }) => Isolate.run(() => _read(library, handle, names));

  static Map<String, String?> _read(String library, int handle, List<String> names) {
    final lib = DynamicLibrary.open(library);
    final get = lib.lookupFunction<_GetC, _GetC>('mpv_get_property_string');
    final free = lib.lookupFunction<_FreeC, _FreeDart>('mpv_free');
    final ctx = Pointer<Void>.fromAddress(handle);
    return {
      for (final name in names)
        name: using((arena) {
          final value = get(ctx, name.toNativeUtf8(allocator: arena));
          if (value == nullptr) return null;
          final text = value.toDartString();
          free(value.cast());
          return text;
        }),
    };
  }
}

/// Oynatıcı çekirdeğini aralıklarla yoklar; yanıt [timeout] içinde gelmezse
/// [onStuck] bir kez çağrılır. Yoklama sürerken yenisi başlamaz.
class EngineWatchdog {
  EngineWatchdog({
    required this.ping,
    required this.onStuck,
    this.period = const Duration(seconds: 4),
    this.timeout = defaultTimeout,
  });

  /// Çekirdek sağlıklıysa kısa sürede tamamlanır.
  final Future<void> Function() ping;
  final void Function() onStuck;
  final Duration period;
  final Duration timeout;

  /// Kısa işler (çözücüyü yeniden kurmak, yeniden bağlanmak) buna yetişir.
  static const defaultTimeout = Duration(seconds: 8);

  Timer? _timer;
  bool _busy = false;
  bool _fired = false;

  void start() {
    _timer ??= Timer.periodic(period, (_) => unawaited(_tick()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_busy || _fired) return;
    _busy = true;
    try {
      await ping().timeout(timeout);
    } on TimeoutException {
      _fired = true;
      stop();
      onStuck();
    } on Object {
      // Okuma hatası takılma değildir (yayın kapanırken olabilir).
    } finally {
      _busy = false;
    }
  }
}
