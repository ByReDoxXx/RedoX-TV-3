import 'dart:math' as math;

/// Dizide bölüm biterken sonraki bölüme geçiş sayacı: oynatma konumundan sayar,
/// duraklatınca durur, geri sarınca kapanır. Jenerik süresi bilinmediği için
/// yalnız son saniyelerde çıkar.
class NextEpisodeCountdown {
  /// Kalan süre bu kadar olunca kart çıkar.
  static const showAt = Duration(seconds: 15);

  /// Kalan süre bu kadar olunca sonraki bölüm açılır (dosya bitmeden).
  static const playAt = Duration(seconds: 3);

  // Önceki bölümün konumu yeni bölüme taşmasın: önce sınırın gerisi görülmeli.
  bool _armed = false;
  bool _cancelled = false;

  /// Kalan saniye (0: açılmalı); kart yoksa null.
  int? update(Duration remaining) {
    if (remaining > showAt) {
      _armed = true;
      _cancelled = false;
      return null;
    }
    if (!_armed || _cancelled) return null;
    return math.max(0, ((remaining - playAt).inMilliseconds / 1000).ceil());
  }

  /// Kullanıcı vazgeçti: geri sarana dek kart çıkmaz.
  void cancel() => _cancelled = true;

  /// Yeni bölüm açıldı.
  void reset() {
    _armed = false;
    _cancelled = false;
  }
}
