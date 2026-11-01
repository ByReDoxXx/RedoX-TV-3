"""Radyo cızırtısı sesini üretir (istasyon geçişi ve bağlanırken).

Uygulama kodu değildir; sesi yeniden üretilebilir kılmak için burada durur.
Depo kökünden çalıştırılır:

    python -I tools/ses/radyo_cizirti.py

Çıktı: assets/sounds/radyo_cizirti.wav (mono, 22 050 Hz, 16 bit, 1,5 sn,
döngüye uygun: baş ve son yumuşak geçişli). İçerik: AM radyo gibi bant
sınırlı parazit (alçak ve yüksek geçiren süzgeç), hafif dalgalanan seviye,
seyrek çıtırtılar ve arada kayan "ıslık" tonu (kanal ararken duyulan).
Sabit tohum: her çalıştırmada aynı dosya.
"""

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sounds/radyo_cizirti.wav"
RATE = 22050
SECONDS = 1.5
FADE = 0.06  # döngü dikişi (sn)


def main():
    rnd = random.Random(2026)
    n = int(RATE * SECONDS)
    # Tek kutuplu süzgeçler: alçak geçiren (boğuk AM), yüksek geçiren (uğultu yok).
    lp = hp_prev_in = hp_prev_out = 0.0
    a_lp = 1 - math.exp(-2 * math.pi * 4200 / RATE)
    a_hp = math.exp(-2 * math.pi * 300 / RATE)
    samples = []
    for i in range(n):
        t = i / RATE
        white = rnd.uniform(-1, 1)
        lp += a_lp * (white - lp)
        hp = a_hp * (hp_prev_out + lp - hp_prev_in)
        hp_prev_in, hp_prev_out = lp, hp
        # Seviye yavaşça dalgalanır (sinyal gelip gidiyor gibi).
        level = 0.55 + 0.25 * math.sin(2 * math.pi * 1.3 * t) + 0.1 * math.sin(2 * math.pi * 3.7 * t)
        s = hp * level
        # Kayan ıslık: 900 → 1600 Hz arası, kısık.
        f = 900 + 700 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.66 * t))
        s += 0.06 * math.sin(2 * math.pi * f * t)
        # Seyrek çıtırtı.
        if rnd.random() < 0.0009:
            s += rnd.choice((-1, 1)) * rnd.uniform(0.6, 1.0)
        samples.append(s)
    peak = max(abs(x) for x in samples) or 1
    fade = int(RATE * FADE)
    out = bytearray()
    for i, x in enumerate(samples):
        g = min(1.0, i / fade, (n - 1 - i) / fade)
        out += struct.pack("<h", int(max(-1, min(1, x / peak * 0.8 * g)) * 32767))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(out))
    print(f"{OUT.name}: {OUT.stat().st_size} bayt")


if __name__ == "__main__":
    main()
