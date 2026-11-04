import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'channel_folder.dart';
import 'live_channel.dart';
import 'user_sources.dart';

/// Eski favorinin kaynak listesinde bulunan bilgileri.
typedef FavoriteOrigin = ({SourceKind kind, String sourceId, String category});

/// Kaynaklardan favoriye eklenen kayıt: ad, yayın adresi, logo (kullanıcının
/// listesindeki kanal, film ya da dizi bölümü). Kimliği adresidir. [kind]
/// Favoriler'deki sekmesini belirler; bu alan yokken eklenenlerde null'dur.
@immutable
class FavoriteItem {
  const FavoriteItem({required this.name, required this.url, this.logo, this.kind, this.sourceId, this.category});

  factory FavoriteItem.of(LiveChannel c, {required SourceKind kind, String? sourceId}) => FavoriteItem(
    name: c.name,
    url: c.streams.first,
    logo: c.logoUrl,
    kind: kind,
    sourceId: sourceId,
    category: c.category,
  );

  static FavoriteItem? fromJson(Object? j) => switch (j) {
    {'ad': final String name, 'adres': final String url} => FavoriteItem(
      name: name,
      url: url,
      logo: j['logo'] as String?,
      kind: SourceKind.values.asNameMap()[j['tur']],
      sourceId: j['kaynak'] as String?,
      category: j['grup'] as String?,
    ),
    _ => null,
  };

  final String name;
  final String url;
  final String? logo;
  final SourceKind? kind;

  /// Geldiği liste (dizi kilidi için).
  final String? sourceId;

  /// Listedeki grubu (adında sezon/bölüm olmayan dizi bu adla toplanır).
  final String? category;

  /// Sekmesi: kayıtlı tür, yoksa addan ve adresten tahmin.
  SourceKind get resolvedKind => kind ?? guessKind(name, url);

  static final _filmUrl = RegExp(r'/movie/|\.(mp4|mkv|avi|mov)(\?|$)', caseSensitive: false);

  /// Türü kayıtlı olmayan favori: bölüm adı ya da Xtream `/series/` dizi,
  /// `/movie/` ya da video dosyası film, gerisi canlı TV.
  static SourceKind guessKind(String name, String url) {
    if (ChannelFolder.parseEpisode(name) != null || url.contains('/series/')) return SourceKind.series;
    if (_filmUrl.hasMatch(url)) return SourceKind.film;
    return SourceKind.live;
  }

  FavoriteItem withOrigin(FavoriteOrigin o) =>
      FavoriteItem(name: name, url: url, logo: logo, kind: o.kind, sourceId: o.sourceId, category: o.category);

  Map<String, Object?> toJson() => {
    'ad': name,
    'adres': url,
    'logo': ?logo,
    'tur': ?kind?.name,
    'kaynak': ?sourceId,
    'grup': ?category,
  };

  @override
  bool operator ==(Object other) => other is FavoriteItem && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Bir profilin favorileri: TV kanalları ve radyo istasyonları (numaralar) ve
/// Kaynaklar'dan eklenen kayıtlar (türüne göre Televizyon, Film ya da Dizi
/// sekmesinde), ekleme (ya da kullanıcının) sırasıyla.
/// Cihazda saklanır.
class Favorites extends ChangeNotifier {
  Favorites({
    List<int> channels = const [],
    List<int> radios = const [],
    List<FavoriteItem> sources = const [],
    this.onSave,
  }) : _channels = List.of(channels),
       _radios = List.of(radios),
       _sources = List.of(sources);

  final List<int> _channels;
  final List<int> _radios;
  final List<FavoriteItem> _sources;
  final Future<void> Function(Favorites)? onSave;

  static const _kChannels = 'favori_kanal';
  static const _kRadios = 'favori_radyo';
  static const _kSources = 'favori_kaynak';

  /// Eski "Klasörler" sekmesinin ağacı: ilk açılışta kayıtları [sources]'a
  /// taşınır.
  static const _kOldFolders = 'favori_klasor';

  /// Cihazdaki favoriler: dönen işlev profilin favorilerini verir (aynı
  /// profil için hep aynı nesne).
  static Future<Favorites Function(String profileId)> load() async {
    final prefs = await SharedPreferences.getInstance();
    List<int> read(String key) => [for (final s in prefs.getStringList(key) ?? const <String>[]) ?int.tryParse(s)];
    List<FavoriteItem> sources(String id) {
      final saved = prefs.getStringList('${_kSources}_$id');
      if (saved != null) return [for (final s in saved) ?_decode(s)];
      return migrateFolders(prefs.getString('${_kOldFolders}_$id'));
    }

    final cache = <String, Favorites>{};
    _loaded = cache;
    return (id) => cache[id] ??= Favorites(
      channels: read('${_kChannels}_$id'),
      radios: read('${_kRadios}_$id'),
      sources: sources(id),
      onSave: (f) async {
        await prefs.setStringList('${_kChannels}_$id', [for (final n in f._channels) '$n']);
        await prefs.setStringList('${_kRadios}_$id', [for (final n in f._radios) '$n']);
        await prefs.setStringList('${_kSources}_$id', [for (final i in f._sources) jsonEncode(i.toJson())]);
      },
    );
  }

  /// [load]'un açtığı profillerin favorileri (silinen kaynağın kayıtlarını
  /// hepsinden kaldırmak için).
  static Map<String, Favorites>? _loaded;

