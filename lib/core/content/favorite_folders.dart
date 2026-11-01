import 'package:flutter/foundation.dart';

import 'live_channel.dart';
import 'm3u_parser.dart';

/// Favori klasöründeki kayıt: ad, yayın adresi, logo (listeden aktarılan
/// dizi bölümü, film ya da kanal).
@immutable
class FavoriteItem {
  const FavoriteItem({required this.name, required this.url, this.logo});

  factory FavoriteItem.fromJson(Map<String, Object?> j) =>
      FavoriteItem(name: j['ad']! as String, url: j['adres']! as String, logo: j['logo'] as String?);

  final String name;
  final String url;
  final String? logo;

  Map<String, Object?> toJson() => {'ad': name, 'adres': url, 'logo': ?logo};

  @override
  bool operator ==(Object other) => other is FavoriteItem && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);
}

/// Favori klasörü: alt klasörler ve kayıtlar (iç içe; kullanıcı isteği:
/// "Dizi İsmi/1.Sezon/Bölüm01"). Kök klasörün adı boştur.
class FavoriteFolder {
  FavoriteFolder(this.name, {List<FavoriteFolder>? folders, List<FavoriteItem>? items})
    : folders = folders ?? [],
      items = items ?? [];

  factory FavoriteFolder.fromJson(Map<String, Object?> j) => FavoriteFolder(
    j['ad'] as String? ?? '',
    folders: [for (final f in j['klasorler'] as List? ?? const []) FavoriteFolder.fromJson((f as Map).cast())],
    items: [for (final i in j['kayitlar'] as List? ?? const []) FavoriteItem.fromJson((i as Map).cast())],
  );

  String name;
  final List<FavoriteFolder> folders;
  final List<FavoriteItem> items;

  /// Alt klasörler dahil kayıt sayısı.
  int get total => items.length + folders.fold(0, (n, f) => n + f.total);

  bool get isEmpty => folders.isEmpty && items.isEmpty;

  FavoriteFolder? child(String name) => folders.where((f) => f.name == name).firstOrNull;

  /// Adı verilen alt klasör; yoksa kurulur.
  FavoriteFolder ensure(String name) {
    if (child(name) case final f?) return f;
    final made = FavoriteFolder(name);
    folders.add(made);
    return made;
  }

  /// Klasördeki kayıtlar oynatıcı listesi olarak (numara sırası).
  List<LiveChannel> get channels => [
    for (final (i, item) in items.indexed)
      LiveChannel(name: item.name, number: i + 1, category: name, streams: [item.url], logoUrl: item.logo),
  ];

  Map<String, Object?> toJson() => {
    'ad': name,
    if (folders.isNotEmpty) 'klasorler': [for (final f in folders) f.toJson()],
    if (items.isNotEmpty) 'kayitlar': [for (final i in items) i.toJson()],
  };

  /// Kanal listesini klasörlere yerleştirir. Yol: grup adı (`group-title`)
  /// ve kanal adı "/" ile bölünür, son parça kaydın adıdır: "Dizi İsmi/1.Sezon"
  /// grubundaki "Bölüm01" ya da grupsuz "Dizi İsmi/1.Sezon/Bölüm01" → Dizi
  /// İsmi › 1.Sezon › Bölüm01. Grubu olmayan ve adında yol bulunmayan kayıt bu
  /// klasöre girer. Aynı ad ve adresli kayıt
  /// tekrar eklenmez; en çok [limit] kayıt eklenir. Döner: eklenen kayıt.
  int import(List<LiveChannel> channels, {int limit = 5000}) {
    var added = 0;
    for (final c in channels) {
      if (added >= limit) break;
      if (c.streams.isEmpty) continue;
      // Grubu olmayan kanal ("Diğer") klasör açmaz.
      final group = c.category == M3uParser.noGroup ? '' : c.category;
      final parts = [..._split(group), ..._split(c.name)];
      if (parts.isEmpty) continue;
      var folder = this;
      for (final p in parts.take(parts.length - 1)) {
        folder = folder.ensure(p);
      }
      final item = FavoriteItem(name: parts.last, url: c.streams.first, logo: c.logoUrl);
      if (folder.items.contains(item)) continue;
      folder.items.add(item);
      added++;
    }
    return added;
  }

  static List<String> _split(String s) => [
    for (final p in s.split('/'))
      if (p.trim() case final t when t.isNotEmpty) t,
  ];
}
