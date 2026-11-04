import '../../core/layout/form_factor.dart';
import '../../core/navigation/destinations.dart';

/// Öğretici hikâyenin bir sayfası: cihazın ekran görüntüsü ([shot]), üstünde
/// parlayan halka ([highlight]: görüntüdeki öğe; yoksa halka çizilmez),
/// başlık ve açıklama. Açıklama kumandalı TV'de [tv], dokunmatikte [touch].
class TutorialSlide {
  const TutorialSlide({required this.shot, required this.title, required this.tv, required this.touch, this.highlight});

  /// Ekran görüntüsü: `assets/tutorial/<cihaz>/<shot>.webp`.
  final String shot;

  /// Görüntüde vurgulanan öğenin anahtarı (manifest.json'daki dikdörtgen).
  final String? highlight;
  final String title;
  final String tv;
  final String touch;

  String text(FormFactor f) => f == FormFactor.tv ? tv : touch;
}

/// Bir bölümün öğretici hikâyesi (Anasayfa'daki halka).
class TutorialStory {
  const TutorialStory(this.section, this.slides);

  final AppSection section;
  final List<TutorialSlide> slides;
}

/// Anasayfa'daki öğretici hikâyeler (kullanıcı isteği: "giren birisi
/// uygulamayı öğrensin"): her bölüm, o cihazın kendi ekran görüntüleriyle
/// (TV, tablet, telefon). Görüntüler ve vurgu dikdörtgenleri
/// test/tutorial/tutorial_shots_test.dart ile üretilir (REDOX_TUTORIAL=1).
abstract final class TutorialStories {
  static const all = [
    TutorialStory(AppSection.home, [
      TutorialSlide(
        shot: 'home',
        highlight: 'home.board',
        title: 'Hoş geldin',
        tv: 'Anasayfa açılışta şu an yayında olanı ve kaldığın filmi, diziyi gösterir. OK ile hemen izlemeye başla.',
        touch: 'Anasayfa şu an yayında olanı ve kaldığın filmi, diziyi gösterir. Karta dokun, hemen izle.',
      ),
      TutorialSlide(
        shot: 'home',
        highlight: 'home.nav',
        title: 'Bölümler',
        tv: 'Soldaki menüde bütün bölümler var: Televizyon, Radyo, Film, Dizi, Favoriler… Sol tuşla menüye geç.',
        touch: 'Bölümlere alttaki menüden ya da bu hikâyelerin sonundaki "Bölüme git" düğmesinden geçebilirsin.',
      ),
      TutorialSlide(
        shot: 'home',
        highlight: 'home.search',
        title: 'Arama',
        tv: 'Üstteki arama kanal, program, radyo, film ve dizi bulur. OK ile cihazın klavyesi açılır.',
        touch: 'Büyüteç kanal, program, radyo, film ve dizi bulur. Türkçe harf yazmasan da bulur.',
      ),
    ]),
    TutorialStory(AppSection.tv, [
      TutorialSlide(
        shot: 'tv',
        highlight: 'tv.chips',
        title: 'Kanallar',
        tv: 'Üstteki çiplerle kategori seç: Ulusal, Haber, Spor, Çocuk… Yıldızlı kanallar Favoriler\'de.',
        touch: 'Üstteki çiplerle kategori seç: Ulusal, Haber, Spor, Çocuk… Yıldıza dokunan kanal Favoriler\'e girer.',
      ),
      TutorialSlide(
        shot: 'tv',
        highlight: 'tv.card',
        title: 'İzle',
        tv: 'Kanalın üstüne gel, sağda canlı önizleme başlar. OK tam ekran açar.',
        touch: 'Kanala dokun, tam ekran açılır. Kartta şu anki program ve ilerlemesi yazar.',
      ),
      TutorialSlide(
        shot: 'tv',
        highlight: 'tv.guide',
        title: 'Yayın akışı',
        tv: 'EPG çizelgesi bütün kanalların günlük akışını gösterir; programa hatırlatma kurabilirsin.',
        touch: 'Yayın akışı bütün kanalların günlük programını gösterir; programa hatırlatma kurabilirsin.',
      ),
      TutorialSlide(
        shot: 'player',
        title: 'Oynatıcıda',
        tv: 'Yukarı/aşağı kanal değiştirir, rakamlar kanala atlar, OK çubuğu açar. Seçenekler\'de kalite, ses, altyazı ve uyku zamanlayıcısı.',
        touch: 'Ekrana dokun, çubuk açılır: kanal listesi, sonraki kanal ve Seçenekler (kalite, ses, altyazı) orada.',
      ),
    ]),
    TutorialStory(AppSection.radio, [
      TutorialSlide(
        shot: 'radio',
        highlight: 'radio.list',
        title: 'Radyo',
        tv: 'Yüzlerce istasyon türlerine göre. OK çalar ve kadranı açar; çalarken başka bölümde gezebilirsin.',
        touch: 'Yüzlerce istasyon türlerine göre. Dokun, çalar; çalarken başka bölümde gezebilirsin.',
      ),
      TutorialSlide(
        shot: 'radio-dial',
        highlight: 'radio.dial',
        title: 'Kadran',
        tv: 'Sağ/sol tuş kadranı çevirir, istasyon kendiliğinden çalar. Saat simgesi son çalan şarkıları gösterir.',
        touch: 'Kadranı parmağınla kaydır, istasyon kendiliğinden çalar. Saat simgesi son çalan şarkıları gösterir.',
      ),
    ]),
    TutorialStory(AppSection.film, [
      TutorialSlide(
        shot: 'film',
        highlight: 'film.grid',
        title: 'Filmler',
        tv: 'Eklediğin film listeleri afişleriyle burada. OK ayrıntıyı açar; yarıda bıraktığın film Anasayfa\'da bekler.',
        touch: 'Eklediğin film listeleri afişleriyle burada. Dokun, ayrıntı açılır; yarıda kalan film Anasayfa\'da bekler.',
      ),
      TutorialSlide(
        shot: 'film',
        highlight: 'film.filter',
        title: 'Süzgeç',
        tv: 'Kategori, Tür ve Yıl ile ara: "Komedi" ve "2020\'ler" birlikte seçilebilir.',
        touch: 'Kategori, Tür ve Yıl ile ara: "Komedi" ve "2020\'ler" birlikte seçilebilir.',
      ),
    ]),
    TutorialStory(AppSection.series, [
      TutorialSlide(
        shot: 'series',
        highlight: 'series.grid',
        title: 'Diziler',
        tv: 'Bölümler kendiliğinden dizi › sezon › bölüm diye dizilir. OK dizinin sayfasını açar.',
        touch: 'Bölümler kendiliğinden dizi › sezon › bölüm diye dizilir. Dokun, dizinin sayfası açılır.',
      ),
      TutorialSlide(
        shot: 'series-detail',
        highlight: 'series.seasons',
        title: 'Sezonlar',
        tv: 'Sezon seç, bölüme OK. Oynatıcıda yukarı tuşu bölüm şeridini açar; bölüm bitince sıradaki başlar.',
        touch: 'Sezon seç, bölüme dokun. Bölüm bitince sıradaki başlar; kaldığın yer saklanır.',
      ),
    ]),
    TutorialStory(AppSection.favorites, [
      TutorialSlide(
        shot: 'favorites',
        highlight: 'favorites.tabs',
        title: 'Favoriler',
        tv: 'Yıldızladığın kanallar, radyolar, filmler ve diziler kendi sekmesinde. Uzun OK ile kanalların sırasını değiştir.',
        touch: 'Yıldızladığın kanallar, radyolar, filmler ve diziler kendi sekmesinde. Tutup sürükle, kanalların sırasını değiştir.',
      ),
    ]),
    TutorialStory(AppSection.splitScreen, [
      TutorialSlide(
        shot: 'split',
        highlight: 'split.tile',
        title: 'Bölünmüş ekran',
        tv: 'Aynı anda iki kanal izle: kutuya OK, kanal seç. Ses seçili kutudan gelir.',
        touch: 'Aynı anda birden çok kanal izle: kutuya dokun, kanal seç. Ses seçili kutudan gelir.',
      ),
    ]),
    TutorialStory(AppSection.sources, [
      TutorialSlide(
        shot: 'sources',
        highlight: 'sources.add',
        title: 'Kaynaklar',
        tv: 'Kendi listelerini ekle: M3U, Xtream, portal, dosya ya da USB/SSD\'deki film klasörü.',
        touch: 'Kendi listelerini ekle: M3U, Xtream, portal, dosya ya da telefondaki film klasörü.',
      ),
      TutorialSlide(
        shot: 'sources',
        highlight: 'sources.card',
        title: 'Listelerin',
        tv: 'Her liste bir klasör: içine gir, kanalları gör. Film ve Dizi listeleri kendi bölümlerinde de görünür.',
        touch: 'Her liste bir klasör: dokun, kanalları gör. Film ve Dizi listeleri kendi bölümlerinde de görünür.',
      ),
    ]),
    TutorialStory(AppSection.settings, [
      TutorialSlide(
        shot: 'settings',
        highlight: 'settings.steps',
        title: 'Kaynak ekle',
        tv: '1. Ne ekliyorsun (Canlı TV, Film, Dizi), 2. Nereden. Uzun adresi telefondan QR ile de gönderebilirsin.',
        touch: '1. Ne ekliyorsun (Canlı TV, Film, Dizi), 2. Nereden. Dosya ya da klasör de seçebilirsin.',
      ),
      TutorialSlide(
        shot: 'settings',
        highlight: 'settings.menu',
        title: 'Ayarlar',
        tv: 'Oynatıcı, altyazı, görünüm, profiller ve yedekleme buradan. Ayarların yedeği telefona da alınabilir.',
        touch: 'Oynatıcı, altyazı, görünüm, profiller ve yedekleme buradan.',
      ),
    ]),
  ];

  /// Çocuk profilinde yalnız Anasayfa ve Televizyon.
  static List<TutorialStory> forProfile({required bool kids}) => [
    for (final s in all)
      if (!kids || s.section == AppSection.home || s.section == AppSection.tv) s,
  ];

  /// Görüntü klasörü: cihazın biçimi (masaüstü tablet görüntüleriyle).
  static String folder(FormFactor f) => switch (f) {
    FormFactor.tv => 'tv',
    FormFactor.phone => 'telefon',
    FormFactor.tablet || FormFactor.desktop => 'tablet',
  };

  /// Kullanılan bütün görüntüler.
  static Set<String> get shots => {
    for (final s in all)
      for (final slide in s.slides) slide.shot,
  };
}
