import 'dart:isolate';

import 'channel_source.dart';
import 'data_pack.dart';
import 'live_channel.dart';
import 'remote_file.dart';

/// Radyo istasyonları: şifreli paket (`radios.bin`, [DataPack.radios]).
/// Kanal listesiyle aynı biçim ve kurallar: tür `category`, yedek yayınlar
/// `streams`. Liste Radio Browser'dan üretilir
/// (`tools/radyo/radyo_listesi.py`); uygulamanın içinde bir kopyası durur,
/// güncel olanı ByReDoxXx/redox-epg deposundan iner.
abstract final class RadioSource {
  static const asset = 'assets/radios/radios.bin';
  static const url = 'https://raw.githubusercontent.com/ByReDoxXx/redox-epg/main/radios.bin';

  /// Paketten istasyonlar; açılmazsa [DataPackException].
  static Future<List<LiveChannel>> open(List<int> bytes, DataPack pack) =>
      Isolate.run(() async => ChannelSource.fromJson(await pack.open(bytes, kind: DataPack.radios), key: 'radios'));

  /// Güncel listeyi indirir; inmez ya da açılmazsa null (eldeki liste kalır).
  static Future<List<LiveChannel>?> download(DataPack pack, {String from = url}) async {
    try {
      final radios = await open(await fetchBytes(Uri.parse(from)), pack);
      return radios.isEmpty ? null : radios;
    } on Object {
      return null;
    }
  }
}
