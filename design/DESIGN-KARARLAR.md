# DESIGN.md uygulama kararları

Tek kaynak: [`DESIGN.md`](DESIGN.md) ("RedoX TV Expressive"; kullanıcının verdiği dosya, değiştirilmeden kopyalandı). Bu belge spec'in Flutter'a nasıl çevrildiğini, spec içindeki çelişkileri ve her seçimin gerekçesini kaydeder. Her sayısal iddianın testi parantez içinde.

Görsel ilham: kullanıcının verdiği Stitch Anasayfa ekranı (`stitch_redox_tv_brand_identity.zip` içindeki `screen.png` ve `code.html`). Zip'teki `DESIGN.md`, bu dosyayla birebir aynıdır (SHA-256 `cc8ac372…`). Ekrandan alınanlar:
- 96 → 288 dp açılan ray, bölüm renkli ikonlar
- Hap arama kutusu
- Durum hapları
- Dikey çizgili bölüm başlığı
- Kart / EPG anahtarı
- Isıl ilerleme çubuğu
- Kanal kartı düzeni
- Vitrin hâlesi
- "OK" tuş ipucu

## 1. Birim ve tuval

- **1 spec px = 1 dp.** CSS pikseli ve Android dp ikisi de yoğunluktan bağımsız referans birimdir. rem = 16 px.
- **TV tuvali 960×540 dp.** Kaynak: Android TV tasarım rehberi (developer.android.com/design/ui/tv/guides/styles/layouts): "Always design at MDPI resolution at 960px × 540px", "At MDPI 1px = 1dp". Önceki "1920×1080 dp" varsayımı yanlıştı ve kaldırıldı.
  - 1080p arayüzde 1 dp = 2 px, 4K arayüzde 1 dp = 4 px olur. Bu oranlar sayfadan çıkarımdır, cihazda ölçülmedi.
  - Bazı kutular 1080p'de 240 dpi kullanır; bu durumda tuval 1280×720 dp olur. Yerleşim genişliğe göre hesaplanır, sabit değildir.
- **TV kenarları:**
  - Yatay: spec'in `margin-tv` değeri, 64 dp.
  - Dikey: 27 dp. Spec'in 64'ü 540 dp yükseklikte %24 eder. Android TV'nin %5 taşma kuralı 540 × 0,05 ≈ 27 dp verir.

## 2. Renk

**Roller YAML'dan birebir alınır.** YAML rolleri, düzyazının dört tohumundan M3 tonal paletleriyle türer. Her rol tamsayı tonla tam eşleşir (`redox_roles_test.dart`):

| Rol grubu | Tohum / palet | Tonlar |
|---|---|---|
| primary, on-primary, fixed, inverse | Crimson Flame `#E61638` | T80, T20, T90/T80/T10/T30, T40; kap = tohum |
| secondary | Molten Amber `#FF9E1B` | T80, T20, T90, T10, T30 |
| tertiary | Incandescent Gold `#FFD54F` | T80, T20, T70, T90, T10, T30 |
| yüzeyler ve metin | Obsidian Void `#0D0E11` | T4, T6, T10, T12, T17, T22, T24, T90, T20 |
| on-surface-variant, outline | kızıl tonu, chroma/8+4 (M3 içerik şeması) | T80, T60, T30 |
| error | M3 hata paleti | T80, T20, T30, T90 |

**Çelişki 1 – yüzey merdiveni.** YAML ve düzyazı farklı değerler veriyor:
- YAML: `#0D0E11 #1B1B1F #1F1F23 #292A2D #343538`
- Düzyazı (Tonal Surface Hierarchy): `#08090B #121418 #181A20 #22252C #2C3039`

**Karar: YAML.** Gerekçeler:
- YAML merdiveni düzyazının kendi tuval tohumunun (Obsidian Void `#0D0E11`) tonal paletidir.
- Düzyazı merdiveni hiçbir tohumdan türemez.

**Çelişki 2 – tuval.** YAML `background: #121316` diyor. Düzyazı iki yerde tuvali `surface-container-lowest` / `#0D0E11` olarak veriyor: "Base Level" ve "Neutral Canvas". Zip'teki ekran da `bg-surface-container-lowest` kullanıyor.

**Karar:** Scaffold zemini `#0D0E11`; `ColorScheme.surface` YAML'daki `#121316` olarak kalır.

**Çelişki 3 – seçili çip.** Spec: kızıl → `#FF9E1B` degrade, beyaz yazı. Beyaz yazı amber ucunda **2,07:1**; WCAG küçük yazı için 4,5:1 ister.

**Karar (kullanıcı onayladı, 2026-10-31):** Degradenin ucu "kor" `#A86500`. Bu, amber tonal paletinin beyazla 4,5:1'i sağlayan **en açık** tonudur: T49 = 4,64:1, T50 = 4,47:1 (`redox_contrast_test.dart`). Spec'in birebir hâli stil rehberinde karşılaştırma için gösteriliyordu; karar verildiği için kaldırıldı. Neden yetmediği regresyon testinde kayıtlı.

**Kızıl yazı kuralı.** Kızıl `#E61638` kartta 3,55:1 verir, bu yüzden küçük yazıda kullanılmaz (`redox_contrast_test.dart`). Kanal adı gibi vurgulu metinlerde yazı rengi `primary`, `secondary` ve `tertiary` rolleridir; kartta hepsi ≥ 4,5:1.

**İlerleme izi.** Kızıl dolgu, `surface-container-highest` izde 2,65:1 kalır; metin dışı öğe eşiği 3:1'dir.

