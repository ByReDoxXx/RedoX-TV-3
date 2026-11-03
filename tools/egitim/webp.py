"""Öğretici hikâye görüntüleri: build/egitim/<cihaz>/*.png → assets/tutorial/<cihaz>/*.webp.

Önce: REDOX_TUTORIAL=1 flutter test test/tutorial/tutorial_shots_test.dart
Kullanım: python tools/egitim/webp.py
"""
import pathlib
import shutil

from PIL import Image

src = pathlib.Path('build/egitim')
dst = pathlib.Path('assets/tutorial')
total = 0
for device in sorted(p for p in src.iterdir() if p.is_dir()):
    out = dst / device.name
    out.mkdir(parents=True, exist_ok=True)
    for png in sorted(device.glob('*.png')):
        target = out / f'{png.stem}.webp'
        Image.open(png).convert('RGB').save(target, 'WEBP', quality=72, method=6)
        total += target.stat().st_size
    shutil.copy(device / 'manifest.json', out / 'manifest.json')
print(f'{total / 1024 / 1024:.2f} MB')
