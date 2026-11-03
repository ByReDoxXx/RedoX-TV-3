import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'live_channel.dart';
import 'local_videos.dart';
import 'm3u_parser.dart';
import 'remote_file.dart';
import 'source_formats.dart';
import 'stalker_client.dart';
import 'xtream_client.dart';

/// Kaynağın türü (kartta rozet; yenileme buna göre).
enum SourceOrigin {
  url('M3U'),
  json('JSON'),
  html('HTML'),
  xtream('Xtream'),
  portal('Portal'),
  bulk('GitHub'),
  file('Dosya'),
  phone('Telefon'),

  /// Cihazdaki klasörün videoları (SSD, USB, SD kart; [LocalVideos]).
  folder('Klasör');

  const SourceOrigin(this.label);

  final String label;
}

/// Kaynağın içeriği (Ayarlar › Kaynak ekle'deki çip): Canlı TV kaynakları
/// Kaynaklar'da, Film kaynakları Film, Dizi kaynakları Dizi bölümünde
/// listelenir (kullanıcı isteği).
enum SourceKind {
  live('Canlı TV'),
  film('Film'),
  series('Dizi');

  const SourceKind(this.label);

  final String label;
}

/// Kullanıcının eklediği liste: bir "klasör" (eski uygulamadaki "Özel M3U").
/// Adresle, hesapla ya da portalla eklenen yenilenebilir.
@immutable
class UserSource {
  const UserSource({
    required this.id,
    required this.name,
    required this.origin,
    required this.count,
    required this.updated,
    this.url,
    this.config = const {},
    this.kind = SourceKind.live,
  });

  factory UserSource.fromJson(Map<String, Object?> j) => UserSource(
    id: j['id']! as String,
    name: j['name']! as String,
    origin: SourceOrigin.values.byName(j['origin']! as String),
    count: j['count']! as int,
    updated: DateTime.parse(j['updated']! as String),
    url: j['url'] as String?,
    config: {for (final MapEntry(:key, :value) in ((j['config'] as Map?) ?? const {}).entries) '$key': '$value'},
    kind: SourceKind.values.asNameMap()[j['kind']] ?? SourceKind.live,
  );

  final String id;
  final String name;
  final SourceOrigin origin;

  /// Kanal sayısı (son okumada).
  final int count;
  final DateTime updated;

  /// Liste adresi (M3U, JSON, HTML, telefondan adres).
  final String? url;

  /// Yenileme bilgisi: Xtream (server, username, password), portal (portal,
  /// mac), klasör (folder: yol). Cihazda, uygulama klasöründe durur.
  final Map<String, String> config;

  /// İçerik: hangi bölümde listelendiği.
  final SourceKind kind;

  bool get refreshable =>
      url != null || origin == SourceOrigin.xtream || origin == SourceOrigin.portal || origin == SourceOrigin.folder;

  UserSource _with({required int count}) => UserSource(
    id: id,
    name: name,
    origin: origin,
    count: count,
    updated: DateTime.now(),
    url: url,
    config: config,
    kind: kind,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'origin': origin.name,
    'count': count,
    'updated': updated.toIso8601String(),
    'url': ?url,
    if (config.isNotEmpty) 'config': config,
    if (kind != SourceKind.live) 'kind': kind.name,
  };
}

class SourceException implements Exception {
  const SourceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Toplu eklemenin sonucu.
typedef BulkResult = ({List<UserSource> added, int failed});

/// Kullanıcının listeleri. Hangi biçimden gelirse gelsin kanallar M3U olarak
/// uygulama klasöründe dosyada durur (büyük olabilir); dizin
/// `kaynaklar.json`'dadır.
class UserSources extends ChangeNotifier {
  UserSources({required this.dir, List<UserSource> items = const [], HeaderFetch? fetch})
    : _items = List.of(items),
      _fetch = fetch ?? ((uri, headers) => fetchBytes(uri, headers: headers));

  /// Listelerin durduğu klasör.
  final Directory dir;
  final List<UserSource> _items;
  final HeaderFetch _fetch;
  final _cache = <String, List<LiveChannel>>{};
  final _portals = <String, StalkerClient>{};

  /// En büyük liste (indirme ve telefondan yükleme sınırı).
  static const maxBytes = 50 * 1024 * 1024;

  /// Toplu eklemede en çok liste.
  static const maxBulk = 50;

  static Future<UserSources> load() async =>
      open(Directory('${(await getApplicationSupportDirectory()).path}/kaynaklar'));

