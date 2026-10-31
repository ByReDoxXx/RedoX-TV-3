import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Paket açılamadı: imza tutmuyor, tür yanlış, anahtar yok ya da biçim bozuk.
class DataPackException implements Exception {
  const DataPackException(this.message);

  final String message;

  @override
  String toString() => 'DataPackException: $message';
}

/// RedoX veri paketi (ByReDoxXx/redox-epg, `tools/pack.mjs`): önce Ed25519
/// imzası doğrulanır (dosya değiştirilmişse reddedilir), sonra AES-256-GCM ile
/// çözülür; içerik gzip'li JSON'dur.
///
/// Biçim: "RDX1" (4) | tür (1) | nonce (12) | şifreli metin | GCM etiketi (16)
/// | imza (64). Başlık (ilk 5 bayt) GCM ek verisidir: bir türün dosyası
/// ötekinin yerine konamaz.
///
/// Şifre anahtarı uygulamanın içindedir (derlemede `--dart-define`), bu yüzden
/// şifreleme kopyalamayı zorlaştırır ama engellemez; değiştirmeyi imza önler
/// (imzanın gizli anahtarı yalnız GitHub Secrets'tadır).
class DataPack {
  const DataPack({required this.dataKey, required this.signPublicKey});

  /// Uygulamanın anahtarları: şifre anahtarı derlemede verilir
  /// (`--dart-define=REDOX_DATA_KEY=…`), imzanın açık anahtarı koddadır.
  factory DataPack.app() => DataPack(
    dataKey: base64.decode(const String.fromEnvironment('REDOX_DATA_KEY')),
    signPublicKey: base64.decode(_signPublic),
  );

  static const _signPublic = 'mRBGuY6gVnBM9Tavz3sbwHN3a2LpfplvB/sAG9BxJuw=';

  static const channels = 1;
  static const epg = 2;

  final List<int> dataKey;
  final List<int> signPublicKey;

  static final _magic = ascii.encode('RDX1');
  static const _header = 5;
  static const _nonce = 12;
  static const _tag = 16;
  static const _signature = 64;

  /// Paketi doğrular ve içindeki JSON nesnesini döndürür.
  Future<Map<String, Object?>> open(List<int> bytes, {required int kind}) async {
    if (dataKey.length != 32) throw const DataPackException('şifre anahtarı yok (REDOX_DATA_KEY)');
    if (bytes.length < _header + _nonce + _tag + _signature) throw const DataPackException('dosya kısa');
    final data = Uint8List.fromList(bytes);
    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) throw const DataPackException('RDX1 değil');
    }
    if (data[4] != kind) throw DataPackException('tür ${data[4]}, beklenen $kind');

    final signedEnd = data.length - _signature;
    final valid = await Ed25519().verify(
      Uint8List.sublistView(data, 0, signedEnd),
      signature: Signature(
        Uint8List.sublistView(data, signedEnd),
        publicKey: SimplePublicKey(signPublicKey, type: KeyPairType.ed25519),
      ),
    );
    if (!valid) throw const DataPackException('imza tutmuyor');

    final List<int> plain;
    try {
      plain = await AesGcm.with256bits().decrypt(
        SecretBox(
          Uint8List.sublistView(data, _header + _nonce, signedEnd - _tag),
          nonce: Uint8List.sublistView(data, _header, _header + _nonce),
          mac: Mac(Uint8List.sublistView(data, signedEnd - _tag, signedEnd)),
        ),
        secretKey: SecretKey(dataKey),
        aad: Uint8List.sublistView(data, 0, _header),
      );
    } on SecretBoxAuthenticationError {
      throw const DataPackException('şifre anahtarı tutmuyor');
    }
    final json = jsonDecode(utf8.decode(gzip.decode(plain)));
    if (json is! Map<String, Object?>) throw const DataPackException('JSON nesnesi değil');
    return json;
  }
}
