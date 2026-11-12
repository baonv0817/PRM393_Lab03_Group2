"""Crops the console screenshots in evidence/ to the part each slide talks about, into slides/img/.

Run from the repo root before scripts/build_slides.js:
    python scripts/prepare_slide_images.py

The originals in evidence/ are not changed. Boxes are (left, top, right, bottom) in pixels of the original file.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'slides' / 'img'

CROPS = {
    # Crashlytics: the two non-fatal issues, the test crash, and the keys of one event
    'crash-nonfatal.png': ('evidence/crashlytics/1-non-fatal.png', (290, 515, 1410, 728)),
    'crash-fatal.png': ('evidence/crashlytics/2-crash.png', (290, 590, 1410, 720)),
    'crash-keys.png': ('evidence/crashlytics/3-keys.png', (278, 340, 1370, 600)),
    # Remote Config: the parameter table after quick_items_limit was published as 2
    'rc-console.png': ('evidence/remote-config/2-console.png', (278, 530, 1400, 760)),
    # Remote Config: top of Home before (defaults) and after the publish (no banner, 2 quick items)
    'rc-before.png': ('evidence/remote-config/1-before.png', (0, 0, 1080, 1320)),
    'rc-after.png': ('evidence/remote-config/3-after.png', (0, 0, 1080, 1320)),
    # Cloudinary: the receipt in breakbite/reports/{uid}
    'cloudinary-library.png': ('evidence/storage/4-cloudinary-library.png', (290, 40, 1528, 560)),
    # Firestore: the reports document that holds the URL
    'firestore-reports.png': ('evidence/storage/5-firestore-reports.png', (250, 260, 1450, 650)),
    # Analytics: DebugView event stream and top events
    'debugview.png': ('evidence/analytics/debugview-top-events.png', (310, 210, 970, 890)),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (src, box) in CROPS.items():
        with Image.open(ROOT / src) as im:
            im.convert('RGB').crop(box).save(OUT / name)
        print('wrote', (OUT / name).relative_to(ROOT))


if __name__ == '__main__':
    main()
