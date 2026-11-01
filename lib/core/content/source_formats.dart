import 'dart:convert';

import 'live_channel.dart';
import 'm3u_parser.dart';

/// Kaynak biçimleri: metinden kanal listesi. Hepsi sonunda M3U olarak
/// saklanır ([toM3u]); klasör içi ve oynatıcı tek biçimle çalışır.
abstract final class SourceFormats {
  /// İçeriğe bakarak biçimi seçer: M3U (#EXTM3U/#EXTINF), JSON (`[`/`{`),
  /// yoksa HTML (sayfadaki yayın bağlantıları).
  static List<LiveChannel> detect(String text, {Uri? base}) {
    final t = text.trimLeft();
    if (t.contains('#EXTINF')) return M3uParser.parse(text);
    if (t.startsWith('[') || t.startsWith('{')) return json(text);
    return html(text, base: base);
  }

  static const _listKeys = ['channels', 'items', 'streams', 'data', 'list', 'playlist', 'results'];
  static const _nameKeys = ['name', 'title', 'channel', 'channel_name', 'label'];
  static const _urlKeys = ['url', 'stream', 'stream_url', 'streamUrl', 'link', 'src', 'file', 'uri', 'urls', 'streams'];
  static const _logoKeys = ['logo', 'tvg-logo', 'tvg_logo', 'icon', 'image', 'thumbnail', 'stream_icon'];
  static const _groupKeys = ['group', 'group-title', 'group_title', 'category', 'genre', 'categoryName'];

  /// JSON kanal listesi: dizi ya da [_listKeys]'ten birinde dizi; öğede ad,
  /// adres (tek ya da dizi: yedek akışlar), logo, kategori alanları
  /// (yaygın adlarıyla). Adresi olmayan öğe atlanır.
  static List<LiveChannel> json(String text) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const [];
    }
    final items = _findList(root);
    final out = <LiveChannel>[];
    for (final item in items) {
      if (item is! Map) continue;
      final streams = [for (final k in _urlKeys) ..._urls(item[k])].where(_isStream).toSet().toList();
      if (streams.isEmpty) continue;
      final name = _first(item, _nameKeys) ?? 'Kanal ${out.length + 1}';
      out.add(
        LiveChannel(
          name: name,
          number: out.length + 1,
          category: _first(item, _groupKeys) ?? 'Genel',
          logoUrl: _first(item, _logoKeys),
          streams: List.unmodifiable(streams),
        ),
      );
    }
    return out;
  }

  static List<Object?> _findList(Object? root) {
    if (root is List) return root;
    if (root is Map) {
      for (final k in _listKeys) {
        if (root[k] case final List<Object?> l) return l;
      }
      for (final v in root.values) {
        if (v is List && v.isNotEmpty && v.first is Map) return v;
      }
    }
    return const [];
  }

  static Iterable<String> _urls(Object? v) sync* {
    if (v is String) yield v.trim();
    if (v is List) {
      for (final e in v) {
        if (e is String) yield e.trim();
        if (e is Map) yield* _urls(e['url'] ?? e['src'] ?? e['link']);
      }
    }
  }

  static String? _first(Map<Object?, Object?> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] case final String v when v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static bool _isStream(String u) => u.startsWith('http://') || u.startsWith('https://') || u.startsWith('rtmp');

  static final _streamLink = RegExp(
    r'''(?:https?:)?//[^\s"'<>]+?\.(?:m3u8|ts|mpd|mp4)(?:\?[^\s"'<>]*)?''',
    caseSensitive: false,
  );

  /// Öznitelikteki (href, src, data-src, file) göreli ya da tam yayın adresi.
  static final _attrLink = RegExp(
    r'''(?:href|src|data-src|file)\s*=\s*["']([^"'\s]+?\.(?:m3u8|ts|mpd|mp4)(?:\?[^"'\s]*)?)["']''',
    caseSensitive: false,
  );
  static final _anchor = RegExp(
    r'''<a\b[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );
  static final _tags = RegExp(r'<[^>]+>');

  /// HTML sayfasındaki yayın bağlantıları (.m3u8, .ts, .mpd, .mp4): bağlantı
  /// metni varsa ad odur, yoksa dosya adı. Aynı adres bir kez.
  static List<LiveChannel> html(String text, {Uri? base}) {
    final names = <String, String>{};
    for (final m in _anchor.allMatches(text)) {
      final label = m.group(2)!.replaceAll(_tags, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (label.isNotEmpty) names[_absolute(m.group(1)!, base)] = label;
    }
    final seen = <String>{};
    final out = <LiveChannel>[];
    final found = [
      for (final m in _attrLink.allMatches(text)) m.group(1)!,
      for (final m in _streamLink.allMatches(text)) m.group(0)!,
    ];
    for (final raw in found) {
      final url = _absolute(raw.replaceAll('&amp;', '&'), base);
      if (!seen.add(url)) continue;
      final file = Uri.tryParse(url)?.pathSegments.lastWhere((p) => p.isNotEmpty, orElse: () => '') ?? '';
      out.add(
        LiveChannel(
          name: names[url] ?? (file.isEmpty ? 'Yayın ${out.length + 1}' : file.replaceAll(RegExp(r'\.\w+$'), '')),
          number: out.length + 1,
          category: 'Sayfa',
          streams: [url],
        ),
      );
    }
    return out;
  }

  static String _absolute(String url, Uri? base) {
    if (url.startsWith('//')) return 'https:$url';
    if (base == null || url.startsWith('http')) return url;
    return base.resolve(url).toString();
  }

  /// Kanallardan M3U (saklama biçimi). Akış başına bir kayıt; aynı tvg-id
  /// yedek akışları bir kanalda toplar.
  static String toM3u(List<LiveChannel> channels) {
    final b = StringBuffer('#EXTM3U\n');
    for (final c in channels) {
      final logo = c.logoUrl == null ? '' : ' tvg-logo="${_attr(c.logoUrl!)}"';
      for (final s in c.streams) {
        b
          ..write('#EXTINF:-1 tvg-id="ch${c.number}" tvg-chno="${c.number}"$logo ')
          ..write('group-title="${_attr(c.category)}",${c.name.replaceAll('\n', ' ')}\n')
          ..write('$s\n');
      }
    }
    return b.toString();
  }

  static String _attr(String v) => v.replaceAll('"', "'");
}
