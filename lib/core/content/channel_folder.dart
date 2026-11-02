import 'live_channel.dart';
import 'm3u_parser.dart';

/// Kaynağın klasör görünümü: kanallar grup adı (`group-title`) ve adlarındaki
/// "/" ile iç içe klasörlere yerleşir (kullanıcı isteği: "Dizi İsmi/1.Sezon/
/// Bölüm01"). Kalıcı değildir; kaynağın kanallarından her açılışta kurulur.
/// Kök klasörün adı boştur.
class ChannelFolder {
  ChannelFolder(this.name, {List<ChannelFolder>? folders, List<LiveChannel>? items})
    : folders = folders ?? [],
      items = items ?? [];

  /// Kanal listesinden ağaç. "Dizi İsmi/1.Sezon" grubundaki "Bölüm01" ya da
  /// grupsuz "Dizi İsmi/1.Sezon/Bölüm01" → Dizi İsmi › 1.Sezon › Bölüm01.
  /// Grubu olmayan ("Diğer") ve adında yol bulunmayan kanal köke girer.
  /// Kayıt kanalın kendisidir (bütün akışları ve logosuyla), adı son parçadır.
  ///
  /// [episodes] (Dizi bölümü): adında sezon/bölüm olan kayıt ("Dizi Adı
  /// S01E02", "Dizi Adı 1. Sezon 2. Bölüm") gruptan bağımsız Dizi Adı ›
  /// Sezon 1 › Bölüm 2'ye yerleşir.
  factory ChannelFolder.build(List<LiveChannel> channels, {bool episodes = false}) {
    final root = ChannelFolder('');
    for (final c in channels) {
      final group = c.category == M3uParser.noGroup ? '' : c.category;
      final parts = (episodes ? episodePath(c.name) : null) ?? [..._split(group), ..._split(c.name)];
      if (parts.isEmpty) continue;
      var folder = root;
      for (final p in parts.take(parts.length - 1)) {
        folder = folder.ensure(p);
      }
      folder.items.add(c.renamed(parts.last));
    }
    return root;
  }

  final String name;
  final List<ChannelFolder> folders;
  final List<LiveChannel> items;

  /// Alt klasörler dahil kayıt sayısı.
  int get total => items.length + folders.fold(0, (n, f) => n + f.total);

  ChannelFolder? child(String name) => folders.where((f) => f.name == name).firstOrNull;

  /// Adı verilen alt klasör; yoksa kurulur.
  ChannelFolder ensure(String name) {
    if (child(name) case final f?) return f;
    final made = ChannelFolder(name);
    folders.add(made);
    return made;
  }

  /// Yoldaki klasör (kökten klasör adları); yoksa null.
  ChannelFolder? at(List<String> path) {
    ChannelFolder? f = this;
    for (final name in path) {
      f = f?.child(name);
    }
    return f;
  }

  static final _sxe = RegExp(r'^(.*?)[\s._-]*S(\d{1,2})[\s._-]*E(\d{1,4})\b(.*)$', caseSensitive: false);
  static final _turkish = RegExp(
    r'^(.*?)[\s._-]*(\d{1,2})\.?\s*Sezon[\s._-]*(\d{1,4})\.?\s*Bölüm(.*)$',
    caseSensitive: false,
  );

  /// "Dizi Adı S01E02 Başlık" → [Dizi Adı, Sezon 1, Bölüm 2 Başlık]; sezon ve
  /// bölüm yoksa null.
  static List<String>? episodePath(String name) {
    final m = _sxe.firstMatch(name) ?? _turkish.firstMatch(name);
    if (m == null) return null;
    final series = m[1]!.replaceAll(RegExp(r'[\s._-]+$'), '').trim();
    if (series.isEmpty) return null;
    final rest = m[4]!.replaceAll(RegExp(r'^[\s._:-]+'), '').trim();
    final episode = 'Bölüm ${int.parse(m[3]!)}${rest.isEmpty ? '' : ' $rest'}';
    return [series, 'Sezon ${int.parse(m[2]!)}', episode];
  }

  static List<String> _split(String s) => [
    for (final p in s.split('/'))
      if (p.trim() case final t when t.isNotEmpty) t,
  ];
}