**Karar:** İz obsidyen `#0D0E11`. Bu izde kızıl 4,17:1, amber 9,34:1, altın 13,68:1 verir.

## 3. Yazı

- **Sora** (OFL, google/fonts `ofl/sora`), değişken yazı tipi, wght 100–800. fontTools ile doğrulandı:
  - Türkçe harflerin hepsi var.
  - `tnum` var: tüm rakamlar 676 birim.
  - `₺` ve `→` glifleri **yok**. Görünen metinde `→` yerine `–` kullanılır.
- **14 belirteç** birebir alındı. em cinsinden izleme, Flutter'da `em × boyut` olarak verilir (`redox_type_test.dart`).
- **M3 yuvaları:**
  - displayMedium, displaySmall ve titleSmall'ın spec'te karşılığı yok. Flutter bunları M3 tabanından doldurur; aile yine Sora. Uygulamada kullanılmazlar.
  - Telefonda `-mobile` belirteçleri kullanılır.
- **TV'de en küçük yazı 16** (spec kuralı). Spec'in kendi çip ve rozet tarifleri 10–12 boyutunda yazı içerir; genel kural öncelikli sayıldı.
  - TV'de 16'nın altındaki stiller 16'ya çıkar.
  - Satır yüksekliği title-md'nin satırı olur.
  - Ağırlık ve em izleme korunur.

## 4. Şekil, boşluk, derinlik

- **Köşeler:** 4 / 8 / 12 / 16 / 24 / tam. **Boşluk:** 4 / 8 / 16 / 24 / 40, oluk 24 (TV 48), kenar 24 (TV 64).
- **Odak:**
  - Büyüme: TV 1.08, masaüstü ve tablet 1.04, birincil düğme 1.06.
  - Yay: M3E `spatialFast` (sertlik 800, sönüm 0,6).
- **Odak halkası:** 2 dp kızıl çizgi + aura (0 8 32, kızıl %40) + ışıma (0 16 64, amber %20).
- **Çelişki 4 – ışıma değerleri.** "Focus & Kinetic Glow" bölümü %45 / %25 ve iç vurgu veriyor; "Focus Elevation" bölümü ofset ve bulanıklıkla birlikte %40 / %20.

  **Karar:** Ölçüleri tam olan "Focus Elevation" değerleri kullanılır. Flutter'da iç gölge yoktur.
- **CSS bulanıklığı → Flutter:**
  - CSS'te sigma = blur / 2. Flutter'da sigma = r × 0,57735 + 0,5.
  - `cssBlur(px)` bu iki formülü eşitler (`redox_type_test.dart`).
- **Halka ofseti 2 dp.** Spec ofset vermez. Kızıl düğmenin etrafındaki kızıl halka görüntüde seçilmiyordu; M3 odak göstergesindeki gibi 2 dp boşluk eklendi.
- **Hayalet kenar** `rgba(255,255,255,.08)`. **Cam düğme** %10 dolgu ve %15 kenar; odakta amber zemin ve obsidyen yazı (9,34:1).
- **Vitrin hâlesi.** Spec'teki "Chromatic Backlight Flares" ve zip'teki hero: arkada kızıl ve amber bulanık ışık.

## 5. Bileşen yorumları

- **Ray seçili öğesi:** sol kenara yaslı asimetrik kızıl hap (spec).
  - Seçili öğe dinlenirken parlamaz. Parıltı yalnızca odak içindir; böylece kumandada seçim ile odak karışmaz.
  - Zip'teki ekranda seçili öğe sürekli parlıyordu; bu bilerek alınmadı.
- **Ray öğe yüksekliği** her biçimde 48 dp. Testte 56 dp ile 540 dp TV yüksekliğinde 156 dp taşma ölçüldü. Bu yüzden:
  - Logo raydan başlığa taşındı.
  - Ana öğeler daha kısa ekranlarda kayar.
- **Ray açılış eğrisi:** spec `cubic-bezier(0.2, 0, 0, 1)`; süre spec'te yok, M3 `medium4` = 400 ms seçildi.
  - Daralmış ray "low" yüzeyde durur.
  - Açık ray yan çekmece sayılır ve spec'e göre "high" yüzeye geçer.
- **Radyo düğmesi:** "obsidyen merkez, amber halka". Seçili radyo düğmesinin içi obsidyen, halka ve noktası amberdir.
- **Nabız atan nokta:** spec süre vermez. Zip'teki `animate-pulse` değeri kullanıldı: 2 sn, opaklık 1 → 0,5. Sistem animasyonları kapalıysa nokta sabit kalır.
- **Medya kartı rampası:** spec'teki doğrusal rampa (alt üçte bir, %0 → %95). Çok açık afişlerde başlığın üst kısmı rampanın düşük opaklık bölgesine düşer. Bu yüzden rampa kontrastı **garanti etmez**. Gerçek afişlerle bakılıp gerekirse rampa başlangıcı yukarı çekilmeli; bu açık nokta olarak bırakıldı.

## 6. Doğrulanmayanlar

- Hiçbir şey cihazda çalıştırılmadı. Görüntüler test ortamında çizildi.
  - Test ortamı gölgeleri bulanıksız çizer (`debugDisableShadows`).
  - Görüntü alınırken gerçek bulanıklık açılır.
- Android TV biçim algılaması yok. Biçim şimdilik açılışta verilir; varsayılan TV'dir.
- Anasayfa'daki içerik örnektir (`HomeContent.preview`). Veri katmanı yazılmadı.
