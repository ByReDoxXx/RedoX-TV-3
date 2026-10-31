"""RedoX TV logo varyasyonlarını kullanıcının logosundan üretir.

Uygulama kodu değildir; tasarım varlıklarını yeniden üretilebilir kılmak için
burada durur. Depo kökünden çalıştırılır:

    python -I design/logo/logo_varyasyonlari.py

Girdiler:
    assets/brand/redox-logo-source.jpg   kullanıcının logosu (Logo-2, siyah zemin;
                                         2048 px, 2000 px'e ölçeklenerek ölçülür)
    assets/brand/redox-logo.svg          izlenmiş vektör (1000 birim). Geometri
                                         ilk logodan izlendi; Logo-2 aynı çizimdir
                                         (piksel hizalı), bu yüzden her yolun rengi
                                         Logo-2'den yeniden örneklenir.

Ölçüler ve gerekçeleri: design/DESIGN-KARARLAR.md, "Logo" bölümü.
"""

import re
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC_JPG = ROOT / "assets/brand/redox-logo-source.jpg"
SRC_SVG = ROOT / "assets/brand/redox-logo.svg"
RES = ROOT / "android/app/src/main/res"

# Kaynak (2000 px) üzerinde ölçülen geometri. Boynuz ucu y=156, çene ve halka
# altı y=1518, yazı y=1534'te başlar; kırpma iki bandın arasında (1526) biter.
MARK_BOX = (295, 116, 1705, 1526)  # kare, 1410 px; yazı dışarıda kalır
WORD_BOX = (300, 1530, 1720, 1750)  # "RedoX TV" yazısı
TILE_RADIUS = 0.22  # karo köşe yarıçapı / kenar

# Android ölçüleri (developer.android.com, doğrulandı):
# uyarlanabilir katman 108 dp, güvenli alan 66 dp; eski simge 48 dp;
# TV afişi xhdpi 320x180 px ve metin içermeli.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SAFE_RADIUS_DP = 33  # güvenli alan 66 dp: işaretin en uzak opak pikseli bu çemberde


def warmth(img):
    """Kızıl/altın pikseller için 0-255 sıcaklık: r - b, koyu laciverte 0."""
    r, _, b = img.split()
    return ImageChops.subtract(r, b)


def subject_mask(img):
    """Boğa + halka + boynuz silueti. Sıcak pikseller genişletilir (koyu dış
    çizgiler dahil olsun), kenardan taşkın dolgu ile arka plan bulunur; dolgunun
    ulaşamadığı her şey (iç boşluklar dahil) konudur."""
    w, h = img.size
    hot = warmth(img).point(lambda v: 255 if v > 70 else 0)
    hot = hot.filter(ImageFilter.MaxFilter(13))
    data = hot.load()
    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.extend(((x, 0), (x, h - 1)))
    for y in range(h):
        queue.extend(((0, y), (w - 1, y)))
    while queue:
        x, y = queue.popleft()
        i = y * w + x
        if seen[i] or data[x, y]:
            continue
        seen[i] = 1
        if x > 0:
            queue.append((x - 1, y))
        if x < w - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < h - 1:
            queue.append((x, y + 1))
    mask = Image.new("L", (w, h), 0)
    m = mask.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            if not seen[row + x]:
                m[x, y] = 255
    # Küçük kıvılcım adacıklarını at: en büyük bileşen dışındakiler gider.
    return largest_component(mask).filter(ImageFilter.GaussianBlur(1.2))


def largest_component(mask):
    w, h = mask.size
    data = mask.load()
    label = [0] * (w * h)
    best, best_size, current = 0, 0, 0
    for sy in range(h):
        for sx in range(w):
            if data[sx, sy] == 0 or label[sy * w + sx]:
                continue
            current += 1
            size = 0
            queue = deque([(sx, sy)])
            label[sy * w + sx] = current
            while queue:
                x, y = queue.popleft()
                size += 1
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h and data[nx, ny] and not label[ny * w + nx]:
                        label[ny * w + nx] = current
                        queue.append((nx, ny))
            if size > best_size:
                best, best_size = current, size
    out = Image.new("L", (w, h), 0)
    o = out.load()
    for y in range(h):
        for x in range(w):
            if label[y * w + x] == best:
                o[x, y] = 255
    return out


def rounded_mask(size, radius_ratio, scale=4):
    from PIL import ImageDraw

    big = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1), radius=int(size * scale * radius_ratio), fill=255
    )
    return big.resize((size, size), Image.LANCZOS)


def mean_color(img, mask):
    """Maskenin 0 olduğu (arka plan) piksellerin ortalaması."""
    inv = mask.point(lambda v: 255 if v < 8 else 0)
    px, mk = img.load(), inv.load()
    total, n = [0, 0, 0], 0
    for y in range(0, img.height, 2):
        for x in range(0, img.width, 2):
            if mk[x, y]:
                r, g, b = px[x, y]
                total[0] += r
                total[1] += g
                total[2] += b
                n += 1
    return tuple(round(c / n) for c in total)


