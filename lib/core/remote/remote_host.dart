import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_key.dart';

/// Telefon kumandasının TV tarafı (kullanıcı isteği: "telefonda kumanda").
/// Yerel ağda iki kapı açar:
/// - **UDP [discoveryPort]:** telefonun "TV var mı?" yayınına ([probe]) TV'nin
///   adı ve HTTP kapısıyla yanıt verir.
/// - **HTTP [port]:** `POST /eslestir` TV ekranında 4 haneli kod gösterir
///   ([pairingCode]); `POST /eslestir?kod=…` kod tutarsa kalıcı anahtar verir;
///   `GET /kumanda?anahtar=…` WebSocket: her ileti bir tuş adıdır
///   ([RemoteKey]) ya da `metin:` önekli yazıdır (telefon klavyesi).
///
/// Güvenlik: tuş göndermek için anahtar gerekir; anahtar yalnız TV ekranındaki
/// kodu bilen cihaza verilir. Kod 2 dakika geçerlidir, yanlış kod 5 denemede
/// iptal olur.
class RemoteHost {
  RemoteHost({
    required this.onKey,
    required this.name,
    this.onText,
    Set<String> tokens = const {},
    this.saveTokens,
    this.port = defaultPort,
    this.discoveryPort = defaultDiscoveryPort,
  }) : _tokens = Set.of(tokens);

  static const defaultPort = 47810;
  static const defaultDiscoveryPort = 47811;

  /// Telefonun yayın iletisi.
  static const probe = 'REDOX-KUMANDA?';

  /// TV'nin adı (telefondaki listede; Ayarlar › Telefon kumandası'ndan
  /// değişir, sonraki aramada görünür).
  String name;
  final void Function(RemoteKey key) onKey;

  /// Telefon klavyesinden yazı ([textPrefix] ile gelen ileti).
  final void Function(String text)? onText;

  /// Yazı iletisinin öneki; gerisi yazılan metindir.
  static const textPrefix = 'metin:';
  final Future<void> Function(Set<String> tokens)? saveTokens;
  final int port;
  final int discoveryPort;
  final Set<String> _tokens;

  HttpServer? _http;
  RawDatagramSocket? _udp;
  final _sockets = <WebSocket>{};

  /// Ekranda gösterilecek eşleşme kodu; yoksa null.
  final pairingCode = ValueNotifier<String?>(null);

  /// Bağlı telefon sayısı.
  final connected = ValueNotifier<int>(0);

  Timer? _codeTimer;
  int _wrong = 0;

  /// Dinlenen HTTP kapısı (açıldıktan sonra).
  int? get boundPort => _http?.port;

  /// Dinlenen bulma kapısı (açıldıktan sonra; kapı doluysa null).
  int? get boundDiscoveryPort => _udp?.port;

  static const _prefsKey = 'kumanda_anahtarlar';
  static const _nameKey = 'kumanda_ad';

  /// Eşleşmiş telefon sayısı.
  int get pairedCount => _tokens.length;

  /// Kullanıcının verdiği ad; yoksa null.
  static Future<String?> loadName() async => (await SharedPreferences.getInstance()).getString(_nameKey);

  /// Adı değiştirir ve saklar.
  Future<void> rename(String value) async {
    name = value;
    await (await SharedPreferences.getInstance()).setString(_nameKey, value);
  }

  /// Telefondaki listede görünen ad: cihazın ağ adı; Android çoğunlukla
  /// "localhost" verir, o zaman "RedoX TV" (yanında adres de görünür).
  static String deviceName() {
    final host = Platform.localHostname;
    return host.isEmpty || host == 'localhost' ? 'RedoX TV' : host;
  }

  /// Eşleşmiş telefonların anahtarları (cihazda saklanır).
  static Future<Set<String>> loadTokens() async =>
      ((await SharedPreferences.getInstance()).getStringList(_prefsKey) ?? const []).toSet();

  static Future<void> storeTokens(Set<String> tokens) async =>
      (await SharedPreferences.getInstance()).setStringList(_prefsKey, tokens.toList());

  Future<void> start() async {
    _http = await _bind(port);
    unawaited(_http!.forEach(_handle));
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _udp = udp;
      udp.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = udp.receive();
        if (d == null || utf8.decode(d.data, allowMalformed: true) != probe) return;
        udp.send(utf8.encode(jsonEncode({'ad': name, 'port': _http!.port})), d.address, d.port);
      });
    } on SocketException {
      // Kapı doluysa bulma çalışmaz; telefon adresle bağlanabilir.
    }
  }

  static Future<HttpServer> _bind(int port) async {
    try {
      return await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      return HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
  }

  Future<void> stop() async {
    _codeTimer?.cancel();
    for (final s in _sockets.toList()) {
      await s.close();
    }
    _udp?.close();
    await _http?.close(force: true);
    _http = null;
    _udp = null;
  }

  /// Eşleşmeleri unutur (bağlı telefonlar da düşer).
  Future<void> forget() async {
    _tokens.clear();
    await saveTokens?.call(_tokens);
    for (final s in _sockets.toList()) {
      await s.close(WebSocketStatus.policyViolation);
    }
  }

  static String _random(int length, String chars) {
    final r = Random.secure();
    return String.fromCharCodes([for (var i = 0; i < length; i++) chars.codeUnitAt(r.nextInt(chars.length))]);
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final q = req.uri.queryParameters;
    try {
      switch ((req.method, req.uri.path)) {
        case ('POST', '/eslestir') when q['kod'] == null:
          _showCode();
          res.write(jsonEncode({'ad': name}));
        case ('POST', '/eslestir'):
          final code = pairingCode.value;
          if (code != null && q['kod'] == code) {
            final token = _random(24, 'abcdefghijkmnpqrstuvwxyz23456789');
            _tokens.add(token);
            await saveTokens?.call(_tokens);
            _hideCode();
            res.write(jsonEncode({'anahtar': token, 'ad': name}));
          } else {
            if (code != null && ++_wrong >= 5) _hideCode();
            res.statusCode = HttpStatus.forbidden;
            res.write(jsonEncode({'hata': 'Kod yanlış.'}));
          }
        case ('GET', '/kumanda') when WebSocketTransformer.isUpgradeRequest(req):
          if (!_tokens.contains(q['anahtar'])) {
            res.statusCode = HttpStatus.forbidden;
            break;
          }
          final socket = await WebSocketTransformer.upgrade(req);
          _sockets.add(socket);
          connected.value = _sockets.length;
          socket.listen(
            (m) {
              if (m case final String text when text.startsWith(textPrefix)) {
                onText?.call(text.substring(textPrefix.length));
              } else if (m case final String name) {
                if (RemoteKey.byName(name) case final key?) onKey(key);
              }
            },
            onDone: () {
              _sockets.remove(socket);
              connected.value = _sockets.length;
            },
          );
          return;
        default:
          res.statusCode = HttpStatus.notFound;
      }
    } on Object {
      res.statusCode = HttpStatus.internalServerError;
    }
    await res.close();
  }

  void _showCode() {
    _wrong = 0;
    pairingCode.value = _random(4, '0123456789');
    _codeTimer?.cancel();
    _codeTimer = Timer(const Duration(minutes: 2), _hideCode);
  }

  void _hideCode() {
    _codeTimer?.cancel();
    pairingCode.value = null;
  }
}
