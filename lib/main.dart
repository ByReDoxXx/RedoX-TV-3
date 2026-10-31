import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/content/channel_source.dart';
import 'core/content/data_pack.dart';
import 'core/content/epg_source.dart';
import 'core/content/live_channel.dart';
import 'core/layout/form_factor.dart';
import 'features/player/stream_probe.dart';
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
  runApp(RedoxApp(tv: tv, rank: StreamProbe().rank));
}
