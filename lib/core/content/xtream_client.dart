import 'dart:convert';

import 'live_channel.dart';
import 'user_sources.dart';

/// Xtream Codes hesabı: `player_api.php` (hesap, canlı kategoriler ve canlı
/// yayınlar). Kanal adresi `sunucu/live/kullanıcı/şifre/<stream_id>.<biçim>`;
/// biçim hesabın izin verdiği ilk biçim (`allowed_output_formats`, yoksa ts).
class XtreamClient {
  XtreamClient({required String server, required this.username, required this.password, required this.fetch})
    : server = _normalize(server);

  /// `http://alan:port` (sonda / yok).
  final String server;
  final String username;
  final String password;
  final Future<List<int>> Function(Uri) fetch;

  static String _normalize(String s) {
    var t = s.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) t = 'http://$t';
    t = t.replaceAll(RegExp(r'/+(player_api\.php|get\.php|c)?/?$'), '');
    return t.endsWith('/') ? t.substring(0, t.length - 1) : t;
  }

  Uri _api([Map<String, String> extra = const {}]) =>
      Uri.parse('$server/player_api.php')
          .replace(queryParameters: {'username': username, 'password': password, ...extra});

  Future<Object?> _get(Map<String, String> extra) async {
    final List<int> bytes;
    try {
      bytes = await fetch(_api(extra));
    } on Object catch (e) {
      throw SourceException('Sunucuya ulaşılamadı ($e).');
    }
    try {
      return jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException {
      throw const SourceException('Sunucu Xtream yanıtı vermedi (adres doğru mu?).');
    }
  }

  /// Hesabı doğrular ve canlı kanalları döner (kategori adlarıyla).
  Future<List<LiveChannel>> liveChannels() async {
    final info = await _get(const {});
    final user = info is Map ? info['user_info'] : null;
    if (user is! Map || '${user['auth']}' != '1') {
      throw const SourceException('Hesap doğrulanamadı: kullanıcı adı ya da şifre yanlış.');
    }
    final formats = user['allowed_output_formats'];
    final ext = formats is List && formats.isNotEmpty ? '${formats.first}' : 'ts';
    final cats = await _get(const {'action': 'get_live_categories'});
    final names = {
      if (cats is List)
        for (final c in cats)
          if (c is Map) '${c['category_id']}': '${c['category_name'] ?? 'Genel'}',
    };
    final streams = await _get(const {'action': 'get_live_streams'});
    if (streams is! List) return const [];
    final out = <LiveChannel>[];
    for (final s in streams) {
      if (s is! Map || s['stream_id'] == null) continue;
      final number = int.tryParse('${s['num']}') ?? out.length + 1;
      final logo = '${s['stream_icon'] ?? ''}';
      out.add(
        LiveChannel(
          name: '${s['name'] ?? 'Kanal $number'}'.trim(),
          number: number,
          category: names['${s['category_id']}'] ?? 'Genel',
          logoUrl: logo.startsWith('http') ? logo : null,
          streams: ['$server/live/$username/$password/${s['stream_id']}.$ext'],
        ),
      );
    }
    return out;
  }
}
