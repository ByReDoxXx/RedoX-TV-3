import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_channel.dart';
import 'remote_file.dart';

/// TMDB'de bulunan film ya da dizi.
class TmdbInfo {
  const TmdbInfo({
    required this.id,
    required this.title,
    this.overview = '',
    this.year,
    this.rating,
    this.posterPath,
    this.backdropPath,
    this.originalTitle,
  });

  factory TmdbInfo.fromJson(Map<String, Object?> j) => TmdbInfo(
    id: j['id'] as int,
    title: '${j['title'] ?? j['name'] ?? ''}',
    overview: '${j['overview'] ?? ''}',
    year: int.tryParse('${j['release_date'] ?? j['first_air_date'] ?? ''}'.split('-').first),
    rating: switch (j['vote_average']) {
      final num v when v > 0 => v.toDouble(),
      _ => null,
    },
    posterPath: j['poster_path'] as String?,
    backdropPath: j['backdrop_path'] as String?,
    originalTitle: (j['original_title'] ?? j['original_name']) as String?,
  );

  final int id;
  final String title;

  /// Özgün ad (yabancı filmde listedeki ad çoğu kez budur).
  final String? originalTitle;
  final String overview;
  final int? year;

  /// TMDB puanı (0–10); oy yoksa null.
  final double? rating;
  final String? posterPath;
  final String? backdropPath;

  static const _images = 'https://image.tmdb.org/t/p';

  String? get poster => posterPath == null ? null : '$_images/w342$posterPath';
  String? get backdrop => backdropPath == null ? null : '$_images/w1280$backdropPath';

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'overview': overview,
    'release_date': ?year?.toString(),
    'vote_average': ?rating,
    'poster_path': ?posterPath,
    'backdrop_path': ?backdropPath,
    'original_title': ?originalTitle,
  };
}

/// Girilen TMDB anahtarının denetim sonucu.
enum TmdbKeyCheck {
  valid,

  /// TMDB anahtarı reddetti (HTTP 401).
  rejected,

  /// Ağ yok ya da TMDB yanıt vermedi; anahtar denenemedi.
  unreachable,
}

/// TMDB (themoviedb.org): Film ve Dizi kayıtlarının afişi, arka planı, özeti,
/// yılı ve puanı (kullanıcı isteği: "TMDB ve IMDB desteği"). Kayıt adı
/// sadeleştirilip ([cleanName]) Türkçe aranır; ilk sonuç alınır. Sonuçlar
/// (bulunamayanlar da) cihazda saklanır, aynı ad yeniden sorulmaz.
///
/// Anahtarı kullanıcı Ayarlar › Veriler'den girer; cihazda saklanır, uygulamaya
/// gömülmez (kullanıcı isteği: "açık kalmasın"; gömülü anahtar APK'dan
/// çıkarılabiliyordu). Girilmediyse TMDB kapalıdır ([shared] null). İki tür
/// kabul edilir: API Read Access Token (Bearer) ve 32 haneli API anahtarı
/// (`api_key`).
class Tmdb {
  Tmdb({required this.token, Future<List<int>> Function(Uri uri, Map<String, String> headers)? fetch})
    : _fetch = fetch ?? ((uri, headers) => fetchBytes(uri, headers: headers, timeout: const Duration(seconds: 10)));

  final String token;
  final Future<List<int>> Function(Uri uri, Map<String, String> headers) _fetch;

  /// Uygulamanın TMDB'si; anahtar girilince ya da kaldırılınca değişir.
  static final current = ValueNotifier<Tmdb?>(null);

  /// Şu anki TMDB; anahtar girilmediyse null.
  static Tmdb? get shared => current.value;

  /// Anahtarın cihazdaki adı. Yedeğe yazılmaz (Backup).
  static const keyPref = 'tmdb_anahtar';

  /// Cihazdaki anahtarı yükler (main.dart).
  static Future<void> loadKey() async {
    final key = (await SharedPreferences.getInstance()).getString(keyPref);
    current.value = key == null || key.isEmpty ? null : Tmdb(token: key);
  }