def fit(img, box_w, box_h):
    """Oranı koruyarak kutuya sığdırır."""
    s = min(box_w / img.width, box_h / img.height)
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def fit_radius(img, radius_px):
    """En uzak opak pikseli (alfa > 64) merkezden radius_px uzağa getirecek
    biçimde ölçekler. Boynuz uçları kare kutuya sığsa da daireyi taşabilir."""
    a = img.getchannel("A").load()
    cx, cy = img.width / 2, img.height / 2
    r2 = max(
        (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
        for y in range(img.height)
        for x in range(img.width)
        if a[x, y] > 64
    )
    s = radius_px / r2 ** 0.5
    return img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)


def paste_center(canvas, layer, dx=0, dy=0):
    x = (canvas.width - layer.width) // 2 + dx
    y = (canvas.height - layer.height) // 2 + dy
    canvas.alpha_composite(layer, (x, y))


PATH_RE = re.compile(r'<path d="([^"]*)" fill="(#[0-9A-Fa-f]{6})" transform="translate\(([-\d.]+),([-\d.]+)\)"/>')
NUM = r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"


def flatten(d, tx, ty, steps=8):
    """Mutlak M/C/Z yolunu alt çokgenlere çevirir (her kübik `steps` parça)."""
    tokens = re.findall(r"[MCZ]|" + NUM, d)
    polys, cur, pos, i, cmd = [], [], (0.0, 0.0), 0, None
    while i < len(tokens):
        t = tokens[i]
        if t in "MCZ":
            cmd = t
            i += 1
            if t == "Z" and cur:
                polys.append(cur)
                cur = []
            continue
        if cmd == "M":
            pos = (float(t) + tx, float(tokens[i + 1]) + ty)
            cur = [pos]
            i += 2
        elif cmd == "C":
            x1, y1, x2, y2, x, y = (float(v) for v in tokens[i : i + 6])
            x1, x2, x = x1 + tx, x2 + tx, x + tx
            y1, y2, y = y1 + ty, y2 + ty, y + ty
            x0, y0 = pos
            for k in range(1, steps + 1):
                u = k / steps
                m = 1 - u
                cur.append((
                    m**3 * x0 + 3 * m * m * u * x1 + 3 * m * u * u * x2 + u**3 * x,
                    m**3 * y0 + 3 * m * m * u * y1 + 3 * m * u * u * y2 + u**3 * y,
                ))
            pos = (x, y)
            i += 6
        else:
            raise ValueError(f"beklenmeyen komut: {cmd!r}")
    if cur:
        polys.append(cur)
    return polys


def recolor_trace(src1000):
    """İzlenmiş vektörün her yolunu, kaynak görselde GÖRÜNEN alanının medyan
    rengiyle boyar. SVG'de sonraki yol üsttedir; bu yüzden sondan başa gidilir
    ve üstteki yolların örttüğü pikseller sayılmaz. Delikli yollar tek-çift
    kuralıyla (XOR) çizilir."""
    from PIL import ImageDraw, ImageStat

    svg = SRC_SVG.read_text(encoding="utf-8")
    matches = list(PATH_RE.finditer(svg))
    covered = Image.new("1", src1000.size, 0)
    colors = [None] * len(matches)
    for idx in range(len(matches) - 1, -1, -1):
        m = matches[idx]
        polys = [p for p in flatten(m.group(1), float(m.group(3)), float(m.group(4))) if len(p) >= 3]
        if not polys:
            continue
        xs = [x for p in polys for x, _ in p]
        ys = [y for p in polys for _, y in p]
        box = (
            max(0, int(min(xs))), max(0, int(min(ys))),
            min(src1000.width, int(max(xs)) + 2), min(src1000.height, int(max(ys)) + 2),
        )
        if box[2] <= box[0] or box[3] <= box[1]:
            continue
        mask = Image.new("1", (box[2] - box[0], box[3] - box[1]), 0)
        for p in polys:
            layer = Image.new("1", mask.size, 0)
            ImageDraw.Draw(layer).polygon([(x - box[0], y - box[1]) for x, y in p], fill=1)
            mask = ImageChops.logical_xor(mask, layer)
        under = covered.crop(box)
        visible = ImageChops.logical_and(mask, ImageChops.invert(under))
        covered.paste(ImageChops.logical_or(under, mask), box[:2])
        region = src1000.crop(box)
        for sample in (visible, mask):
            stat = ImageStat.Stat(region, sample.convert("L"))
            if stat.count[0] > 0:
                colors[idx] = "#%02X%02X%02X" % tuple(int(v) for v in stat.median)
                break
    out, last, changed = [], 0, 0
    for m, c in zip(matches, colors):
        out.append(svg[last : m.start(2)])
        new = c or m.group(2)
        changed += new.upper() != m.group(2).upper()
        out.append(new)
        last = m.end(2)
    out.append(svg[last:])
    SRC_SVG.write_text("".join(out), encoding="utf-8")
    print(f"redox-logo.svg: {len(matches)} yol, {changed} yolun rengi kaynaktan güncellendi")


