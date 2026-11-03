import 'dart:io';
import 'dart:isolate';

import 'channel_folder.dart';
import 'live_channel.dart';
import 'user_sources.dart';

/// Takılı SSD, USB bellek, SD kart ya da dahili depolamadaki bir klasörün
/// video dosyaları (kullanıcı isteği: "SSD'mdeki filmleri açmak"). Klasör alt
/// klasörleriyle taranır; her video bir kayıt olur, akışı dosyanın yoludur
/// (oynatıcı yerel dosyayı açar).
///
/// **Film:** ad dosya adıdır ("Başlangıç (2010).mkv" → "Başlangıç (2010)";
/// yıl ve afiş TMDB'den bu addan), kategori dosyanın bulunduğu klasördür
/// (kökteki dosyalarda seçilen klasörün adı).
///
/// **Dizi:** "Arrow S01E02.mkv" ya da "Arrow 1. Sezon 2. Bölüm.mp4" adları
/// olduğu gibi kalır. Adda sezon/bölüm yoksa klasörden çıkarılır:
/// "Arrow/Sezon 2/03.mkv" → "Arrow S02E03"; numara da yoksa klasördeki
/// sırası.
abstract final class LocalVideos {
  /// Video uzantıları (oynatıcı ffmpeg'in açtığı kaplar).
  static const extensions = {
    'mkv', 'mp4', 'm4v', 'mov', 'avi', 'flv', 'ts', 'm2ts', 'mts', 'webm', //
    'wmv', 'mpg', 'mpeg', '3gp', 'ogv', 'divx', 'vob',
  };

  /// En çok kayıt (yanlışlıkla bütün diski seçmeye karşı).
  static const maxFiles = 50000;

  static bool isVideo(String path) {
    final dot = path.lastIndexOf('.');
    return dot > 0 && extensions.contains(path.substring(dot + 1).toLowerCase());
  }

  /// [root]'taki videolar; [root] tek bir video dosyasıysa yalnız o (kategori
  /// bulunduğu klasör). Tarama ayrı iş parçacığında (büyük diskte binlerce
  /// klasör). Klasör yoksa ya da okunamazsa [SourceException].
  static Future<List<LiveChannel>> scan(String root, SourceKind kind) => Isolate.run(_Scan(root, kind).call);

  /// Taranan dosyalardan kayıtlar (yollar [root]'a göre, sıralı). Testler
  /// ve [scan] ortak kullanır.
  static List<LiveChannel> build(String root, List<String> files, SourceKind kind) {
    final rootName = _parts(root).lastOrNull ?? 'Klasör';
    final out = <LiveChannel>[];
    // Dizide numarasız bölümler klasör başına sırayla numaralanır.
    final order = <String, int>{};
    for (final path in files) {
      final rel = _parts(path.substring(root.length));
      if (rel.isEmpty) continue;
      final file = rel.last;
      final title = file.substring(0, file.lastIndexOf('.')).replaceAll('_', ' ').trim();
      final folders = rel.sublist(0, rel.length - 1);
      final String name;
      final String category;
      if (kind == SourceKind.series) {
        (name, category) = _episode(title, folders, rootName, order);
      } else {
        name = title;
        category = folders.lastOrNull ?? rootName;
      }
      out.add(LiveChannel(name: name, number: out.length + 1, category: category, streams: [path]));
    }
    return out;
  }

  static final _season = RegExp(r'^(?:sezon|season|s)[\s._-]*(\d{1,2})$|^(\d{1,2})\.?\s*sezon$', caseSensitive: false);

  /// Bölüm numarası: çözünürlük ("1080p") ve yıl sayılmaz.
  static final _number = RegExp(r'(?<!\d)(\d{1,3})(?![\dpP])');

  /// Dizi bölümünün adı ve kategorisi (dizinin klasörü).
  static (String, String) _episode(String title, List<String> folders, String rootName, Map<String, int> order) {
    final seasonMatch = folders.isEmpty ? null : _season.firstMatch(folders.last);
    final seriesFolders = seasonMatch == null ? folders : folders.sublist(0, folders.length - 1);
    final series = seriesFolders.lastOrNull ?? rootName;
    if (ChannelFolder.parseEpisode(title) != null) return (title, series);
    final season = int.parse(seasonMatch?[1] ?? seasonMatch?[2] ?? '1');
    final key = folders.join('/');
    final next = order[key] = (order[key] ?? 0) + 1;
    final episode = int.tryParse(_number.firstMatch(title)?[1] ?? '') ?? next;
    String two(int n) => '$n'.padLeft(2, '0');
    return ('$series S${two(season)}E${two(episode)}', series);
  }

  static List<String> _parts(String path) => [
    for (final p in path.split(RegExp(r'[/\\]')))
      if (p.isNotEmpty) p,
  ];

  /// Doğal sıra: "Bölüm 2" "Bölüm 10"dan önce.
  static int naturalCompare(String a, String b) {
    final ra = RegExp(r'\d+|\D+').allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    final rb = RegExp(r'\d+|\D+').allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < ra.length && i < rb.length; i++) {
      final na = int.tryParse(ra[i]);
      final nb = int.tryParse(rb[i]);
      final c = na != null && nb != null ? na.compareTo(nb) : ra[i].compareTo(rb[i]);
      if (c != 0) return c;
    }
    return ra.length.compareTo(rb.length);
  }
}

/// Ayrı iş parçacığında klasör taraması (yalnız yol ve tür taşınır).
class _Scan {
  const _Scan(this.root, this.kind);

  final String root;
  final SourceKind kind;

  List<LiveChannel> call() {
    // Tek dosya (gezginde videonun kendisi seçildi).
    final file = File(root);
    if (LocalVideos.isVideo(root) && file.existsSync()) {
      return LocalVideos.build(file.parent.path, [root], kind);
    }
    final dir = Directory(root);
    if (!dir.existsSync()) throw SourceException('Klasör bulunamadı: $root (sürücü çıkarılmış olabilir).');
    final files = <String>[];
    void walk(Directory d) {
      final List<FileSystemEntity> entries;
      try {
        entries = d.listSync(followLinks: false);
      } on FileSystemException {
        return; // Okunamayan alt klasör atlanır.
      }
      entries.sort((a, b) => LocalVideos.naturalCompare(a.path, b.path));
      for (final e in entries) {
        if (files.length >= LocalVideos.maxFiles) return;
        final name = e.path.split(RegExp(r'[/\\]')).last;
        // Gizli klasörler ve Android'in uygulama verisi atlanır.
        if (name.startsWith('.') || name == 'Android' || name == r'$RECYCLE.BIN') continue;
        if (e is Directory) {
          walk(e);
        } else if (e is File && LocalVideos.isVideo(e.path)) {
          files.add(e.path);
        }
      }
    }

    walk(dir);
    if (files.isEmpty) throw const SourceException('Bu klasörde video dosyası yok (mkv, mp4, avi, mov…).');
    return LocalVideos.build(root, files, kind);
  }
}
