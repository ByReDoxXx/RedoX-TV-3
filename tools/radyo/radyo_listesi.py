"""Radyo istasyon listesini Radio Browser'dan (topluluk dizini) üretir.

Uygulama kodu değildir; listeyi yeniden üretilebilir kılmak için burada durur.
Depo kökünden çalıştırılır:

    python -I tools/radyo/radyo_listesi.py

Çıktı: assets/radios/radios.m3u (kanal listesiyle aynı biçim: group-title tür,
aynı adlı kayıtlar tek istasyonun yedek yayınları). Uygulamaya şifreli paket
olarak girer (radios.bin; redox-epg/tools/pack.mjs radios). M3U uygulamaya
konmaz.

Seçim (eski uygulamadaki listeyle aynı yöntem): Türkiye kayıtları; son
sınamada çalışan (lastcheckok) yayınlar; oy + tıklama puanına göre ilk
LIMIT istasyon. Aynı adlı kayıtlar birleşir (HTTPS önce). Tür, etiket ve
addaki anahtar sözcüklerden.
"""

import json
import re
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/radios/radios.m3u"
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

# Eski listedeki gibi dışlananlar: siyasi ya da doğrulanamayan yayıncılar.
EXCLUDE = ["rojava", "mezopotamya"]


def fold(s):
    """Küçük harf, Türkçe harfler ASCII: eşleme ve birleştirme için."""
    s = s.lower().replace("ı", "i")
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def key(name):
    return re.sub(r"[^a-z0-9]", "", fold(name))


def genre(station):
    text = fold(f"{station['name']} {station['tags']}")
    for g, words in GENRES:
        if any(re.search(rf"(^|[^a-z0-9]){w}", text) for w in words):
            return g
    return FALLBACK_GENRE


def clean_name(name):
    name = re.sub(r"\s+", " ", name).strip(" -|")
    # Tümü büyük harfli adlar başlık biçimine (Türkçe i/I korunur).
    if name.isupper() and len(name) > 4:
        name = " ".join(w if len(w) <= 3 else w[0] + w[1:].replace("İ", "i").replace("I", "ı").lower() for w in name.split())
    return name


def main():
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
    lines = ["#EXTM3U"]
    for n, e in enumerate(merged.values(), start=1):
        # HTTPS yayınlar önce (şifresiz yayın yedekte kalsın).
        e["streams"].sort(key=lambda u: not u.startswith("https://"))
        logo = f' tvg-logo="{e["logo"]}"' if e["logo"] else ""
        for url in e["streams"]:
            lines.append(f'#EXTINF:-1 tvg-chno="{n}"{logo} group-title="{e["genre"]}",{e["name"]}')
            lines.append(url)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    counts = {}
    for e in merged.values():
        counts[e["genre"]] = counts.get(e["genre"], 0) + 1
    print(f"{len(merged)} istasyon, {sum(len(e['streams']) for e in merged.values())} yayın")
    print(", ".join(f"{g} {c}" for g, c in sorted(counts.items(), key=lambda x: -x[1])))


if __name__ == "__main__":
    main()
