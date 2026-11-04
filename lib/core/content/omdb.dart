import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:shared_preferences/shared_preferences.dart';

import 'remote_file.dart';
import 'stored_api_key.dart';
import 'tmdb.dart';

/// IMDb puanı OMDb'den (omdbapi.com) gelir; IMDb'nin herkese açık API'si yoktur.
/// OMDb IMDb'nin resmî servisi değildir. Kayıt önce TMDB ile bulunur, IMDb
/// kimliği TMDB'den alınır ([Tmdb.imdbId]). Anahtarı kullanıcı Ayarlar › Veriler'den
/// girer; ücretsiz anahtarda günlük 1000 istek sınırı olduğundan sonuçlar cihazda
/// saklanır.
class Omdb {
  Omdb({required this.apiKey, Future<List<int>> Function(Uri uri)? fetch, DateTime Function()? now})
    : _fetch = fetch ?? ((uri) => fetchBytes(uri, timeout: const Duration(seconds: 10))),
      _now = now ?? DateTime.now;

  final String apiKey;
  final Future<List<int>> Function(Uri uri) _fetch;
  final DateTime Function() _now;

  static final key = StoredApiKey<Omdb>('omdb_anahtar', (k) => Omdb(apiKey: k));

  /// Şu anki OMDb; anahtar girilmediyse null.
  static Omdb? get shared => key.current.value;

  /// Anahtar denemesinde sorulan kayıt (TMDB belgelerindeki örnek film).
  static const _probeId = 'tt0137523';

  static const _prefsKey = 'omdb_onbellek';
  static const _cacheLimit = 1000;

  /// Puan yavaş değişir; bu süreden eskisi yeniden sorulur.
  static const _cacheLife = Duration(days: 30);

  Uri _uri(String imdbId) => Uri.https('www.omdbapi.com', '/', {'i': imdbId, 'apikey': apiKey});

  /// Anahtarı OMDb'ye sorar; saklamaz.
  static Future<ApiKeyCheck> checkKey(String key, {Future<List<int>> Function(Uri uri)? fetch}) async {
    final probe = Omdb(apiKey: key, fetch: fetch);
    try {
      await probe._fetch(probe._uri(_probeId));
      return ApiKeyCheck.valid;
    } on HttpException catch (e) {
      return e.message.contains('401') ? ApiKeyCheck.rejected : ApiKeyCheck.unreachable;
    } on Object {
      return ApiKeyCheck.unreachable;
    }
  }

  /// Kayıt → (puan, sorulduğu an). Puan null: IMDb'de puanı yok.
  Map<String, (double?, int)>? _cache;

  /// Oturumdaki sorgular: aynı kayıt için hep aynı Future döner, sayfa yeniden
  /// çizilince puan satırı titremez.
  final _lookups = <String, Future<double?>>{};

  Future<Map<String, (double?, int)>> _load() async {
    if (_cache case final c?) return c;
    final raw = (await SharedPreferences.getInstance()).getString(_prefsKey);
    final map = <String, (double?, int)>{};
    if (raw != null) {
      try {
        for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map<String, Object?>).entries) {
          final entry = value! as Map<String, Object?>;
          map[key] = ((entry['p'] as num?)?.toDouble(), entry['t']! as int);
        }
      } on Object {
        // Bozuk önbellek: baştan.
      }
    }
    return _cache ??= map;
  }

  Future<void> _save(Map<String, (double?, int)> cache) async {
    while (cache.length > _cacheLimit) {
      cache.remove(cache.keys.first);
    }
    await (await SharedPreferences.getInstance()).setString(
      _prefsKey,
      jsonEncode({
        for (final MapEntry(:key, :value) in cache.entries) key: {'p': value.$1, 't': value.$2},
      }),
    );
  }

  /// Saklanan puanları siler (Ayarlar › Veriler).
  Future<void> clearCache() async {
    _cache = {};
    _lookups.clear();
    await (await SharedPreferences.getInstance()).remove(_prefsKey);
  }

  /// TMDB'de bulunan kaydın IMDb puanı; yoksa ya da ulaşılamazsa null.
  Future<double?> ratingOf(Tmdb tmdb, TmdbInfo info, {required bool series}) {
    final id = '${series ? 'd' : 'f'}:${info.id}';
    return _lookups[id] ??= _rating(id, tmdb, info.id, series);
  }

  Future<double?> _rating(String id, Tmdb tmdb, int tmdbId, bool series) async {
    final cache = await _load();
    final now = _now();
    if (cache[id] case (final rating, final at)
        when now.difference(DateTime.fromMillisecondsSinceEpoch(at)) < _cacheLife) {
      return rating;
    }
    final double? rating;
    try {
      final imdbId = await tmdb.imdbId(tmdbId, series: series);
      rating = imdbId == null ? null : _parse(jsonDecode(utf8.decode(await _fetch(_uri(imdbId)))));
    } on Object {
      // Ağ hatası, sınır ya da geçersiz anahtar: saklanmaz, sonra yeniden denenir.
      _lookups.remove(id);
      return null;
    }
    cache
      ..remove(id)
      ..[id] = (rating, now.millisecondsSinceEpoch);
    unawaited(_save(cache));
    return rating;
  }

  /// `imdbRating` metindir; değer yoksa "N/A".
  static double? _parse(Object? body) => body is Map ? double.tryParse('${body['imdbRating']}') : null;
}