def tile_outline(img, inset=2.0):
    """Logonun yuvarlak karo sınırı, kaynak görselde ölçülür: dört köşede her
    satırda beyazın (R+G+B >= 600) bittiği ilk piksel. Kenardaki kenar
    yumuşatma pikselleri kesilsin diye çokgen merkeze doğru `inset` birim
    daraltılır. Dönen nokta listesi saat yönündedir."""
    w, h = img.size
    px = img.load()

    def first_solid(xs, y):
        return next((x for x in xs if sum(px[x, y]) < 600), None)

    def corner(rows, xs):
        pts = []
        for y in rows:
            x = first_solid(xs, y)
            if x is None:
                continue
            pts.append((x, y))
            if x in (xs[0],):  # kenara ulaşıldı: köşe bitti
                break
        return pts

    left = list(range(0, w // 2))
    right = list(range(w - 1, w // 2, -1))
    top = range(0, h // 2)
    bottom = range(h - 1, h // 2, -1)
    tl = corner(top, left)  # (x, y) üstten aşağı
    tr = corner(top, right)
    bl = corner(bottom, left)
    br = corner(bottom, right)
    # Saat yönü: sol üst köşe (kenardan üste), sağ üst (üstten kenara), sağ alt
    # (kenardan alta), sol alt (alttan kenara).
    ring = [*reversed(tl), *tr, *reversed(br), *bl]
    cx, cy = w / 2, h / 2
    k = 1 - inset / (w / 2)
    return [(cx + (x + 0.5 - cx) * k, cy + (y + 0.5 - cy) * k) for x, y in ring]


def write_full_svg(src1000):
    """Tam logoyu, ölçülen karo sınırıyla keser: köşelerdeki beyaz kalıntılar
    gider, köşeler saydam olur. Dosya her çalıştırmada baştan yazılır."""
    svg = SRC_SVG.read_text(encoding="utf-8")
    paths = [m.group(0) for m in PATH_RE.finditer(svg)]
    outline = tile_outline(src1000)
    d = "M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in outline) + " Z"
    out = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<!-- Geometri: visioncortex VTracer 0.6.12 ile izlendi. Renkler ve saydam köşeler: "
        "design/logo/logo_varyasyonlari.py -->\n"
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" viewBox="0 0 1000 1000">\n'
        f'<defs><clipPath id="tile"><path d="{d}"/></clipPath></defs>\n'
        '<g clip-path="url(#tile)">\n' + "\n".join(paths) + "\n</g>\n</svg>\n"
    )
    SRC_SVG.write_text(out, encoding="utf-8")
    print(f"redox-logo.svg: karo sınırı {len(outline)} nokta, köşeler saydam")


def write_mark_svg():
    """İzlenmiş vektörü işaret kutusuna kırpar: viewBox + yuvarlak köşeli kesme.
    Kutunun tamamen dışında kalan yollar (yazı) atılır."""
    svg = SRC_SVG.read_text(encoding="utf-8")
    x0, y0, x1, y1 = (v / 2 for v in MARK_BOX)  # izleme 1000 birim = kaynak / 2
    size = x1 - x0
    kept, dropped = [], 0
    for m in re.finditer(r'<path d="([^"]*)" fill="(#[0-9A-Fa-f]{6})" transform="translate\(([-\d.]+),([-\d.]+)\)"/>', svg):
        nums = [float(n) for n in re.findall(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", m.group(1))]
        tx, ty = float(m.group(3)), float(m.group(4))
        xs = [n + tx for n in nums[0::2]] or [tx]
        ys = [n + ty for n in nums[1::2]] or [ty]
        if max(xs) < x0 or min(xs) > x1 or max(ys) < y0 or min(ys) > y1:
            dropped += 1
            continue
        kept.append(m.group(0))
    r = size * TILE_RADIUS
    out = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<!-- RedoX TV işareti: redox-logo.svg'den kırpıldı (design/logo/logo_varyasyonlari.py). -->\n"
        f'<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="{size:g}" height="{size:g}" '
        f'viewBox="{x0:g} {y0:g} {size:g} {size:g}">\n'
        f'<defs><clipPath id="tile"><rect x="{x0:g}" y="{y0:g}" width="{size:g}" height="{size:g}" '
        f'rx="{r:.1f}" ry="{r:.1f}"/></clipPath></defs>\n'
        '<g clip-path="url(#tile)">\n' + "\n".join(kept) + "\n</g>\n</svg>\n"
    )
    dest = ROOT / "assets/brand/redox-mark.svg"
    dest.write_text(out, encoding="utf-8")
    print(f"redox-mark.svg: {len(kept)} yol, {dropped} yol atıldı, {dest.stat().st_size} bayt")


def main():
    src = Image.open(SRC_JPG).convert("RGB")
    assert src.width == src.height, src.size
    # Geometri 2000 px kaynakta ölçüldü; farklı boyuttaki kaynak ölçeklenir.
    src = src.resize((2000, 2000), Image.LANCZOS)

    # Konu maskesi 1000 px ölçekte (hız için); ikonların en büyüğü 432 px.
    half = src.resize((1000, 1000), Image.LANCZOS)
    recolor_trace(half)
    write_full_svg(half)
    write_mark_svg()
    mb = tuple(v // 2 for v in MARK_BOX)
    crop = half.crop(mb)
    mask = subject_mask(crop)
    bg = mean_color(crop, mask)
    print("arka plan ortalaması", "#%02X%02X%02X" % bg)

    subject = crop.convert("RGBA")
    subject.putalpha(mask)
    bbox = mask.point(lambda v: 255 if v > 16 else 0).getbbox()
    subject = subject.crop(bbox)

    # Tek renk katman: sıcaklık (kızıl/altın) opak, koyu dış çizgiler saydam.
    mono_alpha = ImageChops.multiply(
        warmth(crop).point(lambda v: max(0, min(255, (v - 40) * 3))), mask
    ).crop(bbox)
    mono = Image.new("RGBA", mono_alpha.size, (255, 255, 255, 0))
    mono.putalpha(mono_alpha)

    # Karo (eski Android simgesi, Windows): işaret kırpıntısı + yuvarlak köşe.
    def tile(px):
        t = crop.resize((px, px), Image.LANCZOS).convert("RGBA")
        t.putalpha(rounded_mask(px, TILE_RADIUS))
        return t

    for name, d in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(parents=True, exist_ok=True)
        tile(round(48 * d)).save(folder / "ic_launcher.png")
        layer = round(108 * d)
        fitted = fit_radius(subject, SAFE_RADIUS_DP * d)
        # Tek renk katman aynı ölçek ve konumda olmalı (temalı simge geçişi).
        mono_fitted = mono.resize(fitted.size, Image.LANCZOS)
        if name == "xxxhdpi":
            print(f"işaret kutusu {fitted.width / d:.1f} x {fitted.height / d:.1f} dp (en az 48 dp)")
        for fname, art in (("ic_launcher_foreground.png", fitted), ("ic_launcher_monochrome.png", mono_fitted)):
            canvas = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
            paste_center(canvas, art)
            canvas.save(folder / fname)

    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Uyarlanabilir simge: 108 dp katmanlar, işaret 66 dp güvenli alanda. -->\n"
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )

    # TV afişi: işaret üstte, logonun kendi yazısı altta; logo lacivert zeminde.
    word = half.crop(tuple(v // 2 for v in WORD_BOX))
    word_alpha = warmth(word).point(lambda v: max(0, min(255, (v - 30) * 4)))
    word_rgba = word.convert("RGBA")
    word_rgba.putalpha(word_alpha)
    word_rgba = word_rgba.crop(word_alpha.point(lambda v: 255 if v > 24 else 0).getbbox())
    banner = Image.new("RGBA", (320, 180), bg + (255,))
    art = fit(subject, 200, 108)
    text = fit(word_rgba, 236, 40)
    gap = 8
    top = (180 - art.height - gap - text.height) // 2
    banner.alpha_composite(art, ((320 - art.width) // 2, top))
    banner.alpha_composite(text, ((320 - text.width) // 2, top + art.height + gap))
    (RES / "drawable-xhdpi").mkdir(exist_ok=True)
    banner.convert("RGB").save(RES / "drawable-xhdpi/banner.png")

    # Windows: çok boyutlu ICO, karo.
    sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    tile(256).save(ico, sizes=[(s, s) for s in sizes])
    print("app_icon.ico boyutları", sorted(Image.open(ico).info.get("sizes", [])))

    (RES / "values/colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        "    <!-- Logonun lacivert zemini (işaret kırpıntısının arka plan ortalaması). -->\n"
        f'    <color name="ic_launcher_background">#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}</color>\n'
        "    <!-- Uygulama tuvali: DESIGN.md nötr tohumu (Logo-2'nin siyah zemini). -->\n"
        '    <color name="redox_obsidian">#000000</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print("bitti")


if __name__ == "__main__":
    main()
