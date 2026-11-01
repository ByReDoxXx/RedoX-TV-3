"""Kanal listesine (assets/channels/tr.m3u) yeni bir M3U'yu birleştirir ve
kanalları yeniden numaralar.

Uygulama kodu değildir; listeyi yeniden üretilebilir kılmak için burada durur.
Depo kökünden çalıştırılır:

    python -I tools/kanal/kanal_birlestir.py <yeni.m3u> [--yaz]

`--yaz` verilmezse yalnız rapor yazar (eşleşen, eklenecek, dışlanan).

Kurallar:
- Listede olan kanalın yeni adresi, yoksa yedek akış olarak eklenir.
- Listede olmayan kanal, logosu ve kategorisiyle eklenir.
- Ücretli kanalların izinsiz yeniden yayınları eklenmez (DISLA).
- Numara: önce ANA sırası (Türksat frekans listesi, hiremco.com.tr, 16.10.2026:
  ana kanallar önde); sonra mevcut sıra (Türksat kanal/frekans PDF'inin satır
  sırası, önceki çalışma); en sonda yeni kanallar, kategori sırasıyla.
"""

import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIST = ROOT / "assets/channels/tr.m3u"

# Ana kanallar, hiremco.com.tr Türksat frekans listesindeki sırayla.
ANA = [
    "TRT 1", "TRT 2", "TRT Haber", "TRT Spor", "TRT Çocuk", "TRT Belgesel", "ATV", "Show TV", "Kanal D",
    "Star TV", "NOW TV", "TV8", "TV8.5", "Beyaz TV", "360 TV", "Kanal 7", "NTV", "CNN Türk", "Habertürk TV",
    "A Haber", "TGRT Haber HD", "Euro D", "DMAX", "TLC",
]

# Ücretli kanalların aracı sunuculardan izinsiz yeniden yayını: eklenmez.
DISLA = {"ssport", "ssport2", "disneyjr", "babytv"}

# Sınamada (01.11.2026, Türkiye çıkışlı) yayın vermeyen adresler: aracı
# sunucu HTML döndürüyor, 404, yanıt yok ya da yalnız yurt içi (Almanya).
OLU = [
    "kick2m3u8.freesrv.com",
    "telezen-stream.freesrv.com",
    "162.212.179.32/akamaissh101/ssh101/tv7tv",
    "tvnet-live.lg.mncdn.com/tvnet/tvnet/playlist.m3u8",
    "gzttv-live.lg.mncdn.com/gzttv/gzttv/playlist.m3u8",
    "edge1.socialsmart.tv/ftvturk",
    "mcdn.ndr.de",
    "tagesschau-live.ard-mcdn.de",
]

# Yeni listedeki ad → bizim listedeki ad (adla eşleşmeyenler).
ALIAS = {
    "tv2": "Teve2",
    "nowtv": "NOW TV",
    "tv85": "TV8.5",
    "a2": "A2 TV",
    "haberturk": "Habertürk TV",
    "tgrthaber": "TGRT Haber HD",
    "benguturktv": "Bengütürk TV",
    "trtturk": "TRT Türk",
    "trtarabi": "TRT Arabi",
    "powerturktv": "PowerTürk TV HD",
    "minikacocuk": "Minika Çocuk",
    "minikago": "Minika Go",
    "trtdiyanetcocuk": "TRT Diyanet Çocuk",
    "htspor": "HT Spor TV",
    "trtsporyildiz": "TRT Spor Yıldız",
    "trtmuzik": "TRT Müzik",
    "trtcocuk": "TRT Çocuk",
    "cnbce": "CNBC-e",
    "ekolhaber": "Ekol TV",
    "gzt": "GZT TV",
    "tjktv": "TJK 1",
    "tjktv2": "TJK 2",
}

# Yeni listenin grupları → bizim kategoriler.
GRUP = {
    "Ulusal": "Ulusal",
    "Ulusal-Eğlence": "Genel",
    "Eglence": "Genel",
    "Haber": "Haber",
    "Ulusal - Yurt Disi": "Dünya",
    "Yurt Disi": "Dünya",
    "Belgesel": "Belgesel",
    "Kultur": "Ulusal",
    "Spor": "Spor",
    "Muzik": "Müzik",
    "Cocuk": "Çocuk",
}
KATEGORI_SIRASI = [
    "Ulusal", "Haber", "Spor", "Belgesel", "Sinema", "Müzik", "Çocuk", "Yaşam", "Dini", "Kıbrıs", "Dünya",
    "Genel", "Yerel", "Diğer",
]

