import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Uygulama ikonları: Material Symbols Outlined (Apache-2.0), 24 px SVG.
/// Dosyalar assets/icons/ altında; `<ad>_24px.svg` ve dolu `<ad>_fill1_24px.svg`.
enum RedoxIcons {
  home('home', 'Anasayfa'),
  television('live_tv', 'Televizyon'),
  radio('radio', 'Radyo'),
  film('movie', 'Film'),
  series('video_library', 'Dizi'),
  favorites('favorite', 'Favoriler'),
  splitScreen('grid_view', 'Bölünmüş ekran'),
  sources('dns', 'Kaynaklar'),
  settings('settings', 'Ayarlar'),
  remote('settings_remote', 'Kumanda'),
  search('search', 'Arama'),
  play('play_arrow', 'Oynat'),
  pause('pause', 'Duraklat'),
  previous('skip_previous', 'Önceki'),
  next('skip_next', 'Sonraki'),
  volume('volume_up', 'Ses'),
  brightness('brightness_6', 'Parlaklık'),
  star('star', 'Yıldız'),
  folder('folder', 'Klasör'),
  qrCode('qr_code_2', 'QR kod'),
  wifi('wifi', 'Wi-Fi'),
  clock('schedule', 'Saat'),
  notifications('notifications', 'Bildirim'),
  profile('account_circle', 'Profil'),
  lock('lock', 'Kilit'),
  menu('menu', 'Menüyü aç'),
  menuOpen('menu_open', 'Menüyü kapat'),
  more('more_vert', 'Diğer'),
  fullscreen('fullscreen', 'Tam ekran'),
  cardView('view_module', 'Kart görünümü'),
  epg('view_timeline', 'EPG çizelgesi'),
  chevronLeft('chevron_left', 'Sola kaydır'),
  chevronRight('chevron_right', 'Sağa kaydır'),
  sync('sync', 'Sonraki akış'),
  moreHorizontal('more_horiz', 'Seçenekler'),
  expandLess('expand_less', 'Yukarı'),
  expandMore('expand_more', 'Aşağı'),
  subtitles('subtitles', 'Altyazı'),
  aspectRatio('aspect_ratio', 'Ölçek'),
  quality('hd', 'Kalite'),
  close('close', 'Kapat'),
  check('check', 'Seçili'),
  add('add', 'Ekle'),
  edit('edit', 'Düzenle'),
  backspace('backspace', 'Sil'),
  kids('child_care', 'Çocuk'),
  json('data_object', 'JSON'),
  html('code', 'HTML'),
  portal('router', 'Portal'),
  plugin('extension', 'Eklenti'),
  bulkAdd('playlist_add', 'Toplu ekle'),
  uploadFile('upload_file', 'Dosya'),
  link('link', 'Adres'),
  back('arrow_back', 'Geri'),
  volumeDown('volume_down', 'Sesi azalt'),
  dialpad('dialpad', 'Rakamlar'),
  tvDevice('tv', 'TV'),
  keyboard('keyboard', 'Klavye'),
  send('send', 'Gönder');

  const RedoxIcons(this.symbol, this.label);

  /// Material Symbols adı (dosya adının başı).
  final String symbol;

  /// Türkçe görünen ad (erişilebilirlik etiketi olarak da kullanılır).
  final String label;

  String assetPath({required bool filled}) => 'assets/icons/$symbol${filled ? '_fill1' : ''}_24px.svg';
}

/// Tek renkli SVG ikon. Seçili durumda dolu biçim kullanılır.
class RedoxIcon extends StatelessWidget {
  const RedoxIcon(this.icon, {super.key, this.filled = false, this.size = 24, required this.color});

  final RedoxIcons icon;
  final bool filled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      icon.assetPath(filled: filled),
      width: size,
      height: size,
      semanticsLabel: icon.label,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
