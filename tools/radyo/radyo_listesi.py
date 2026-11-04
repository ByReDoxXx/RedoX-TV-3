"""Radyo istasyon listesini Radio Browser'dan (topluluk dizini) üretir.

Uygulama kodu değildir; listeyi yeniden üretilebilir kılmak için burada durur.
Depo kökünden çalıştırılır:

    python -I tools/radyo/radyo_listesi.py [--eski <radios.json>]

Çıktı: ~/.redox/kaynak/radios.m3u, depoda değil (kanal listesiyle aynı biçim: group-title tür,
aynı adlı kayıtlar tek istasyonun yedek yayınları). Uygulamaya şifreli paket
olarak girer (radios.bin; redox-epg/tools/pack.mjs radios). M3U uygulamaya
konmaz.

Seçim (eski uygulamadaki listeyle aynı yöntem): Türkiye kayıtları; son
sınamada çalışan (lastcheckok) yayınlar; oy + tıklama puanına göre ilk
LIMIT istasyon. Aynı adlı kayıtlar birleşir (HTTPS önce). Tür, etiket ve
addaki anahtar sözcüklerden.

--eski: eski uygulamanın elle ayıklanmış, Türkiye'den iki turda sınanmış
listesi (radios.enc'nin çözülmüş JSON'u; kullanıcı kararı 2026-11-01: "Eski +
yeni eklenenler"). Eski istasyonlar numara, tür, logo ve yayın sırasıyla aynen
kalır; Radio Browser'dan yalnız eski listede olmayanlar sona eklenir. Eşleşme
"Türkiye/Turkey/Radyo/Radio/FM" eklerini yok sayar ("Virgin Radio Türkiye" =
"Virgin Radio"). Çözülmüş dosya ve eski şifre depoya konmaz.
"""

import argparse
import json
import re
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path.home() / ".redox/kaynak/radios.m3u"
API = "https://de1.api.radio-browser.info/json/stations/bycountrycodeexact/TR?hidebroken=true&limit=2000"
# Shoutcast sunucuları tarayıcı kimliğine ses yerine HTML döndürür.
UA = "RedoXTV/3.0"
LIMIT = 150
MAX_STREAMS = 3

# Sıra önemlidir: ilk eşleşen tür kazanır.
GENRES = [
    ("Haber & Spor", ["haber", "news", "spor", "sport", "gundem", "cnn", "gol", "trafik"]),
    ("Dini", ["dini", "islam", "kuran", "quran", "ilahi", "dua", "diyanet", "semerkand", "lalegul", "akra", "risalet"]),
    ("Türkü & Halk", ["turku", "halk", "folk", "ozan", "anadolu", "bozlak", "saz", "havalari"]),
    ("Arabesk & Fantezi", ["arabesk", "fantezi", "damar", "fasil"]),
    ("Nostalji", ["nostalji", "70s", "80s", "90s", "00s", "oldies", "golden", "retro", "eski", "altin", "yesilcam", "2010", "45lik", "efsane"]),
    ("Rock & Alternatif", ["rock", "alternatif", "alternative", "metal", "indie"]),
    ("Dans & Elektronik", ["dance", "electronic", "house", "edm", "club", "trance", "techno", "lounge", "chill", "dans", "hip hop", "r&b", "rap"]),
    ("Klasik & Sanat", ["klasik", "classical", "sanat", "tsm", "jazz", "caz", "blues", "ottoman", "makam", "classic", "nagme", "alaturka"]),
    ("Pop", ["pop", "hit", "top", "fm", "turkce", "turk", "slow", "love", "kiss", "joy", "fenomen", "viva", "max"]),
]
FALLBACK_GENRE = "Karışık"

# Eski listedeki gibi dışlananlar (yayıncıya göre, dile göre değil): siyasi ya
# da doğrulanamayan yayıncılar, yabancı devlet yayın organları, TV kanalının
# sesi. Eşleşme key() üzerinden (ad içinde geçerse).
EXCLUDE = [
    "rojava",
    "mezopotamya",
    "kurd1",
    "azadi",
    "medradyo",
    "denge",
    "sputnik",
    "halktv",
    "radioava",
    "tezene",
]

# Eşleştirmede yok sayılan ekler.
NOISE = {"turkey", "turkiye", "radyo", "radio", "fm", "tr"}

# Eski listede başka yazılışla bulunanlar (loose_key başı) ve Radio Browser'da
# yanlışlıkla Türkiye'ye kayıtlı yabancı istasyonlar: eklenmez.
SAME_AS_OLD = ["45lik", "turkuazanadolu", "max", "bloomberght", "powerturk2", "pal"]
FOREIGN = ["fg938"]


