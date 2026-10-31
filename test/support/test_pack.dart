import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:redox_tv/core/content/data_pack.dart';

/// Testte paket üretir ve açar: `redox-epg/tools/pack.mjs`'in Dart karşılığı
/// (biçim DataPack'te). Anahtarlar her testte yeniden üretilir.
class TestPack {
  TestPack._(this._keyPair, this.dataKey, this.reader);

  static Future<TestPack> create() async {
    final keyPair = await Ed25519().newKeyPair();
    final dataKey = List<int>.generate(32, (i) => (i * 37 + 11) % 256);
    final pub = await keyPair.extractPublicKey();
    return TestPack._(keyPair, dataKey, DataPack(dataKey: dataKey, signPublicKey: pub.bytes));
  }

  final SimpleKeyPair _keyPair;
  final List<int> dataKey;

  /// Bu paketleri açan okuyucu.
  final DataPack reader;

  Future<Uint8List> seal(Map<String, Object?> json, {required int kind}) async {
    final header = [...ascii.encode('RDX1'), kind];
    final box = await AesGcm.with256bits().encrypt(
      gzip.encode(utf8.encode(jsonEncode(json))),
      secretKey: SecretKey(dataKey),
      aad: header,
    );
    final signed = Uint8List.fromList([...header, ...box.nonce, ...box.cipherText, ...box.mac.bytes]);
    final signature = await Ed25519().sign(signed, keyPair: _keyPair);
    return Uint8List.fromList([...signed, ...signature.bytes]);
  }
}
