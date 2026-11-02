import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'remote_host.dart';
import 'remote_key.dart';

/// Yerel ağda bulunan bir TV; eşleşince [token] dolar.
class RemoteTv {
  const RemoteTv({required this.name, required this.host, required this.port, this.token});

  factory RemoteTv.fromJson(Map<String, Object?> j) => RemoteTv(
    name: j['ad'] as String,
    host: j['adres'] as String,
    port: j['port'] as int,
    token: j['anahtar'] as String?,
  );

  final String name;
  final String host;
  final int port;
  final String? token;

  RemoteTv withToken(String token) => RemoteTv(name: name, host: host, port: port, token: token);

  Map<String, Object?> toJson() => {'ad': name, 'adres': host, 'port': port, 'anahtar': ?token};
}

/// Eşleşme kodu tutmadı.
class RemoteCodeException implements Exception {
  const RemoteCodeException();
}

/// Telefon kumandasının telefon tarafı: TV'leri bulur, eşleşir, bağlanır
/// ([RemoteHost] ile konuşur). Testlerde alt sınıfla değiştirilir.
class RemoteClient {
  const RemoteClient({this.discoveryPort = RemoteHost.defaultDiscoveryPort, this.broadcast});

  final int discoveryPort;

  /// Yayın adresi; null ise bütün yerel ağ (255.255.255.255).
  final InternetAddress? broadcast;

  static const _prefsKey = 'kumanda_tv';
  static const _timeout = Duration(seconds: 3);

  /// Son eşleşilen TV (açılışta doğrudan bağlanılır).
  Future<RemoteTv?> saved() async {
    final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
    if (raw == null) return null;
    try {
      return RemoteTv.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> save(RemoteTv? tv) async {
    final prefs = await SharedPreferences.getInstance();
    if (tv == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(tv.toJson()));
    }
  }

  /// [wait] boyunca yanıt veren TV'ler (adrese göre tekil).
  Future<List<RemoteTv>> discover({Duration wait = const Duration(seconds: 2)}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final found = <String, RemoteTv>{};
    final sub = socket.listen((e) {
      if (e != RawSocketEvent.read) return;
      final d = socket.receive();
      if (d == null) return;
      try {
        final j = jsonDecode(utf8.decode(d.data)) as Map<String, Object?>;
        final host = d.address.address;
        found[host] = RemoteTv(name: j['ad'] as String, host: host, port: j['port'] as int);
      } on Object {
        // Başka bir uygulamanın yanıtı.
      }
    });
    final probe = utf8.encode(RemoteHost.probe);
    final target = broadcast ?? InternetAddress('255.255.255.255');
    // UDP kaybolabilir: iki kez sorulur.
    socket.send(probe, target, discoveryPort);
    await Future<void>.delayed(wait ~/ 3);
    socket.send(probe, target, discoveryPort);
    await Future<void>.delayed(wait - wait ~/ 3);
    await sub.cancel();
    socket.close();
    return found.values.toList();
  }

  Future<Map<String, Object?>> _post(RemoteTv tv, Map<String, String> query) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final req = await client.postUrl(
        Uri(scheme: 'http', host: tv.host, port: tv.port, path: '/eslestir', queryParameters: query),
      );
      final res = await req.close().timeout(_timeout);
      final body = await utf8.decodeStream(res).timeout(_timeout);
      if (res.statusCode == HttpStatus.forbidden) throw const RemoteCodeException();
      if (res.statusCode != HttpStatus.ok) throw HttpException('HTTP ${res.statusCode}');
      return jsonDecode(body) as Map<String, Object?>;
    } finally {
      client.close(force: true);
    }
  }

  /// TV ekranında eşleşme kodunu gösterir.
  Future<void> requestCode(RemoteTv tv) => _post(tv, const {});

  /// Kod tutarsa anahtarlı TV; tutmazsa [RemoteCodeException].
  Future<RemoteTv> pair(RemoteTv tv, String code) async {
    final j = await _post(tv, {'kod': code});
    return tv.withToken(j['anahtar'] as String);
  }

  /// Tuş kanalı. Anahtar geçersizse [WebSocketException].
  Future<RemoteConnection> connect(RemoteTv tv) async {
    final socket = await WebSocket.connect(
      Uri(
        scheme: 'ws',
        host: tv.host,
        port: tv.port,
        path: '/kumanda',
        queryParameters: {'anahtar': tv.token ?? ''},
      ).toString(),
    ).timeout(_timeout);
    socket.pingInterval = const Duration(seconds: 5);
    return RemoteConnection(socket);
  }
}

/// TV'ye açık tuş kanalı.
class RemoteConnection {
  RemoteConnection(this._socket) {
    _socket.listen(null, onDone: _done.complete, onError: (Object _) {}, cancelOnError: false);
  }

  final WebSocket _socket;
  final _done = Completer<void>();

  /// Bağlantı kapanınca tamamlanır.
  Future<void> get done => _done.future;

  void send(RemoteKey key) => _socket.add(key.name);

  /// Telefon klavyesi: TV'de açık yazı kutusuna yazılır.
  void type(String text) => _socket.add('${RemoteHost.textPrefix}$text');

  Future<void> close() => _socket.close();
}
