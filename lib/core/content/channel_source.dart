import 'dart:isolate';

import '../ui/channel_card.dart';
import 'data_pack.dart';
import 'live_channel.dart';
import 'remote_file.dart';

/// Kanal listesi: şifreli paket (`channels.bin`, [DataPack]). Uygulamanın
/// içinde bir kopyası durur (açılış, internet yokken); güncel olanı
/// ByReDoxXx/redox-epg deposundan iner, böylece kanal eklemek için yeni sürüm
/// gerekmez. Kaynak liste gizli depodadır (`assets/channels/tr.m3u`) ve
/// uygulamaya konmaz.
abstract final class ChannelSource {
  static const asset = 'assets/channels/channels.bin';
  static const url = 'https://raw.githubusercontent.com/ByReDoxXx/redox-epg/main/channels.bin';

  /// Paketten kanallar; açılmazsa [DataPackException].
  static Future<List<LiveChannel>> open(List<int> bytes, DataPack pack) =>
      Isolate.run(() async => fromJson(await pack.open(bytes, kind: DataPack.channels)));

  /// Güncel listeyi indirir; inmez ya da açılmazsa null (eldeki liste kalır).
  static Future<List<LiveChannel>?> download(DataPack pack, {String from = url}) async {
    try {
      final channels = await open(await fetchBytes(Uri.parse(from)), pack);
      return channels.isEmpty ? null : channels;
    } on Object {
      return null;
    }
  }

  /// `{"channels": [{"number", "name", "category", "logo"?, "streams"}]}`.
  /// Paket numaraya göre sıralı gelir. Radyo paketi aynı biçimdedir, yalnız
  /// anahtarı `radios`tur ([RadioSource]).
  static List<LiveChannel> fromJson(Map<String, Object?> json, {String key = 'channels'}) {
    final list = json[key];
    if (list is! List) throw DataPackException('$key listesi yok');
    return [
      for (final (i, c) in list.indexed)
        if (c case {
          'number': final int number,
          'name': final String name,
          'category': final String category,
          'streams': final List<Object?> streams,
        })
          LiveChannel(
            name: name,
            number: number,
            category: category,
            logoUrl: c['logo'] as String?,
            streams: List.unmodifiable(streams.whereType<String>()),
            // Vurgu rengi sıradan: komşu kanallar ayrışsın.
            accent: CardAccent.values[(i + 1) % CardAccent.values.length],
          ),
    ];
  }
}