  /// [dir]'deki listeleri açar (yoksa klasörü kurar).
  static Future<UserSources> open(Directory dir, {HeaderFetch? fetch}) async {
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

  /// Türdeki kaynaklar (Kaynaklar: canlı; Film; Dizi).
  List<UserSource> of(SourceKind kind) => [
    for (final s in _items)
      if (s.kind == kind) s,
  ];

  /// Toplam kanal (başlıktaki rozet).
  int get channelCount => _items.fold(0, (n, s) => n + s.count);

  File _file(String id) => File('${dir.path}/$id.m3u');

  /// Listenin kanalları (dosyadan; bellekte tutulur).
  /// Listenin kayıtları. Dosya ayrı bir iş parçacığında okunup ayrıştırılır:
  /// 145 bin filmlik listede ana iş parçacığı Chromecast'te 30 sn'den uzun
  /// meşgul kalıyor, Android uygulamayı "yanıt vermiyor" diye kapatıyordu.
  /// Aynı liste için süren okuma paylaşılır.
  Future<List<LiveChannel>> channels(UserSource s) async {
    final cached = _cache[s.id];
    if (cached != null) return cached;
    final path = _file(s.id).path;
    // Statik işlev ve yalnız yol gönderilir: yerinde yazılan kapanış sürüm
    // derlemesinde nesnenin kendisini (ve ekran ağacını) da taşımaya
    // çalışıp "unsendable" hatası veriyordu (Chromecast'te görüldü).
    final list = await (_reading[s.id] ??= Isolate.run(_ParseFile(path).call).whenComplete(() {
      // Blok gövde: ok işlevi kaldırılan Future'ı döndürür, okuma kendini bekler.
      _reading.remove(s.id);
    }));
    return _cache[s.id] = list;
  }

  final _reading = <String, Future<List<LiveChannel>>>{};

  // ---- Ekleme -------------------------------------------------------------

  /// Adresteki listeyi indirip ekler; biçim içerikten anlaşılır (M3U, JSON,
  /// HTML sayfasındaki yayın bağlantıları).
  Future<UserSource> addUrl(
    String name,
    String url, {
    SourceOrigin origin = SourceOrigin.url,
    SourceKind kind = SourceKind.live,
  }) async {
    final uri = _httpUri(url);
    final text = await _download(uri);
    return _store(
      name,
      SourceFormats.detect(text, base: uri),
      origin: origin,
      url: uri.toString(),
      raw: text,
      kind: kind,
    );
  }

  /// Adresteki listeyi indirip kanallarını verir, Kaynaklar'a eklemez
  /// (Favoriler › Klasörler'e aktarım).
  Future<List<LiveChannel>> fetch(String url) async {
    final uri = _httpUri(url);
    final channels = SourceFormats.detect(await _download(uri), base: uri);
    if (channels.isEmpty) {
      throw const SourceException('Kanal bulunamadı: M3U, JSON ya da yayın bağlantılı HTML değil.');
    }
    return channels;
  }

  /// Metni ekler (dosya, telefon); biçim içerikten anlaşılır.
  Future<UserSource> addText(
    String name,
    String text, {
    required SourceOrigin origin,
    String? url,
    SourceKind kind = SourceKind.live,
  }) => _store(name, SourceFormats.detect(text), origin: origin, url: url, raw: text, kind: kind);

  /// Xtream Codes hesabının canlı kanalları; Film türünde filmleri (VOD),
  /// Dizi türünde dizi bölümlerini.
  Future<UserSource> addXtream(
    String name, {
    required String server,
    required String username,
    required String password,
    SourceKind kind = SourceKind.live,
  }) async {
    final client = XtreamClient(
      server: server,
      username: username,
      password: password,
      fetch: (u) => _fetch(u, const {}),
    );
    return _store(
      name.trim().isEmpty ? Uri.tryParse(client.server)?.host ?? 'Xtream' : name,
      await client.channels(kind),
      origin: SourceOrigin.xtream,
      config: {'server': client.server, 'username': username, 'password': password},
      kind: kind,
    );
  }

  /// Cihazdaki klasörün videoları (takılı SSD, USB bellek, SD kart): alt
  /// klasörleriyle taranır; yenileyince yeni eklenen dosyalar da gelir.
  /// [path] tek bir video da olabilir. Ad boşsa klasörün (dosyanın) adı.
  Future<UserSource> addFolder(String name, String path, {SourceKind kind = SourceKind.film}) async {
    final last = path.split(RegExp(r'[/\\]')).lastWhere((p) => p.isNotEmpty, orElse: () => 'Klasör');
    // Tek video seçildiyse ad uzantısız dosya adı.
    final folder = LocalVideos.isVideo(last) ? last.substring(0, last.lastIndexOf('.')) : last;
    return _store(
      name.trim().isEmpty ? folder : name,
      await LocalVideos.scan(path, kind),
      origin: SourceOrigin.folder,
      config: {'folder': path},
      kind: kind,
    );
  }

  /// MAC/STB portalının canlı kanalları (adresler oynatma anında çözülür).
  Future<UserSource> addPortal(
    String name, {
    required String portal,
    required String mac,
    SourceKind kind = SourceKind.live,
  }) async {
    final id = _newId();
    final client = StalkerClient(portal: portal, mac: mac, fetch: _fetch);
    final channels = await client.liveChannels(id);
    _portals[id] = client;
    final host = Uri.tryParse(portal.contains('://') ? portal : 'http://$portal')?.host;
    return _store(
      name.trim().isEmpty ? host ?? 'Portal' : name,
      channels,
      origin: SourceOrigin.portal,
      config: {'portal': portal.trim(), 'mac': client.mac},
      id: id,
      kind: kind,
    );
  }

  /// Toplu ekleme: GitHub klasörü (`github.com/kullanıcı/depo[/tree/dal/yol]`)
  /// içindeki .m3u/.m3u8 dosyaları ya da satır satır adres içeren bir metin
  /// dosyası. Her liste ayrı klasör olur.
  Future<BulkResult> addBulk(String url, {SourceKind kind = SourceKind.live}) async {
    final uri = _httpUri(url);
    final urls = uri.host == 'github.com' ? await _githubLists(uri) : _lines(await _download(uri));
    if (urls.isEmpty) throw const SourceException('Bu adreste M3U listesi bulunamadı.');
    final added = <UserSource>[];
    var failed = 0;
    for (final (name, u) in urls.take(maxBulk)) {
      try {
        added.add(await addUrl(name, u, origin: SourceOrigin.bulk, kind: kind));
      } on SourceException {
        failed++;
      }
    }
    return (added: added, failed: failed);
  }

  /// GitHub klasöründeki listeler (GitHub içerik arayüzü, oturumsuz).
  Future<List<(String, String)>> _githubLists(Uri uri) async {
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.length < 2) throw const SourceException('GitHub adresi github.com/kullanıcı/depo biçiminde olmalı.');
    final (owner, repo) = (seg[0], seg[1]);
    String? ref;
    var path = '';
    if (seg.length >= 4 && (seg[2] == 'tree' || seg[2] == 'blob')) {
      ref = seg[3];
      path = seg.skip(4).join('/');
    }
    final api = Uri.https('api.github.com', '/repos/$owner/$repo/contents/$path', {'ref': ?ref});
    final Object? body;
    try {
      body = jsonDecode(
        utf8.decode(await _fetch(api, const {'Accept': 'application/vnd.github+json', 'User-Agent': 'RedoXTV'})),
      );
    } on Object {
      throw const SourceException('GitHub klasörü okunamadı (depo açık mı?).');
    }
    final files = body is List ? body : [body];
    final list = RegExp(r'\.m3u8?$', caseSensitive: false);
    return [
      for (final f in files)
        if (f case {'name': final String name, 'download_url': final String dl} when list.hasMatch(name))
          (name.replaceAll(list, ''), dl),
    ];
  }

