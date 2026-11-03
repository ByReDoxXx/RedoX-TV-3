import '../../../core/content/channel_folder.dart';
import '../../../core/content/live_channel.dart';
import '../../../core/content/tmdb.dart';

/// Film/dizi oynatıcısında başlık ve alt satır: dizide "Adanalı" ve
/// "Sezon 2 · Bölüm 3 · Bölüm adı", filmde temiz ad ve "2026 · Kategori".
({String title, String subtitle}) vodTitle(LiveChannel c, {required bool series}) {
  if (series) {
    if (ChannelFolder.parseEpisode(c.name) case final e?) {
      return (
        title: e.series,
        subtitle: ['Sezon ${e.season}', 'Bölüm ${e.episode}', if (e.title.isNotEmpty) e.title].join(' · '),
      );
    }
    return (title: c.name, subtitle: c.category);
  }
  final (name, year) = Tmdb.cleanName(c.name);
  return (
    title: name.isEmpty ? c.name : name,
    subtitle: [?year?.toString(), if (c.category.isNotEmpty) c.category].join(' · '),
  );
}
