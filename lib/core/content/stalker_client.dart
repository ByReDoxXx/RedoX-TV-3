import 'dart:convert';

import 'live_channel.dart';
import 'user_sources.dart';

/// İstek: adres ve başlıklar → yanıt baytları.
typedef HeaderFetch = Future<List<int>> Function(Uri uri, Map<String, String> headers);

/// MAC/STB portal (Stalker ara katmanı; MAG kutularının portalı). Protokol,
/// açık kaynak skerit/stbroker istemcisinden doğrulandı:
/// - `…/server/load.php?type=stb&action=handshake&JsHttpRequest=1-xml`,
///   çerez `mac=…; stb_lang=en; timezone=…` → `js.token`.
/// - Sonraki isteklerde `Authorization: Bearer <token>`; önce `get_profile`.
/// - `type=itv&action=get_genres` ve `get_all_channels` → `js.data`
///   (id, name, number, cmd, logo, tv_genre_id).
/// - Oynatma anında `type=itv&action=create_link&cmd=…` → `js.cmd`
///   ("ffmpeg http://…"; baştaki sözcük atılır). Bağlantılar kısa ömürlüdür:
///   kanal adresi kayıtta [streamPrefix] + kaynak + cmd olarak durur, oynatıcı
///   açmadan önce [UserSources.resolve] ile çözer.
class StalkerClient {
  StalkerClient({required String portal, required String mac, required this.fetch})
    : portal = portal.trim(),
      mac = mac.trim().toUpperCase();

  final String portal;
  final String mac;
  final HeaderFetch fetch;

  static const streamPrefix = 'stalker:';
  static const _userAgent =
      'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';

  /// `00:1A:79:12:34:56` biçimi.
  static final macPattern = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$');

  Uri? _endpoint;
  String? _token;

  Map<String, String> get _headers => {
    'User-Agent': _userAgent,
    'X-User-Agent': 'Model: MAG254; Link: WiFi',
    'Cookie': 'mac=${Uri.encodeComponent(mac)}; stb_lang=en; timezone=${Uri.encodeComponent('Europe/Istanbul')}',
    if (_token case final t?) 'Authorization': 'Bearer $t',
  };

  /// Portal adresinden olası `load.php` adresleri: `…/c/` biçimi
  /// (`…/stalker_portal/c/`), kök ve `portal.php`.
  List<Uri> _candidates() {
    var t = portal;
    if (!t.startsWith('http://') && !t.startsWith('https://')) t = 'http://$t';
    final u = Uri.parse(t);
    final origin = '${u.scheme}://${u.authority}';
    var path = u.path.replaceAll(RegExp(r'/c/?$'), '').replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('.php')) return [u.replace(query: '')];
    return {
      Uri.parse('$origin$path/server/load.php'),
      Uri.parse('$origin/stalker_portal/server/load.php'),
      Uri.parse('$origin/portal.php'),
    }.toList();
  }

  Future<Object?> _call(Uri endpoint, String type, String action, [Map<String, String> params = const {}]) async {
    final uri = endpoint.replace(
      queryParameters: {'type': type, 'action': action, ...params, 'JsHttpRequest': '1-xml'},
    );
    final text = utf8.decode(await fetch(uri, _headers), allowMalformed: true);
    if (text.contains('Authorization failed')) throw const SourceException('Portal yetki vermedi (MAC kayıtlı mı?).');
    final body = jsonDecode(text);
    return body is Map ? body['js'] : null;
  }

  /// El sıkışma ve profil; başarısızsa [SourceException].
  Future<void> connect() async {
    if (!macPattern.hasMatch(mac)) throw const SourceException('MAC adresi 00:1A:79:12:34:56 biçiminde olmalı.');
    for (final endpoint in _candidates()) {
      try {
        _token = null;
        final js = await _call(endpoint, 'stb', 'handshake');
        final token = js is Map ? js['token'] : null;
        if (token is! String || token.isEmpty) continue;
        _token = token;
        _endpoint = endpoint;
        await _call(endpoint, 'stb', 'get_profile', const {
          'hd': '1',
          'stb_type': 'MAG254',
          'num_banks': '1',
          'image_version': '218',
          'hw_version': '2.6-IB-00',
          'auth_second_step': '0',
          'not_valid_token': '0',
        });
        return;
      } on SourceException {
        rethrow;
      } on Object {
        // Sıradaki olası adres.
      }
    }
    throw const SourceException('Portal bulunamadı ya da yanıt vermedi (adres doğru mu?).');
  }

  /// Canlı kanallar; adresleri [sourceId]'li yer tutucudur.
  Future<List<LiveChannel>> liveChannels(String sourceId) async {
    if (_endpoint == null) await connect();
    final endpoint = _endpoint!;
    final genres = await _call(endpoint, 'itv', 'get_genres');
    final names = {
      if (genres is List)
        for (final g in genres)
          if (g is Map) '${g['id']}': '${g['title'] ?? 'Genel'}',
    };
    final js = await _call(endpoint, 'itv', 'get_all_channels');
    final data = js is Map ? js['data'] : null;
    if (data is! List) return const [];
    final out = <LiveChannel>[];
    for (final c in data) {
      if (c is! Map || c['cmd'] == null) continue;
      final number = int.tryParse('${c['number']}') ?? out.length + 1;
      final logo = '${c['logo'] ?? ''}';
      out.add(
        LiveChannel(
          name: '${c['name'] ?? 'Kanal $number'}'.trim(),
          number: number,
          category: names['${c['tv_genre_id']}'] ?? 'Genel',
          logoUrl: logo.startsWith('http') ? logo : null,
          streams: [placeholder(sourceId, '${c['cmd']}')],
        ),
      );
    }
    return out;
  }

  static String placeholder(String sourceId, String cmd) =>
      '$streamPrefix$sourceId:${base64Url.encode(utf8.encode(cmd))}';

  /// Yer tutucudan (kaynak, cmd).
  static (String, String)? parse(String url) {
    if (!url.startsWith(streamPrefix)) return null;
    final rest = url.substring(streamPrefix.length);
    final i = rest.indexOf(':');
    if (i < 0) return null;
    return (rest.substring(0, i), utf8.decode(base64Url.decode(rest.substring(i + 1))));
  }

  /// Oynatma anında gerçek adres (`create_link`).
  Future<String> link(String cmd) async {
    if (_endpoint == null) await connect();
    final js = await _call(_endpoint!, 'itv', 'create_link', {'cmd': cmd, 'disable_ad': '0', 'forced_storage': '0'});
    final out = js is Map ? '${js['cmd'] ?? ''}' : '';
    final url = out.replaceFirst(RegExp(r'^\w+\s+(?=\w+://)'), '').trim();
    if (!url.contains('://')) throw const SourceException('Portal yayın adresi vermedi.');
    return url;
  }
}