  /// Kaynak silindi: kayıtları bütün profillerin favorilerinden kalkar
  /// (kullanıcı isteği: "Kaynaklardan bir şey silinirse dizi ve filmlerden de
  /// silinsin"). Açık profiller bellekte, açılmamışlar cihazda temizlenir.
  static Future<void> forgetEverywhere(Set<String> urls) async {
    if (urls.isEmpty) return;
    final open = _loaded ?? const {};
    for (final f in open.values) {
      f.forgetSources(urls);
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('${_kSources}_') || open.containsKey(key.substring(_kSources.length + 1))) continue;
      final saved = prefs.getStringList(key) ?? const <String>[];
      final kept = [
        for (final s in saved)
          if (_decode(s) case final i? when !urls.contains(i.url)) s,
      ];
      if (kept.length != saved.length) await prefs.setStringList(key, kept);
    }
  }

  /// Bu profilin favorilerinden [urls] kayıtlarını kaldırır.
  void forgetSources(Set<String> urls) {
    final before = _sources.length;
    _sources.removeWhere((i) => urls.contains(i.url));
    if (_sources.length != before) _changed();
  }

  static FavoriteItem? _decode(String s) {
    try {
      return FavoriteItem.fromJson(jsonDecode(s));
    } on FormatException {
      return null;
    }
  }

  /// Eski klasör ağacının (JSON) bütün kayıtları, ağaç sırasıyla, tekrarsız.
  static List<FavoriteItem> migrateFolders(String? json) {
    if (json == null) return const [];
    final out = <FavoriteItem>{};
    void walk(Object? node) {
      if (node is! Map) return;
      for (final i in node['kayitlar'] as List? ?? const []) {
        if (FavoriteItem.fromJson(i) case final item?) out.add(item);
      }
      for (final f in node['klasorler'] as List? ?? const []) {
        walk(f);
      }
    }

    try {
      walk(jsonDecode(json));
    } on FormatException {
      return const [];
    }
    return out.toList();
  }

  List<int> get channels => List.unmodifiable(_channels);
  List<int> get radios => List.unmodifiable(_radios);
  List<FavoriteItem> get sources => List.unmodifiable(_sources);

  bool hasChannel(int number) => _channels.contains(number);
  bool hasRadio(int number) => _radios.contains(number);
  bool hasSource(String url) => _sources.any((i) => i.url == url);

  void toggleChannel(int number) => _toggle(_channels, number);
  void toggleRadio(int number) => _toggle(_radios, number);
  void toggleSource(FavoriteItem item) => _toggle(_sources, item);

  /// Sıralama (Favoriler sayfası): kaydı [to] konumuna taşır.
  void moveChannel(int number, int to) => _move(_channels, number, to);
  void moveRadio(int number, int to) => _move(_radios, number, to);

  /// Kaydı kendi türünün listesinde [to] konumuna taşır.
  void moveSource(String url, int to) {
    final i = _sources.indexWhere((s) => s.url == url);
    if (i < 0) return;
    final item = _sources[i];
    final same = sourcesOf(item.resolvedKind);
    final from = same.indexOf(item);
    final target = to.clamp(0, same.length - 1);
    if (from == target) return;
    final anchor = same[target];
    _sources.remove(item);
    final at = _sources.indexOf(anchor);
    _sources.insert(target > from ? at + 1 : at, item);
    _changed();
  }

  /// [kind] türündeki kayıtları [urls] sırasına dizer (Film ve Dizi'de
  /// sürükle-bırak); diğer türlerin yeri değişmez. Listede olmayan adres atlanır.
  void reorderSources(SourceKind kind, List<String> urls) {
    final byUrl = {for (final i in sourcesOf(kind)) i.url: i};
    final ordered = [...urls.map((u) => byUrl[u]).nonNulls];
    if (ordered.length != byUrl.length) return;
    var next = 0;
    for (final (i, item) in _sources.indexed) {
      if (item.resolvedKind == kind) _sources[i] = ordered[next++];
    }
    _changed();
  }

  /// [kind] türündeki kaynak favorileri.
  List<FavoriteItem> sourcesOf(SourceKind kind) => [
    for (final i in _sources)
      if (i.resolvedKind == kind) i,
  ];

  /// [kind] türündeki kaynak favorileri oynatıcı listesi olarak (numara sırası).
  List<LiveChannel> sourceChannels(SourceKind kind) => [
    for (final (i, item) in sourcesOf(kind).indexed)
      LiveChannel(
        name: item.name,
        number: i + 1,
        category: item.category ?? kind.label,
        streams: [item.url],
        logoUrl: item.logo,
      ),
  ];

  /// Türü kayıtlı olmayan favorilerin adresleri.
  Set<String> get unclassified => {
    for (final i in _sources)
      if (i.kind == null) i.url,
  };

  /// Eski favorilere kaynak listesinde bulunan bilgileri işler. [complete]:
  /// bütün listeler okundu; bulunamayanların türü tahminle kalıcı olur.
  void classify(Map<String, FavoriteOrigin> found, {required bool complete}) {
    var changed = false;
    for (final (i, item) in _sources.indexed) {
      if (item.kind != null) continue;
      final origin = found[item.url];
      if (origin != null) {
        _sources[i] = item.withOrigin(origin);
      } else if (complete) {
        _sources[i] = item.withOrigin((
          kind: item.resolvedKind,
          sourceId: item.sourceId ?? 'favori',
          category: item.category ?? item.resolvedKind.label,
        ));
      } else {
        continue;
      }
      changed = true;
    }
    if (changed) _changed();
  }

  void _toggle<T>(List<T> list, T value) {
    if (!list.remove(value)) list.add(value);
    _changed();
  }

  void _move<T>(List<T> list, T value, int to) {
    if (!list.remove(value)) return;
    list.insert(to.clamp(0, list.length), value);
    _changed();
  }

  void _changed() {
    notifyListeners();
    unawaited(onSave?.call(this));
  }
}
