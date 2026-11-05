import 'dart:async';

import '../../core/content/content_locks.dart';
import '../../core/content/live_channel.dart';
import '../../core/content/user_sources.dart';
import '../search/search_page.dart';

/// Kaynağın içinde bulunan kayıt. [list] kaynağın bütün kayıtları, [index]
/// bulunanın sırası: oynatıcıda kaynağın kendi sırasıyla gezilir.
class SourceHit {
  const SourceHit({required this.source, required this.list, required this.index});

  final UserSource source;
  final List<LiveChannel> list;
  final int index;

  LiveChannel get channel => list[index];
}

/// Bütün listelerin kayıtlarında ad araması. Listeler 145 bin kayda çıkabiliyor
/// ve yazı katlama yavaş: ana iş parçacığını kilitlememek için tarama küçük
/// dilimlerle ve aralarda olay döngüsüne dönerek yapılır (Chromecast'te uzun
/// iş uygulamayı "yanıt vermiyor" diye kapatıyordu).
class SourceSearch {
  SourceSearch(this.sources);

  final UserSources sources;

  /// Bulunan en çok kayıt.
  static const limit = 100;
  static const _slice = 2000;

  /// Kayıtların katlanmış adları (kaynak kimliğine göre). Liste yenilenince
  /// [reset] ile boşalır.
  final _folded = <String, List<String>>{};

  void reset() => _folded.clear();

  /// [query]'yi adında taşıyan kayıtlar. [cancelled] true dönerse tarama durur
  /// (yeni arama başladı). Arama kilidi aşmasın: içinde kilitli klasör olan
  /// kaynak bütünüyle atlanır (klasörün yerini bulmak yol ağacı ister), kilitli
  /// kayıt da gösterilmez.
  Future<List<SourceHit>> run(String query, {SourceKind? kind, ContentLocks? locks, bool Function()? cancelled}) async {
    final q = SearchPage.fold(query.trim());
    if (q.isEmpty) return const [];
    bool stop() => cancelled?.call() ?? false;
    final hits = <SourceHit>[];
    for (final s in sources.items) {
      if (kind != null && s.kind != kind) continue;
      if (locks != null && _lockedInside(locks, s)) continue;
      final List<LiveChannel> list;
      try {
        list = await sources.channels(s);
      } on Object {
        continue; // Dosyası okunamayan liste sonuçlara girmez.
      }
      if (stop()) return const [];
      final names = await _names(s, list, stop);
      if (names == null) return const [];
      for (var i = 0; i < list.length; i++) {
        if (i % _slice == 0 && i > 0) {
          await Future<void>.delayed(Duration.zero);
          if (stop()) return const [];
        }
        if (!names[i].contains(q)) continue;
        final url = list[i].streams.firstOrNull;
        if (url != null && (locks?.blocks(ContentLocks.item(url)) ?? false)) continue;
        hits.add(SourceHit(source: s, list: list, index: i));
        if (hits.length >= limit) return hits;
      }
    }
    return hits;
  }

  bool _lockedInside(ContentLocks locks, UserSource s) {
    final prefix = ContentLocks.folder(s.id, const []);
    return locks.locked.any((key) => key.startsWith(prefix) && locks.blocks(key));
  }

  Future<List<String>?> _names(UserSource s, List<LiveChannel> list, bool Function() stop) async {
    final known = _folded[s.id];
    if (known != null && known.length == list.length) return known;
    final names = <String>[];
    for (final c in list) {
      names.add(SearchPage.fold(c.name));
      if (names.length % _slice == 0) {
        await Future<void>.delayed(Duration.zero);
        if (stop()) return null;
      }
    }
    return _folded[s.id] = names;
  }
}
