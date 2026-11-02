import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ayarlar › Oynatıcı: en yüksek görüntü kalitesi.
enum QualityCap {
  highest('En yüksek', null),
  fullHd('En çok Full HD (1080p)', 1080),
  hd('En çok HD (720p)', 720);

  const QualityCap(this.label, this.maxHeight);

  final String label;

  /// Seçilecek en yüksek görüntü yüksekliği; null: sınırsız.
  final int? maxHeight;
}

/// Ayarlar › Oynatıcı: açılışta görüntü ölçeği (oynatıcıdaki ölçek
/// seçenekleriyle aynı adlar; VideoScale).
enum StartScale {
  original('16:9 Orijinal'),
  fill('Ekranı doldur'),
  stretch('Uzat');

  const StartScale(this.label);

  final String label;
}

/// Ayarlar › Oynatıcı: ön bellek (takılan yayınlar için).
enum BufferSize {
  auto('Otomatik', null),
  s5('5 sn', 5),
  s10('10 sn', 10),
  s20('20 sn', 20);

  const BufferSize(this.label, this.seconds);

  final String label;

  /// İleriye okunan süre; null: oynatıcının varsayılanı.
  final int? seconds;
}

/// Ayarlar › Oynatıcı: tercih edilen ses ve altyazı dili (mpv dil kodları,
/// önem sırasıyla).
enum TrackLanguage {
  auto('Otomatik', ''),
  turkish('Türkçe', 'tr,tur,tür'),
  english('İngilizce', 'en,eng'),
  off('Kapalı', '');

  const TrackLanguage(this.label, this.codes);

  final String label;
  final String codes;
}

/// Ayarlar › Açılış: profil seçildikten sonra açılan sayfa.
enum StartPage {
  home('Anasayfa'),
  tv('Televizyon'),
  lastChannel('Son izlenen kanal');

  const StartPage(this.label);

  final String label;
}

/// Uygulama ayarları (kullanıcı isteği: Ayarlar'a oynatıcı, açılış ve veri
/// ayarları). Cihazda saklanır, bütün profillerde ortaktır.
///
/// Oynatma katmanı (motor, oturum, akış sıralama) widget ağacının dışında
/// kurulduğundan ayarlar [instance] ile okunur; main.dart cihazdakini
/// yükler, testlerde varsayılanlar (saklamasız) geçerlidir.
class AppSettings extends ChangeNotifier {
  AppSettings({
    this._quality = QualityCap.highest,
    this._scale = StartScale.original,
    this._buffer = BufferSize.auto,
    this._failover = true,
    this._audio = TrackLanguage.auto,
    this._subtitles = TrackLanguage.auto,
    this._askProfile = true,
    this._startPage = StartPage.home,
    this.onSave,
  });

  /// Uygulamanın ayarları (main.dart yükler).
  static AppSettings instance = AppSettings();

  final Future<void> Function(AppSettings)? onSave;

  static const _prefix = 'ayar_';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[prefs.getString('$_prefix$key')] ?? fallback;
    return AppSettings(
      quality: pick(QualityCap.values, 'kalite', QualityCap.highest),
      scale: pick(StartScale.values, 'olcek', StartScale.original),
      buffer: pick(BufferSize.values, 'onbellek', BufferSize.auto),
      failover: prefs.getBool('${_prefix}yedek') ?? true,
      audio: pick(TrackLanguage.values, 'ses_dili', TrackLanguage.auto),
      subtitles: pick(TrackLanguage.values, 'altyazi_dili', TrackLanguage.auto),
      askProfile: prefs.getBool('${_prefix}profil_sor') ?? true,
      startPage: pick(StartPage.values, 'acilis', StartPage.home),
      onSave: (s) async {
        await prefs.setString('${_prefix}kalite', s.quality.name);
        await prefs.setString('${_prefix}olcek', s.scale.name);
        await prefs.setString('${_prefix}onbellek', s.buffer.name);
        await prefs.setBool('${_prefix}yedek', s.failover);
        await prefs.setString('${_prefix}ses_dili', s.audio.name);
        await prefs.setString('${_prefix}altyazi_dili', s.subtitles.name);
        await prefs.setBool('${_prefix}profil_sor', s.askProfile);
        await prefs.setString('${_prefix}acilis', s.startPage.name);
      },
    );
  }

  QualityCap _quality;
  StartScale _scale;
  BufferSize _buffer;
  bool _failover;
  TrackLanguage _audio;
  TrackLanguage _subtitles;
  bool _askProfile;
  StartPage _startPage;

  QualityCap get quality => _quality;
  StartScale get scale => _scale;
  BufferSize get buffer => _buffer;

  /// Akış açılmazsa kanalın sıradaki akışına kendiliğinden geç.
  bool get failover => _failover;
  TrackLanguage get audio => _audio;
  TrackLanguage get subtitles => _subtitles;

  /// "Kim izliyor?" her açılışta sorulsun; kapalıysa son profil açılır.
  bool get askProfile => _askProfile;
  StartPage get startPage => _startPage;

  set quality(QualityCap v) => _set(() => _quality = v);
  set scale(StartScale v) => _set(() => _scale = v);
  set buffer(BufferSize v) => _set(() => _buffer = v);
  set failover(bool v) => _set(() => _failover = v);
  set audio(TrackLanguage v) => _set(() => _audio = v);
  set subtitles(TrackLanguage v) => _set(() => _subtitles = v);
  set askProfile(bool v) => _set(() => _askProfile = v);
  set startPage(StartPage v) => _set(() => _startPage = v);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
    unawaited(onSave?.call(this));
  }
}
