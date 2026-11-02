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

/// Ayarlar › Görünüm: yazı boyutu.
enum TextSize {
  small('%85', 0.85),
  normal('%100', 1),
  large('%115', 1.15),
  larger('%130', 1.3);

  const TextSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// Ayarlar › Altyazı: yazı boyutu (oynatıcının 1280x720 referansında
/// punto; küçük ekranda oranla küçülür).
enum SubtitleSize {
  small('Küçük', 26),
  normal('Normal', 34),
  large('Büyük', 44),
  larger('Çok büyük', 56);

  const SubtitleSize(this.label, this.fontSize);

  final String label;
  final double fontSize;
}

/// Ayarlar › Altyazı: yazı rengi (ARGB).
enum SubtitleColor {
  white('Beyaz', 0xFFFFFFFF),
  yellow('Sarı', 0xFFFFE14D),
  cyan('Camgöbeği', 0xFF7FE7FF),
  green('Yeşil', 0xFF9DF07A);

  const SubtitleColor(this.label, this.argb);

  final String label;
  final int argb;
}

/// Ayarlar › Altyazı: yazının arkası.
enum SubtitleBackground {
  none('Yok (gölgeli)', 0x00000000),
  translucent('Yarı saydam', 0xAA000000),
  black('Siyah', 0xFF000000);

  const SubtitleBackground(this.label, this.argb);

  final String label;
  final int argb;
}

/// Ayarlar › Altyazı: ekranın altından uzaklık (referans 720 yükseklikte).
enum SubtitlePosition {
  lowest('En altta', 24),
  raised('Biraz yukarıda', 72),
  high('Yukarıda', 140);

  const SubtitlePosition(this.label, this.margin);

  final String label;

  /// Alttan boşluk.
  final double margin;
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
    this._textSize = TextSize.normal,
    this._gestures = true,
    this._nightMode = false,
    this._backgroundAudio = true,
    this._oled = false,
    this._subtitleSize = SubtitleSize.normal,
    this._subtitleColor = SubtitleColor.white,
    this._subtitleBackground = SubtitleBackground.translucent,
    this._subtitlePosition = SubtitlePosition.lowest,
    this._subtitleBold = false,
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
      textSize: pick(TextSize.values, 'yazi', TextSize.normal),
      gestures: prefs.getBool('${_prefix}hareketler') ?? true,
      nightMode: prefs.getBool('${_prefix}gece') ?? false,
      backgroundAudio: prefs.getBool('${_prefix}arka_ses') ?? true,
      oled: prefs.getBool('${_prefix}oled') ?? false,
      subtitleSize: pick(SubtitleSize.values, 'altyazi_boyut', SubtitleSize.normal),
      subtitleColor: pick(SubtitleColor.values, 'altyazi_renk', SubtitleColor.white),
      subtitleBackground: pick(SubtitleBackground.values, 'altyazi_arka', SubtitleBackground.translucent),
      subtitlePosition: pick(SubtitlePosition.values, 'altyazi_konum', SubtitlePosition.lowest),
      subtitleBold: prefs.getBool('${_prefix}altyazi_kalin') ?? false,
      onSave: (s) async {
        await prefs.setString('${_prefix}yazi', s.textSize.name);
        await prefs.setBool('${_prefix}hareketler', s.gestures);
        await prefs.setBool('${_prefix}gece', s.nightMode);
        await prefs.setBool('${_prefix}arka_ses', s.backgroundAudio);
        await prefs.setBool('${_prefix}oled', s.oled);
        await prefs.setString('${_prefix}altyazi_boyut', s.subtitleSize.name);
        await prefs.setString('${_prefix}altyazi_renk', s.subtitleColor.name);
        await prefs.setString('${_prefix}altyazi_arka', s.subtitleBackground.name);
        await prefs.setString('${_prefix}altyazi_konum', s.subtitlePosition.name);
        await prefs.setBool('${_prefix}altyazi_kalin', s.subtitleBold);
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
  TextSize _textSize;
  bool _gestures;
  bool _nightMode;
  bool _backgroundAudio;
  bool _oled;

  /// OLED modu: arka planlar ve gezinti çubukları saf siyah (OLED ekranda
  /// siyah piksel yanmaz: pil tasarrufu, daha derin siyah).
  bool get oled => _oled;
  set oled(bool v) => _set(() => _oled = v);

  SubtitleSize _subtitleSize;
  SubtitleColor _subtitleColor;
  SubtitleBackground _subtitleBackground;
  SubtitlePosition _subtitlePosition;
  bool _subtitleBold;

  SubtitleSize get subtitleSize => _subtitleSize;
  SubtitleColor get subtitleColor => _subtitleColor;
  SubtitleBackground get subtitleBackground => _subtitleBackground;
  SubtitlePosition get subtitlePosition => _subtitlePosition;
  bool get subtitleBold => _subtitleBold;

  set subtitleSize(SubtitleSize v) => _set(() => _subtitleSize = v);
  set subtitleColor(SubtitleColor v) => _set(() => _subtitleColor = v);
  set subtitleBackground(SubtitleBackground v) => _set(() => _subtitleBackground = v);
  set subtitlePosition(SubtitlePosition v) => _set(() => _subtitlePosition = v);
  set subtitleBold(bool v) => _set(() => _subtitleBold = v);

  /// Bütün uygulamada yazı boyutu.
  TextSize get textSize => _textSize;

  /// Oynatıcıda dokunma hareketleri (kaydırma: ses, parlaklık, kanal; çift
  /// dokunma ve iki parmak: ölçek). Kapalıyken yalnız dokunma çubuğu açar.
  bool get gestures => _gestures;

  /// Gece modu: ses aralığı sıkıştırılır (konuşma belirgin, ani yüksek ses
  /// bastırılır).
  bool get nightMode => _nightMode;

  /// Uygulamadan çıkınca ya da ekran kapanınca ses sürsün; kapalıysa yayın
  /// duraklar, dönünce sürer.
  bool get backgroundAudio => _backgroundAudio;

  set textSize(TextSize v) => _set(() => _textSize = v);
  set gestures(bool v) => _set(() => _gestures = v);
  set nightMode(bool v) => _set(() => _nightMode = v);
  set backgroundAudio(bool v) => _set(() => _backgroundAudio = v);

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
