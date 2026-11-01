import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/content/channel_source.dart';
import 'core/content/data_pack.dart';
import 'core/content/epg_source.dart';
import 'core/content/live_channel.dart';
import 'core/content/profiles.dart';
import 'core/content/watch_history.dart';
import 'core/playback/frame_grabber.dart';
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
  // Anasayfa kartlarında yayından gerçek kare (FrameStore); "Kim izliyor?"
  // ekranı dururken alınmaya başlar.
  runApp(RedoxApp(tv: tv, profiles: profiles, history: history, frames: FrameStore(startDelay: const Duration(seconds: 3)), rank: StreamProbe().rank));
}
