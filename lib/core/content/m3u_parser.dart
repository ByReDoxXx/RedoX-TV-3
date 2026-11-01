import '../ui/channel_card.dart';
import 'live_channel.dart';

/// M3U (#EXTM3U) kanal listesi okuyucu. Okunan öznitelikler: `tvg-id`,
/// `tvg-chno` (kanal numarası), `tvg-logo`, `group-title` (kategori); ad
/// virgülden sonraki metindir, adres sonraki yorum olmayan satır.
///
/// Aynı `tvg-id`'li (yoksa aynı adlı) kayıtlar tek kanalın akışlarıdır
/// ("Akış 1/2"), dosyadaki sırayla. Kanallar numaraya göre sıralanır;
/// numarası olmayanlar sona, listedeki sırayla dizilir ve en büyük
/// numaradan sonraki numaraları alır (numaralar çakışmasın).
///
/// Uygulamanın kendi listesi M3U değil, şifreli pakettir (ChannelSource);
/// aynı kurallar paketi üreten `redox-epg/tools/pack.mjs`'tedir. Bu okuyucu
/// kullanıcının ekleyeceği M3U kaynakları ("Kaynaklar" bölümü, QR ile kaynak)
/// ve testler içindir.
abstract final class M3uParser {
  /// `group-title` olmayan kanalın kategorisi.
  static const noGroup = 'Diğer';

  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  static List<LiveChannel> parse(String text) {
    final byKey = <String, _Entry>{};
    _Entry? pending;
    var order = 0;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        final comma = _nameComma(line);
        final attrs = {for (final m in _attr.allMatches(line.substring(0, comma))) m[1]!: m[2]!};
        pending = _Entry(
          id: attrs['tvg-id'],
          name: line.substring(comma + 1).trim(),
          number: int.tryParse(attrs['tvg-chno'] ?? ''),
          logo: _nonEmpty(attrs['tvg-logo']),
          category: _nonEmpty(attrs['group-title']) ?? noGroup,
          order: ++order,
        );
      } else if (!line.startsWith('#') && pending != null) {
        // Aynı gruptaki aynı ad yedek akıştır; farklı gruptaki aynı ad ayrı
        // kayıttır (dizi listesinde her sezonun "Bölüm01"i).
        final key = _nonEmpty(pending.id) ?? '${pending.category}\u0000${pending.name}';
        (byKey[key] ??= pending).streams.add(line);
        pending = null;
      }
    }
    final entries = byKey.values.toList()
      ..sort((a, b) {
        final n = (a.number ?? 1 << 30).compareTo(b.number ?? 1 << 30);
        return n != 0 ? n : a.order.compareTo(b.order);
      });
    var next = entries.fold(0, (m, e) => (e.number ?? 0) > m ? e.number! : m);
    return [
      for (final e in entries)
        LiveChannel(
          name: e.name,
          number: e.number ?? ++next,
          category: e.category,
          logoUrl: e.logo,
          streams: List.unmodifiable(e.streams),
          // Vurgu rengi numaradan: komşu kanallar ayrışsın.
          accent: CardAccent.values[e.order % CardAccent.values.length],
        ),
    ];
  }

  /// Adı ayıran virgül: tırnak içindeki virgüller (öznitelik değerleri) sayılmaz.
  static int _nameComma(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') quoted = !quoted;
      if (ch == ',' && !quoted) return i;
    }
    return line.length - 1;
  }

  static String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
}

class _Entry {
  _Entry({
    required this.id,
    required this.name,
    required this.number,
    required this.logo,
    required this.category,
    required this.order,
  });

  final String? id;
  final String name;
  final int? number;
  final String? logo;
  final String category;
  final int order;
  final streams = <String>[];
}
