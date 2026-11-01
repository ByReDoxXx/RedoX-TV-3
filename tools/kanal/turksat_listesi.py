"""Türksat'ın resmi frekans listesinden şifresiz TV kanallarını indirir
(TKGS'nin dağıttığı kanallar; TKGS ayrı bir liste olarak yayımlanmıyor).

Uygulama kodu değildir. Depo kökünden çalıştırılır:

    python -I tools/kanal/turksat_listesi.py

Çıktı: tools/kanal/turksat_sifresiz.txt (bir satır bir kanal adı, Türksat'ın
yazımıyla; başta tarih). kanal_birlestir.py listede yalnız bu kanalları tutar.
Kaynak: turksat.com.tr/uydu/yayincilik-hizmetleri/turksat-frekans-listesi,
süzgeç "Şifreleme: Şifresiz", yayın 4K/HD/SD (RD radyodur).
"""

import datetime
import html
import re
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent / "turksat_sifresiz.txt"
BASE = "https://www.turksat.com.tr/uydu/yayincilik-hizmetleri/turksat-frekans-listesi"


def main():
    names = set()
    # Site sayfalar arasında sırayı sabit tutmuyor: tek geçişte satır
    # kaçabiliyor (01.11.2026'da ADA TV, GENÇ TV). Üç geçişin birleşimi.
    for yayin in ("4K", "HD", "SD") * 3:
        for page in range(60):
            q = urllib.parse.urlencode({"sifreleme": "Şifresiz", "yayin": yayin, "page": page})
            req = urllib.request.Request(f"{BASE}?{q}", headers={"User-Agent": "Mozilla/5.0"})
            text = urllib.request.urlopen(req, timeout=60).read().decode("utf-8")
            got = 0
            for row in re.findall(r"<tr>(.*?)</tr>", text, re.S):
                cells = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip() for c in re.findall(r"<td[^>]*>(.*?)</td>", row, re.S)]
                if len(cells) >= 10 and cells[1]:
                    names.add(cells[1])
                    got += 1
            if got == 0:
                break
    lines = [f"# Türksat şifresiz TV kanalları, {datetime.date.today().isoformat()} ({len(names)} ad)", *sorted(names)]
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{OUT.name}: {len(names)} kanal")


if __name__ == "__main__":
    main()
