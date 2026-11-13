"""Prepares the images of the final-assignment slides in slides/img-final/ (run before build_final_slides.js).

    python scripts/prepare_final_slides.py [VIDEO_WORK_DIR]

- screenshots from evidence/, resized (the originals are not changed);
- three frames of the demo video's two-screen parts (web beside phone), taken from the recorded parts in
  VIDEO_WORK_DIR (default: the video tools folder outside the repo); skipped when they are not there;
- white icons drawn from the Windows icon font (Segoe Fluent Icons), shown in coloured circles on the slides;
- sizes.json: the width and height of every image, so the deck keeps their proportions.
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "slides" / "img-final"
VIDEO = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:/PRM-ASM/handoff/tools/final_video/work")
FFMPEG = (r"C:/Users/An Nguyen/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/"
          r"ffmpeg-9.0.2-full_build/bin/ffmpeg.exe")

# name -> (source in evidence/, crop box or None, max height in px)
SHOTS = {
    "s02-home": ("p1/S02.png", None, 1200),
    "k02-staff": ("p4-real/K02-new-order.png", None, 1200),
    "w01-reject": ("web/W01-role-rejection.png", None, 900),
    "w02-menu": ("web/W02-menu.png", None, 900),
    "w03-queue": ("web/W03-review-queue.png", None, 900),
    "w04-stats": ("web/W04-dashboard.png", None, 900),
    "w05-ann": ("web/W05-published.png", None, 900),
    "k14-ai-on": ("ai/k14-ai-on.png", None, 1200),
    "k14-filled": ("ai/output-banh-mi-fields.png", None, 1200),
    "k14-not-food": ("ai/failure-not-food.png", None, 1200),
    "rules-run": ("rules/rules-run-2026-11-13.png", None, 900),
}

# name -> (phone recording of a video part, second; negative = from the end): the current screens of the phone
PHONE_FRAMES = {
    "s07-tracking": ("x1/phone.mp4", 2.0),
    "s19-inbox": ("x2/phone.mp4", -1.0),
}

# name -> (recorded part, second); the bottom caption bar of the video is cut off
FRAMES = {
    "x1-approved": ("x1/x1.mp4", 27.5),
    "x2-inbox": ("x2/x2.mp4", 30.0),
    "x3-ai-off": ("x3/x3.mp4", 31.0),
}

ICONS = {
    "person": 0xE77B, "people": 0xE716, "phone": 0xE8EA, "globe": 0xE774, "shield": 0xEA18, "robot": 0xE99A,
    "bulb": 0xEA80, "megaphone": 0xE789, "bug": 0xEBE8, "clock": 0xE823, "cloud": 0xE753, "lock": 0xE72E,
    "check": 0xE73E, "shop": 0xE719, "bell": 0xEA8F, "cart": 0xE7BF, "warning": 0xE7BA, "speed": 0xEC4A,
    "code": 0xE943, "sync": 0xE895, "chart": 0xE9D2, "camera": 0xE722, "settings": 0xE713,
}


def shot(name, src, box, max_h):
    im = Image.open(ROOT / "evidence" / src).convert("RGB")
    if box:
        im = im.crop(box)
    if im.height > max_h:
        im = im.resize((round(im.width * max_h / im.height), max_h), Image.LANCZOS)
    im.save(OUT / f"{name}.png", optimize=True)
    return im.size


def frame(name, part, second):
    src = VIDEO / part
    if not src.exists():
        return None
    tmp = OUT / f"{name}-full.png"
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-ss", str(second), "-i", str(src), "-frames:v", "1", str(tmp)],
                   check=True)
    im = Image.open(tmp).convert("RGB").crop((0, 0, 1280, 592))
    tmp.unlink()
    im.save(OUT / f"{name}.png", optimize=True)
    return im.size


def phone_frame(name, part, second):
    src = VIDEO / part
    if not src.exists():
        return None
    seek = ["-sseof", str(second)] if second < 0 else ["-ss", str(second)]
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *seek, "-i", str(src), "-frames:v", "1", str(OUT / f"{name}.png")],
                   check=True)
    return Image.open(OUT / f"{name}.png").size


def icon(name, code, size=256):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    font = ImageFont.truetype("C:/Windows/Fonts/SegoeIcons.ttf", int(size * 0.62))
    d = ImageDraw.Draw(im)
    l, t, r, b = d.textbbox((0, 0), chr(code), font=font)
    d.text(((size - (r - l)) / 2 - l, (size - (b - t)) / 2 - t), chr(code), font=font, fill=(255, 255, 255, 255))
    im.save(OUT / f"icon-{name}.png")
    return (size, size)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sizes = {}
    for name, (src, box, max_h) in SHOTS.items():
        sizes[name] = shot(name, src, box, max_h)
    for name, (part, second) in PHONE_FRAMES.items():
        old = OUT / f"{name}.png"
        size = phone_frame(name, part, second)
        if size:
            sizes[name] = size
        elif old.exists():
            sizes[name] = Image.open(old).size
    for name, (part, second) in FRAMES.items():
        old = OUT / f"{name}.png"
        size = frame(name, part, second)
        if size:
            sizes[name] = size
        elif old.exists():
            sizes[name] = Image.open(old).size
    for name, code in ICONS.items():
        sizes[f"icon-{name}"] = icon(name, code)
    (OUT / "sizes.json").write_text(json.dumps(sizes, indent=1), encoding="utf-8")
    print(len(sizes), "images in", OUT)


if __name__ == "__main__":
    main()
