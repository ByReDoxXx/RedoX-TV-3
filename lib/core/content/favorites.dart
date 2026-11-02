import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_channel.dart';

/// Kaynaklardan favoriye eklenen kayıt: ad, yayın adresi, logo (kullanıcının
/// listesindeki kanal, film ya da dizi bölümü). Kimliği adresidir.
@immutable
class FavoriteItem {
  const FavoriteItem({required this.name, required this.url, this.logo});

  factory FavoriteItem.of(LiveChannel c) => FavoriteItem(name: c.name, url: c.streams.first, logo: c.logoUrl);

  static FavoriteItem? fromJson(Object? j) => switch (j) {
    {'ad': final String name, 'adres': final String url} => FavoriteItem(
      name: name,
      url: url,
      logo: j['logo'] as String?,
    ),
    _ => null,
  };

  final String name;
  final String url;
  final String? logo;

  Map<String, Object?> toJson() => {'ad': name, 'adres': url, 'logo': ?logo};

  @override
  bool operator ==(Object other) => other is FavoriteItem && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Bir profilin favorileri: TV kanalları ve radyo istasyonları (numaralar) ve
/// Kaynaklar'dan eklenen kayıtlar, ekleme (ya da kullanıcının) sırasıyla.
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
  /// taşınır (kullanıcı isteği: klasörler Kaynaklar'da; sekme kaldırıldı).
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
  void moveSource(String url, int to) {
    final i = _sources.indexWhere((s) => s.url == url);
    if (i >= 0) _move(_sources, _sources[i], to);
  }

  /// Kaynak favorileri oynatıcı listesi olarak (numara sırası).
  List<LiveChannel> get sourceChannels => [
    for (final (i, item) in _sources.indexed)
      LiveChannel(name: item.name, number: i + 1, category: 'Kaynaklar', streams: [item.url], logoUrl: item.logo),
  ];

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