  static List<(String, String)> _lines(String text) => [
    for (final l in const LineSplitter().convert(text))
      if (l.trim().startsWith('http')) ('', l.trim()),
  ];

  // ---- Yenileme, silme, çözme --------------------------------------------

  Future<UserSource> refresh(UserSource s) async {
    final c = s.config;
    final List<LiveChannel> channels;
    String? raw;
    switch (s.origin) {
      case SourceOrigin.xtream:
        channels = await XtreamClient(
          server: c['server']!,
          username: c['username']!,
          password: c['password']!,
          fetch: (u) => _fetch(u, const {}),
        ).channels(s.kind);
      case SourceOrigin.portal:
        final client = StalkerClient(portal: c['portal']!, mac: c['mac']!, fetch: _fetch);
        channels = await client.liveChannels(s.id);
        _portals[s.id] = client;
      case SourceOrigin.folder:
        channels = await LocalVideos.scan(c['folder']!, s.kind);
      default:
        final url = s.url;
        if (url == null) return s;
        final uri = Uri.parse(url);
        raw = await _download(uri);
        channels = SourceFormats.detect(raw, base: uri);
    }
    if (channels.isEmpty) throw const SourceException('Listede kanal bulunamadı.');
    await _write(s.id, channels, raw);
    final updated = s._with(count: channels.length);
    _items[_items.indexWhere((e) => e.id == s.id)] = updated;
    await _save();
    return updated;
  }

  Future<void> remove(UserSource s) async {
    _items.removeWhere((e) => e.id == s.id);
    _cache.remove(s.id);
    _portals.remove(s.id);
    final f = _file(s.id);
    if (await f.exists()) await f.delete();
    await _save();
  }