  /// Anahtarı saklar ve hemen kullanır; null kaldırır (TMDB kapanır).
  static Future<void> setKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove(keyPref);
      current.value = null;
    } else {
      await prefs.setString(keyPref, key);
      current.value = Tmdb(token: key);
    }
  }

  /// Anahtarı TMDB'ye sorar; saklamaz.
  static Future<TmdbKeyCheck> checkKey(
    String key, {
    Future<List<int>> Function(Uri uri, Map<String, String> headers)? fetch,
  }) async {
    try {
      await Tmdb(token: key, fetch: fetch)._get('/3/authentication', const {});
      return TmdbKeyCheck.valid;
    } on HttpException catch (e) {
      return e.message.contains('401') ? TmdbKeyCheck.rejected : TmdbKeyCheck.unreachable;
    } on Object {
      return TmdbKeyCheck.unreachable;
    }
  }

  static final _shortKey = RegExp(r'^[0-9a-fA-F]{32}$');

  /// TMDB isteği; anahtar türüne göre sorguda ya da başlıkta gider.
  Future<List<int>> _get(String path, Map<String, String> query) {
    final short = _shortKey.hasMatch(token);
    return _fetch(Uri.https('api.themoviedb.org', path, {...query, if (short) 'api_key': token}), {
      if (!short) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });
  }

  static const _prefsKey = 'tmdb_onbellek';
  static const _cacheLimit = 1000;

  /// Ad → bilgi (null: TMDB'de yok). Ekleme sırasıyla; sınır aşılınca en eski
  /// düşer.
  Map<String, TmdbInfo?>? _cache;
  final _pending = <String, Future<TmdbInfo?>>{};

  Future<Map<String, TmdbInfo?>> _load() async {
    if (_cache case final c?) return c;
    final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
    final map = <String, TmdbInfo?>{};
    if (raw != null) {
      try {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map<String, Object?>).entries) {
          map[key] = value == null ? null : TmdbInfo.fromJson(value as Map<String, Object?>);
        }
      } on Object {
        // Bozuk önbellek: baştan.
      }
    }
    return _cache ??= map;
  }

  Future<void> _save(Map<String, TmdbInfo?> cache) async {
    while (cache.length > _cacheLimit) {
      cache.remove(cache.keys.first);
    }
    await (await SharedPreferences.getInstance()).setString(
      _prefsKey,
      jsonEncode({for (final e in cache.entries) e.key: e.value?.toJson()}),
    );
  }

  /// Saklanan film/dizi bilgilerini siler (Ayarlar › Veriler); sonraki
  /// açılışta yeniden sorulur.
  Future<void> clearCache() async {
    _cache = {};
    await (await SharedPreferences.getInstance()).remove(_prefsKey);
  }

  /// Saklanan ad sayısı (bulunamayanlar dahil); önbellek yüklenmediyse cihazdan.
  Future<int> cacheSize() async => (await _load()).length;

  /// TMDB'nin önerdiği benzer yapımlar (recommendations); ağ yoksa boş.
  /// Oturum boyunca bellekte tutulur.
  Future<List<TmdbInfo>> similar(TmdbInfo info, {required bool series}) =>
      _similar['${series ? 'd' : 'f'}:${info.id}'] ??= _fetchSimilar(info.id, series);

  final _similar = <String, Future<List<TmdbInfo>>>{};

  Future<List<TmdbInfo>> _fetchSimilar(int id, bool series) async {
    try {
      final body = jsonDecode(
        utf8.decode(await _get('/3/${series ? 'tv' : 'movie'}/$id/recommendations', const {'language': 'tr-TR'})),
      );
      final results = body is Map ? body['results'] : null;
      return [
        if (results is List)
          for (final r in results)
            if (r is Map<String, Object?> && r['id'] is int) TmdbInfo.fromJson(r),
      ];
    } on Object {
      return const [];
    }
  }

  /// Benzerlerden listede olanlar (oynatılabilenler), TMDB sırasıyla: ad
  /// sadeleştirilip ([cleanName]) Türkçe ya da özgün adla eşlenir.
  static Future<List<(TmdbInfo, LiveChannel)>> inLibrary(List<TmdbInfo> similar, List<LiveChannel> library) async {
    if (similar.isEmpty) return const [];
    final byName = await _index(library);
    return [
      for (final s in similar)
        if (byName[matchKey(s.title)] ?? byName[matchKey(s.originalTitle ?? '')] case final c?) (s, c),
    ];
  }

  /// Listenin ad dizini (eşleme anahtarı → kayıt); liste başına bir kez
  /// kurulur. Büyük listede anahtarlar ayrı isolate'ta çıkarılır: on binlerce
  /// adın sadeleştirilmesi Chromecast'te ana iş parçacığını saniyelerce
  /// kilitliyordu (ANR).
  static Future<Map<String, LiveChannel>> _index(List<LiveChannel> library) => _indexes[library] ??= () async {
    final names = [for (final c in library) c.name];
    final keys = names.length < isolateThreshold ? _keysOf(names) : await _keysInIsolate(names);
    final byName = <String, LiveChannel>{};
    for (var i = 0; i < keys.length; i++) {
      byName.putIfAbsent(keys[i], () => library[i]);
    }
    return byName;
  }();

  static List<String> _keysOf(List<String> names) => [for (final n in names) matchKey(cleanName(n).$1)];

  /// Ayrı işlev: isolate'a yalnız adlar gider (kayıtlar kopyalanmaz).
  static Future<List<String>> _keysInIsolate(List<String> names) => Isolate.run(() => _keysOf(names));

  static final _indexes = Expando<Future<Map<String, LiveChannel>>>();

  /// Bu sayıdan kısa listenin dizini ana iş parçacığında kurulur.
  static const isolateThreshold = 2000;

  /// Eşleme anahtarı: küçük harf, yalnız harf ve rakam ("Yüzüklerin
  /// Efendisi: Kralın Dönüşü" → "yüzüklerinefendisikralındönüşü").
  static String matchKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  /// Kayıt adının TMDB karşılığı; bulunamazsa ya da ağ yoksa null.
  Future<TmdbInfo?> find(String name, {required bool series}) {
    final key = '${series ? 'd' : 'f'}:${name.trim().toLowerCase()}';
    // Blok gövde: ok işlevi kaldırılan Future'ı döndürür, whenComplete onu
    // (kendini) bekler ve hiç bitmez.
    return _pending[key] ??= _find(key, name, series).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<TmdbInfo?> _find(String key, String name, bool series) async {
    final cache = await _load();
    if (cache.containsKey(key)) return cache[key];
    final (query, year) = cleanName(name);
    if (query.isEmpty) return null;
    final Object? body;
    try {
      body = jsonDecode(
        utf8.decode(
          await _get('/3/search/${series ? 'tv' : 'movie'}', {
            'query': query,
            'language': 'tr-TR',
            if (year != null) series ? 'first_air_date_year' : 'year': '$year',
          }),
        ),
      );
    } on Object {
      // Ağ hatası: önbelleğe yazılmaz, sonra yeniden denenir.
      return null;
    }
    final results = body is Map ? body['results'] : null;
    final first = results is List && results.isNotEmpty ? results.first : null;
    final info = first is Map<String, Object?> ? TmdbInfo.fromJson(first) : null;
    cache[key] = info;
    unawaited(_save(cache));
    return info;
  }

  static final _bracketed = RegExp(r'[\[({][^\])}]*[\])}]');
  static final _year = RegExp(r'(?:^|\s)((?:19|20)\d{2})(?=\s|$)');

  /// Dil/kaynak öneki: "TR:", "|TR|", "┃MULTI┃", "[NL]" (dikey çizgi ASCII ya da kutu çizgisi).
  static final _prefix = RegExp(r'^(?:[A-Z]{2,3}\s*[:|\-]\s*|[|┃│\[][A-Z0-9 /+-]{2,20}[|┃│\]]\s*)+');

  /// Kalite ve dil etiketleri (küçük harfle; kelime kelime atılır).
  static const _noise = {
    '4k', 'uhd', 'fhd', 'hd', 'sd', 'hdr', '1080p', '720p', '2160p', 'hevc', 'x264', 'x265', 'h264', 'h265', //
    'webdl', 'web-dl', 'bluray', 'dual', 'altyazılı', 'altyazili', 'dublaj', 'tr', 'multi', 'sdr', '-',
  };

  /// IPTV kayıt adından arama metni ve yıl: "TR: Başlangıç (2010) [4K]" →
  /// ("Başlangıç", 2010). Dil öneki, köşeli/yuvarlak ayraçlar, kalite ve dil
  /// etiketleri atılır; nokta ve alt çizgi boşluk olur.
  static (String, int?) cleanName(String raw) {
    var s = raw.trim().replaceFirst(_prefix, '');
    int? year;
    for (final m in RegExp(r'\(((?:19|20)\d{2})\)').allMatches(s)) {
      year = int.parse(m.group(1)!);
    }
    s = s.replaceAll(_bracketed, ' ').replaceAll(RegExp('[._]'), ' ');
    final bare = _year.allMatches(s).lastOrNull;
    // Ad yalnız yıldan oluşmuyorsa ("1917" filmi) yıl ayrılır.
    if (bare != null && s.replaceRange(bare.start, bare.end, '').trim().isNotEmpty) {
      year ??= int.parse(bare.group(1)!);
      s = s.replaceRange(bare.start, bare.end, ' ');
    }
    s = s
        .replaceAll(RegExp('türkçe dublaj', caseSensitive: false), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => !_noise.contains(w.toLowerCase()))
        .join(' ');
    s = s.replaceAll(RegExp(r'^[\s\-|:]+|[\s\-|:]+$'), '');
    return (s, year);
  }
}
