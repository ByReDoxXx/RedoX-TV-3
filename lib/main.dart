import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/content/channel_source.dart';
import 'core/content/content_locks.dart';
import 'core/content/data_pack.dart';
import 'core/content/epg_source.dart';
import 'core/content/live_channel.dart';
import 'core/content/favorites.dart';
import 'core/content/profiles.dart';
import 'core/content/radio_source.dart';
import 'core/content/song_history.dart';
import 'core/content/user_sources.dart';
import 'core/content/watch_history.dart';
import 'core/playback/frame_grabber.dart';
import 'core/playback/radio_controller.dart';
import 'core/layout/form_factor.dart';
import 'core/playback/stream_probe.dart';
import 'features/tv/tv_content.dart';
import 'features/tv/tv_guide_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Oynatıcı (libmpv) yerel kütüphanesi.
  MediaKit.ensureInitialized();
  // TV'de dokunma yok, odak her an görünür olmalı. Android varsayılanı "touch"
  // kipidir ve halka ilk tuşa kadar gizli kalır (emülatörde doğrulandı).
  if (FormFactor.current == FormFactor.tv) {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  }
  // Kanal listesi ve yayın akışı şifreli paketlerdir (DataPack). Uygulamadaki
  // kopya açılışta okunur; güncel liste ve akış arkada iner.
  final pack = DataPack.app();
  final embedded = await ChannelSource.open(
    (await rootBundle.load(ChannelSource.asset)).buffer.asUint8List(),
    pack,
  ).catchError((Object _) => const <LiveChannel>[]);
  final tv = TvGuideController(
    TvContent(channels: embedded),
    load: () => EpgSource.load(pack),
    loadChannels: () => ChannelSource.download(pack),
  );
  unawaited(tv.start());
  // Kanal açılırken akışlar yoklanır: hızlı açılanlar içinde bit hızı en
  // yüksek olan önde (StreamProbe).
  // Profiller ve her profilin son izlenen kanalları cihazda saklanır.
  final profiles = await ProfileStore.load();
  final history = await WatchHistory.load();
  final favorites = await Favorites.load();
  // Kullanıcının M3U listeleri (Kaynaklar).
  final sources = await UserSources.load();
  // Radyo istasyonları da şifreli pakettir: uygulamadaki kopya hemen, güncel
  // liste arkada iner. Radyo uygulama boyunca tektir (bölüm değişince ses sürer).
  final stations = ValueNotifier(
    await RadioSource.open(
      (await rootBundle.load(RadioSource.asset)).buffer.asUint8List(),
      pack,
    ).catchError((Object _) => const <LiveChannel>[]),
  );
  unawaited(
    RadioSource.download(pack).then((fresh) {
      if (fresh != null) stations.value = fresh;
    }),
  );
  // Anasayfa kartlarında yayından gerçek kare (FrameStore); "Kim izliyor?"
  // ekranı dururken alınmaya başlar.
  runApp(
    RedoxApp(
      tv: tv,
      profiles: profiles,
      history: history,
      favorites: favorites,
      locks: await ContentLocks.load(),
      sources: sources,
      radio: RadioController(stations: stations, songs: await SongHistory.load()),
      frames: FrameStore(startDelay: const Duration(seconds: 3)),
      rank: StreamProbe().rank,
    ),
  );
}
