import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'live_channel.dart';
import 'm3u_parser.dart';
import 'remote_file.dart';

/// Kaynağın nereden geldiği (kartta rozet).
enum SourceOrigin {
  url('Adres'),
  file('Dosya'),
  phone('Telefon');

  const SourceOrigin(this.label);

  final String label;
}

/// Kullanıcının eklediği M3U listesi: bir "klasör" (eski uygulamadaki
/// "Özel M3U"). Adresle eklenen yenilenebilir.
@immutable
class UserSource {
  const UserSource({
    required this.id,
    required this.name,
    required this.origin,
    required this.count,
    required this.updated,
    this.url,
  });

  factory UserSource.fromJson(Map<String, Object?> j) => UserSource(
    id: j['id']! as String,
    name: j['name']! as String,
    origin: SourceOrigin.values.byName(j['origin']! as String),
    count: j['count']! as int,
    updated: DateTime.parse(j['updated']! as String),
    url: j['url'] as String?,
  );

  final String id;
  final String name;
  final SourceOrigin origin;

  /// Kanal sayısı (son okumada).
  final int count;
  final DateTime updated;

  /// Liste adresi (adresle ya da telefondan adresle eklendiyse).
  final String? url;

  bool get refreshable => url != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'origin': origin.name,
    'count': count,
    'updated': updated.toIso8601String(),
    'url': ?url,
  };
}

class SourceException implements Exception {
  const SourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Kullanıcının M3U listeleri. Listelerin metni uygulama klasöründe dosya
/// olarak durur (büyük olabilir), dizin `kaynaklar.json`'dadır.
class UserSources extends ChangeNotifier {
  UserSources({required this.dir, List<UserSource> items = const [], Future<List<int>> Function(Uri)? fetch})
    : _items = List.of(items),
      _fetch = fetch ?? fetchBytes;

  /// Listelerin durduğu klasör.
  final Directory dir;
  final List<UserSource> _items;
  final Future<List<int>> Function(Uri) _fetch;
  final _cache = <String, List<LiveChannel>>{};

  /// En büyük liste (telefondan yükleme ve indirme sınırı).
  static const maxBytes = 50 * 1024 * 1024;

  static Future<UserSources> load() async =>
      open(Directory('${(await getApplicationSupportDirectory()).path}/kaynaklar'));

  /// [dir]'deki listeleri açar (yoksa klasörü kurar).
  static Future<UserSources> open(Directory dir, {Future<List<int>> Function(Uri)? fetch}) async {
    await dir.create(recursive: true);
    return UserSources(dir: dir, items: await _readIndex(dir), fetch: fetch);
  }

  static Future<List<UserSource>> _readIndex(Directory dir) async {
    final f = File('${dir.path}/kaynaklar.json');
    if (!await f.exists()) return const [];
    try {
      return [
        for (final j in jsonDecode(await f.readAsString()) as List) UserSource.fromJson(j as Map<String, Object?>),
      ];
    } on Object {
      return const [];
    }
  }

  List<UserSource> get items => List.unmodifiable(_items);

  /// Toplam kanal (başlıktaki rozet).
  int get channelCount => _items.fold(0, (n, s) => n + s.count);

  File _file(String id) => File('${dir.path}/$id.m3u');

  /// Listenin kanalları (dosyadan; bellekte tutulur).
  Future<List<LiveChannel>> channels(UserSource s) async {
    final cached = _cache[s.id];
    if (cached != null) return cached;
    final f = _file(s.id);
    if (!await f.exists()) return const [];
    return _cache[s.id] = M3uParser.parse(await f.readAsString());
  }

  /// Adresteki listeyi indirip ekler.
  Future<UserSource> addUrl(String name, String url, {SourceOrigin origin = SourceOrigin.url}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw const SourceException('Adres http:// ya da https:// ile başlamalı.');
    }
    return addText(name, await _download(uri), origin: origin, url: uri.toString());
  }

  /// M3U metnini ekler (dosya, telefon).
  Future<UserSource> addText(String name, String text, {required SourceOrigin origin, String? url}) async {
    final channels = _validate(text);
    final s = UserSource(
      id: _newId(),
      name: _name(name, url),
      origin: origin,
      count: channels.length,
      updated: DateTime.now(),
      url: url,
    );
    await _file(s.id).writeAsString(text);
    _cache[s.id] = channels;
    _items.add(s);
    await _save();
    return s;
  }

  /// Adresle eklenen listeyi yeniden indirir.
  Future<UserSource> refresh(UserSource s) async {
    final url = s.url;
    if (url == null) return s;
    final text = await _download(Uri.parse(url));
    final channels = _validate(text);
    await _file(s.id).writeAsString(text);
    _cache[s.id] = channels;
    final updated = UserSource(
      id: s.id,
      name: s.name,
      origin: s.origin,
      count: channels.length,
      updated: DateTime.now(),
      url: url,
    );
    _items[_items.indexWhere((e) => e.id == s.id)] = updated;
    await _save();
    return updated;
  }

  Future<void> remove(UserSource s) async {
    _items.removeWhere((e) => e.id == s.id);
    _cache.remove(s.id);
    final f = _file(s.id);
    if (await f.exists()) await f.delete();
    await _save();
  }

  Future<String> _download(Uri uri) async {
    final List<int> bytes;
    try {
      bytes = await _fetch(uri);
    } on Object catch (e) {
      throw SourceException('Liste indirilemedi ($e).');
    }
    if (bytes.length > maxBytes) throw const SourceException('Liste çok büyük (en çok 50 MB).');
    return utf8.decode(bytes, allowMalformed: true);
  }

  static List<LiveChannel> _validate(String text) {
    final channels = text.contains('#EXTINF') ? M3uParser.parse(text) : const <LiveChannel>[];
    if (channels.isEmpty) throw const SourceException('Geçerli bir M3U listesi değil (kanal bulunamadı).');
    return channels;
  }

  /// Ad boşsa adresin dosya adı ya da "Liste N".
  String _name(String name, String? url) {
    final t = name.trim();
    if (t.isNotEmpty) return t;
    final last = url == null ? '' : Uri.parse(url).pathSegments.lastWhere((p) => p.isNotEmpty, orElse: () => '');
    return last.isNotEmpty
        ? last.replaceAll(RegExp(r'\.m3u8?$', caseSensitive: false), '')
        : 'Liste ${_items.length + 1}';
  }

  static String _newId() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}${r.nextInt(1 << 20)}';
  }

  Future<void> _save() async {
    await File('${dir.path}/kaynaklar.json').writeAsString(jsonEncode([for (final s in _items) s.toJson()]));
    notifyListeners();
  }
}