# Yeni kanalların görünen adı (yeni listedeki yazım düzeltilir).
AD = {
    "flashtv": "Flash TV",
    "ulketv": "Ülke TV",
    "dhacanli": "DHA Canlı",
    "number1tv": "Number 1 TV",
    "number1turk": "Number 1 Türk",
    "number1dance": "Number 1 Dance",
    "number1damar": "Number 1 Damar",
    "number1ask": "Number 1 Aşk",
    "powerturktaptaze": "PowerTürk Taptaze",
    "powerturkslow": "PowerTürk Slow",
    "powerturkakustik": "PowerTürk Akustik",
    "kralpoptv": "Kral Pop TV",
    "dreamturk": "Dream Türk",
    "persianaturkiye": "Persiana Türkiye",
    "trtebatv": "TRT EBA TV",
}


def fold(s):
    s = s.lower().replace("ı", "i")
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def key(name):
    k = re.sub(r"[^a-z0-9]", "", fold(name))
    return re.sub(r"(hd)$", "", k)


def parse(text):
    """M3U → [(attrs, ad, [akışlar])] ilk görülme sırasıyla; aynı ad tek kayıt."""
    out, by_name, pending = [], {}, None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("#EXTINF"):
            attrs = dict(re.findall(r'([\w-]+)="([^"]*)"', line.rsplit(",", 1)[0]))
            pending = (attrs, line.rsplit(",", 1)[1].strip())
        elif line and not line.startswith("#") and pending:
            attrs, name = pending
            if name not in by_name:
                by_name[name] = (attrs, name, [])
                out.append(by_name[name])
            if line not in by_name[name][2]:
                by_name[name][2].append(line)
            pending = None
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    new_path = Path(sys.argv[1])
    write = "--yaz" in sys.argv
    text = LIST.read_text(encoding="utf-8")
    # Baştaki açıklama satırları (kaynak notları) korunur.
    header = [l for l in text.splitlines()[1:] if l.startswith("# ")]
    header = header[: next((i for i, l in enumerate(text.splitlines()[1:]) if not l.startswith("# ")), len(header))]
    ours = parse(text)
    by_key = {key(n): (a, n, s) for a, n, s in ours}
    added, alt, skipped = [], [], []
    for attrs, name, streams in parse(new_path.read_text(encoding="utf-8")):
        k = key(name)
        streams = [u for u in streams if not any(d in u for d in OLU)]
        if not streams:
            skipped.append(f"{name} (yayın yok)")
            continue
        if k in DISLA:
            skipped.append(name)
            continue
        target = by_key.get(key(ALIAS[k])) if k in ALIAS else by_key.get(k)
        if target:
            fresh = [u for u in streams if u not in target[2]]
            target[2].extend(fresh)
            alt.append((name, target[1], len(fresh)))
        else:
            cat = GRUP.get(attrs.get("group-title", ""), "Diğer")
            entry = ({"tvg-logo": attrs.get("tvg-logo", ""), "group-title": cat}, AD.get(k, name), list(streams))
            ours.append(entry)
            by_key[k] = entry
            added.append((AD.get(k, name), cat))

    # Numara: ana sıra, sonra mevcut numara sırası, sonra yeni kanallar.
    def old_number(entry):
        n = entry[0].get("tvg-chno", "")
        return int(n) if n.isdigit() else None

    ana_keys = [key(n) for n in ANA]
    first = [by_key[k] for k in ana_keys if k in by_key]
    rest_old = sorted((e for e in ours if e not in first and old_number(e) is not None), key=old_number)
    rest_new = sorted(
        (e for e in ours if e not in first and old_number(e) is None),
        key=lambda e: KATEGORI_SIRASI.index(e[0]["group-title"]) if e[0]["group-title"] in KATEGORI_SIRASI else 99,
    )
    ordered = first + rest_old + rest_new

    print(f"Yedek akış eklenen/eşleşen: {len(alt)}")
    for new, old, n in alt:
        print(f"  {new} → {old} (+{n})")
    print(f"Yeni kanal: {len(added)}")
    for n, c in added:
        print(f"  {n} [{c}]")
    print(f"Dışlanan: {', '.join(skipped)}")
    print("İlk 30:", " | ".join(f"{i}:{e[1]}" for i, e in enumerate(ordered[:30], start=1)))
    print(f"Toplam {len(ordered)} kanal")

    if write:
        lines = ["#EXTM3U", *header]
        for i, (attrs, name, streams) in enumerate(ordered, start=1):
            logo = attrs.get("tvg-logo", "")
            logo_attr = f' tvg-logo="{logo}"' if logo else ""
            for url in streams:
                lines.append(
                    f'#EXTINF:-1 tvg-id="redox-{i}" tvg-chno="{i}"{logo_attr} group-title="{attrs["group-title"]}",{name}'
                )
                lines.append(url)
        LIST.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{LIST} yazıldı")


if __name__ == "__main__":
    main()
