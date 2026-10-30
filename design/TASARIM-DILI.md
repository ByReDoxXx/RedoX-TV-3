# RedoX TV 3.0 — Logodan Tasarım Dili

Kaynak: yeni logo (`assets/brand/redox-logo-source.jpg`). Pano: `design/dil-panosu.png`. Renkler `design/tokens.json` ve `design/tonal-palette.json`; yazı tipi, şekil, hareket `design/M3E-UX-UI.md`. Bu belge M3 Expressive'in **üstüne** RedoX'e özgü katmanı koyar; M3E ile çakışan yerde M3E ölçüleri (köşe, yay, süre) geçerlidir.

> Motifler logodan gözle çıkarıldı (kırpmalar panoda). Dp/renk değerleri **RedoX kararıdır**; resmi bir şartname değildir.

## Altı motif

| # | Motif | Logoda | Arayüz kuralı |
|---|---|---|---|
| 1 | **Halka** | Altın halka, üstte çentik, içte ince yaylar | Odak halkası 3 dp `#F8E286`; story halkası 3 dp altın + 3 dp boşluk; radyo kadranı yayı ve çentikli ibre; dekor: 1 dp `#E5AF53` %50 ince yaylar |
| 2 | **Faset** | Düşük poligon yüzeyler, sivri kalkan | Görsel üstü scrim çapraz faset geçişli; seçili durumda şekil dönüşümü yuvarlak → çokgen (M3E `pressedShape` mantığı); hero kart (48 dp) tek kesik köşe |
| 3 | **Üçlü kontur** | Koyu kontur → altın kılcal → kızıl dolgu | Görsel üstündeki rozet/çip: 2 dp `#060B1F` kontur; seçili kızıl öğe: 1 dp `#E5AF53` kılcal |
| 4 | **Işık (statik)** | Yatay kızıl ışık çizgisi, altın parlama, kıvılcım | Odaktaki kart: statik altın parıltı (24 dp blur, %45); bölüm ayracı kızıl→saydam çizgi; kıvılcım yalnız açılışta ve sabit. **Sonsuz animasyon yok** |
| 5 | **Eğim** | İtalik, keskin wordmark | Google Sans Flex `slnt −10` (eksen aralığı −10…0, doğrulandı) **yalnızca marka anlarında**: wordmark başlık, ekran başlığı, kanal numarası. Gövde metni dik |
| 6 | **Gradyan ve zemin** | Kızıl parlak→şarap, altın parlak→bronz, zeminde üst mavi parıltı | Hero düğme `#E11D3C`→`#BF002C`; ilerleme `#F8E286`→`#C98234`; zemin `#1E3755` (üst, %50) → `#0F1126` → `#060B1F` |

## Kontrast (hesaplandı)
Üst parıltıdaki en açık zemin `#1E3755` üzerinde: `onSurface #E0E0FE` 9,39:1, `onSurfaceVariant #C1C3EE` 7,10:1, altın `#E5AF53` 6,11:1. Beyaz yazı kızıl gradyan başında (`#E11D3C`) 4,73:1, sonunda (`#820E26`) 10,29:1. Koyu kontur `#060B1F` / altın 9,85:1. Hepsi küçük metin eşiğinin (4,5:1) üstünde.

## Logo kullanımı
- **Ray üstü:** boğa + halka işareti, **56 dp**, kırpılmamış, etrafında boşluk (clear space) ≥ 8 dp.
- **Başlık:** "RedoX" kızıl + "TV" altın, `slnt −10`; wordmark metin olarak yazılır (SVG gerekmez).
- **Açılış/giriş ekranı:** tam logo SVG (`assets/brand/redox-logo.svg`, ~800 KB).
- **Karanlık zemin dışında** logo kullanılmaz (logo açık zeminde denenmedi).

## Açık noktalar (doğrulanmadı)
- **Küçük işaret yok.** Tam logo SVG ~2100 yol, 800 KB; ray ve başlık boyutu için sade bir işaret (boğa + halka) ayrıca çizilmeli. Otomatik izlemeyle ağır çıktığından ben elle çizmedim.
- Kesik köşe, faset scrim ve `slnt` kullanımı **zevk kararıdır**; Stitch ve Flutter'da görüldükten sonra onaylanmalı.
- Gradyanlar GPU maliyeti: zayıf TV'lerde çok sayıda gradyanlı kart ölçülmeden vaat edilmiyor.