  /// Oynatıcının açacağı gerçek adres: portal yer tutucusu `create_link` ile
  /// çözülür, diğerleri olduğu gibi.
  Future<String> resolve(String url) async {
    final parsed = StalkerClient.parse(url);
    if (parsed == null) return url;
    final (id, cmd) = parsed;
    var client = _portals[id];
    if (client == null) {
      final s = _items.where((e) => e.id == id).firstOrNull;
      if (s == null) throw const SourceException('Portal kaynağı silinmiş.');
      client = _portals[id] = StalkerClient(portal: s.config['portal']!, mac: s.config['mac']!, fetch: _fetch);
    }
    return client.link(cmd);
  }

  // ---- Yardımcılar -------------------------------------------------------

  static Uri _httpUri(String url) {
    var t = url.trim();
    if (!t.contains('://')) t = 'http://$t';
    final uri = Uri.tryParse(t);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw const SourceException('Adres http:// ya da https:// ile başlamalı.');
    }
    return uri;
  }

  Future<String> _download(Uri uri) async {
    final List<int> bytes;
    try {
      bytes = await _fetch(uri, const {});
    } on Object catch (e) {
      throw SourceException('Liste indirilemedi ($e).');
    }
    if (bytes.length > maxBytes) throw const SourceException('Liste çok büyük (en çok 50 MB).');
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<UserSource> _store(
    String name,
    List<LiveChannel> channels, {
    required SourceOrigin origin,
    String? url,
    String? raw,
    Map<String, String> config = const {},
    String? id,
    SourceKind kind = SourceKind.live,
  }) async {
    if (channels.isEmpty) {
      throw const SourceException('Kanal bulunamadı: M3U, JSON ya da yayın bağlantılı HTML değil.');
    }
    final s = UserSource(
      id: id ?? _newId(),
      name: _name(name, url),
      origin: origin,
      count: channels.length,
      updated: DateTime.now(),
      url: url,
      config: config,
      kind: kind,
    );
    await _write(s.id, channels, raw);
    _items.add(s);
    await _save();
    return s;
  }

  /// M3U ise metnin kendisi, değilse kanallardan üretilen M3U saklanır.
  Future<void> _write(String id, List<LiveChannel> channels, String? raw) async {
    final m3u = raw != null && raw.contains('#EXTINF') ? raw : SourceFormats.toM3u(channels);
    await _file(id).writeAsString(m3u);
    _cache[id] = channels;
  }

  /// Ad boşsa adresin dosya adı ya da "Liste N".
  String _name(String name, String? url) {
    final t = name.trim();
    if (t.isNotEmpty) return t;
    final last = url == null ? '' : Uri.parse(url).pathSegments.lastWhere((p) => p.isNotEmpty, orElse: () => '');
    return last.isNotEmpty
        ? last.replaceAll(RegExp(r'\.(m3u8?|json|html?)$', caseSensitive: false), '')
        : 'Liste ${_items.length + 1}';
  }

  static String _newId() {
    final r = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}${r.nextInt(1 << 20)}';
  }

  /// Yedek (Ayarlar › Veriler): dizin ve her listenin M3U metni.
  Future<Map<String, Object?>> exportData() async => {
    'dizin': [for (final s in _items) s.toJson()],
    'listeler': {
      for (final s in _items)
        if (await _file(s.id).exists()) s.id: await _file(s.id).readAsString(),
    },
  };

  /// Yedeği geri yükler: eldeki listelerin yerine yedektekiler geçer.
  /// [merge]: eldekiler kalır, yedekte olup burada olmayan listeler eklenir.
  Future<void> importData(Map<String, Object?> data, {bool merge = false}) async {
    final index = [for (final j in data['dizin'] as List? ?? const []) UserSource.fromJson(j as Map<String, Object?>)];
    final texts = (data['listeler'] as Map?)?.cast<String, Object?>() ?? const {};
    if (merge) {
      final have = {for (final s in _items) s.id};
      for (final s in index) {
        if (have.contains(s.id)) continue;
        if (texts[s.id] case final String text) await _file(s.id).writeAsString(text);
        _items.add(s);
      }
      await _save();
      return;
    }
    for (final s in _items) {
      final f = _file(s.id);
      if (await f.exists()) await f.delete();
    }
    for (final s in index) {
      if (texts[s.id] case final String text) await _file(s.id).writeAsString(text);
    }
    _items
      ..clear()
      ..addAll(index);
    _cache.clear();
    _portals.clear();
    await _save();
  }

  Future<void> _save() async {
    await File('${dir.path}/kaynaklar.json').writeAsString(jsonEncode([for (final s in _items) s.toJson()]));
    notifyListeners();
  }
}

/// Ayrı iş parçacığında liste dosyasını okuyup ayrıştırır (yalnız yolu taşır).
class _ParseFile {
  const _ParseFile(this.path);

  final String path;

  List<LiveChannel> call() {
    final f = File(path);
    return f.existsSync() ? M3uParser.parse(f.readAsStringSync()) : const [];
  }
}