def fold(s):
    """Küçük harf, Türkçe harfler ASCII: eşleme ve birleştirme için."""
    s = s.lower().replace("ı", "i")
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def key(name):
    return re.sub(r"[^a-z0-9]", "", fold(name))


def loose_key(name):
    """Eski/yeni liste eşleşmesi: ekler atılmış anahtar."""
    words = [w for w in re.split(r"[^a-z0-9]+", fold(name)) if w and w not in NOISE]
    return "".join(words) or key(name)


def load_old(path):
    """Eski listenin istasyonları (numara sırasıyla), M3U girdisi biçiminde."""
    radios = json.loads(Path(path).read_text(encoding="utf-8"))["radios"]
    return [
        {
            "number": r["number"],
            "name": r["name"],
            "genre": r["cat"],
            "logo": r.get("logoUrl") or None,
            # Eski sıra korunur (elle sınanmış: ana yayın önce).
            "streams": [s["url"] for s in r.get("sources", []) if s.get("url")],
            "keep_order": True,
        }
        for r in sorted(radios, key=lambda r: r["number"])
    ]


def genre(station):
    text = fold(f"{station['name']} {station['tags']}")
    for g, words in GENRES:
        if any(re.search(rf"(^|[^a-z0-9]){w}", text) for w in words):
            return g
    return FALLBACK_GENRE


def clean_name(name):
    name = re.sub(r"\s+", " ", name).strip(" -|")
    # Radio Browser'daki ülke eki ("Babyland Turkey"); eski listedeki adlarda yok.
    name = re.sub(r"\s+(turkey|türkiye|turkiye)$", "", name, flags=re.IGNORECASE)
    # Tümü büyük harfli adlar başlık biçimine (Türkçe i/I korunur).
    if name.isupper() and len(name) > 4:
        name = " ".join(w if len(w) <= 3 else w[0] + w[1:].replace("İ", "i").replace("I", "ı").lower() for w in name.split())
    return name


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--eski", help="eski listenin çözülmüş JSON'u (depoya konmaz)")
    old = load_old(args.parse_args().eski) if args.parse_args().eski else []
    old_keys = {loose_key(e["name"]) for e in old}
    req = urllib.request.Request(API, headers={"User-Agent": UA})
    stations = json.load(urllib.request.urlopen(req, timeout=60))
    ok = [s for s in stations if s.get("lastcheckok") == 1 and (s.get("url_resolved") or s.get("url"))]
    ok.sort(key=lambda s: s["votes"] + 3 * s["clickcount"], reverse=True)
    merged = {}
    for s in ok:
        k = key(s["name"])
        if not k or any(x in k for x in EXCLUDE):
            continue
        url = s.get("url_resolved") or s["url"]
        if k not in merged:
            if len(merged) >= LIMIT:
                continue
            merged[k] = {
                "name": clean_name(s["name"]),
                "genre": genre(s),
                "logo": s["favicon"] if s.get("favicon", "").startswith("https://") else None,
                "streams": [],
            }
        e = merged[k]
        if url not in e["streams"] and len(e["streams"]) < MAX_STREAMS:
            e["streams"].append(url)
    # Eski listede olanlar atlanır; yeniler eski numaralardan sonra gelir.
    def known(e):
        k = loose_key(e["name"])
        return k in old_keys or (old and any(k.startswith(a) for a in SAME_AS_OLD)) or any(k.startswith(f) for f in FOREIGN)

    added = [e for e in merged.values() if not known(e)]
    start = max((e["number"] for e in old), default=0) + 1
    for n, e in enumerate(added, start=start):
        e["number"] = n
    entries = old + added
    lines = ["#EXTM3U"]
    for e in entries:
        if not e.get("keep_order"):
            # HTTPS yayınlar önce (şifresiz yayın yedekte kalsın).
            e["streams"].sort(key=lambda u: not u.startswith("https://"))
        logo = f' tvg-logo="{e["logo"]}"' if e["logo"] else ""
        for url in e["streams"]:
            lines.append(f'#EXTINF:-1 tvg-chno="{e["number"]}"{logo} group-title="{e["genre"]}",{e["name"]}')
            lines.append(url)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    counts = {}
    for e in entries:
        counts[e["genre"]] = counts.get(e["genre"], 0) + 1
    print(f"{len(entries)} istasyon ({len(old)} eski + {len(added)} yeni), {sum(len(e['streams']) for e in entries)} yayın")
    if added:
        print("yeni:", ", ".join(e["name"] for e in added))
    print(", ".join(f"{g} {c}" for g, c in sorted(counts.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main()
