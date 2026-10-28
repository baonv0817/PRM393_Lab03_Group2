"""Sinh logo BreakBite: SVG (dùng trong app) và PNG (icon app, tài liệu) từ cùng một bộ tham số.

Chạy từ gốc repo: `python scripts/make_logo.py` (cần Pillow: `pip install pillow`).

Ý tưởng: chiếc bánh tròn bị cắn một miếng (Bite) với chữ B nâu cacao ở giữa, trên nền cam thương hiệu.
Màu theo bảng màu Lab 2: cam F69D39, nâu 622B14, kem FFF5E5.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # gốc repo

W = 512
TILE_R = 112                      # bo góc nền
DISC_C, DISC_R = (256, 268), 168  # chiếc bánh
BITE = [(-70, 40), (-45, 52), (-20, 40)]  # (góc, bán kính) của ba dấu cắn trên mép bánh
STROKE = 40                       # nét chữ B

# Chữ B: thân đứng + hai bụng (đoạn thẳng và nửa đường tròn), nét tròn đầu.
B_SEGMENTS = [
    ("line", (205, 185), (205, 361)),
    ("line", (205, 185), (255, 185)),
    ("arc", (255, 227), 42),          # bụng trên, tâm, bán kính; từ -90 đến 90 độ
    ("line", (255, 269), (205, 269)),
    ("line", (205, 269), (265, 269)),
    ("arc", (265, 315), 46),          # bụng dưới
    ("line", (265, 361), (205, 361)),
]
B_PATH = ("M205 185 V361 M205 185 H255 A42 42 0 0 1 255 269 H205 "
          "M205 269 H265 A46 46 0 0 1 265 361 H205")

VARIANTS = {
    # nền cam, bánh kem, chữ nâu: icon app, màn Onboarding
    "brand": dict(tile="#F69D39", disc="#FFF5E5", ink="#622B14"),
    # nền xám nhạt, bánh cam nhạt, chữ nâu nhạt: ảnh giữ chỗ trên thẻ món
    "soft": dict(tile="#F3F0EA", disc="#F9CF98", ink="#8A5D48"),
}


def bite_circles():
    out = []
    for deg, r in BITE:
        a = math.radians(deg)
        out.append((DISC_C[0] + DISC_R * math.cos(a), DISC_C[1] + DISC_R * math.sin(a), r))
    return out


def svg(v):
    c = VARIANTS[v]
    bites = "\n  ".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{c["tile"]}"/>' for x, y, r in bite_circles())
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">
  <title>BreakBite</title>
  <rect width="{W}" height="{W}" rx="{TILE_R}" fill="{c['tile']}"/>
  <circle cx="{DISC_C[0]}" cy="{DISC_C[1]}" r="{DISC_R}" fill="{c['disc']}"/>
  {bites}
  <path d="{B_PATH}" fill="none" stroke="{c['ink']}" stroke-width="{STROKE}" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def stamp_path(draw, scale, color, ox=0, oy=0):
    """Vẽ nét chữ B bằng cách đóng dấu hình tròn dày đặc dọc đường đi (giống nét SVG đầu tròn)."""
    rr = STROKE / 2 * scale
    for seg in B_SEGMENTS:
        pts = []
        if seg[0] == "line":
            (x1, y1), (x2, y2) = seg[1], seg[2]
            n = int(max(abs(x2 - x1), abs(y2 - y1)) * scale / 2) + 1
            pts = [(x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n) for i in range(n + 1)]
        else:
            (cx, cy), r = seg[1], seg[2]
            n = int(math.pi * r * scale / 2) + 1
            pts = [(cx + r * math.cos(math.radians(-90 + 180 * i / n)), cy + r * math.sin(math.radians(-90 + 180 * i / n))) for i in range(n + 1)]
        for x, y in pts:
            draw.ellipse([x * scale + ox - rr, y * scale + oy - rr, x * scale + ox + rr, y * scale + oy + rr], fill=color)


def png(v, size):
    c = VARIANTS[v]
    s = 4                                    # lấy mẫu dày để mép mịn
    big = W * s
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, big - 1, big - 1], radius=TILE_R * s, fill=c["tile"])
    cx, cy = DISC_C
    d.ellipse([(cx - DISC_R) * s, (cy - DISC_R) * s, (cx + DISC_R) * s, (cy + DISC_R) * s], fill=c["disc"])
    for x, y, r in bite_circles():
        d.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=c["tile"])
    stamp_path(d, s, c["ink"])
    return img.resize((size, size), Image.LANCZOS)


def foreground(px):
    """Lớp nền trước của icon thích ứng Android: khung 108 dp, trong suốt, bánh nằm gọn vùng an toàn 66 dp.
    Lớp nền sau là màu cam thương hiệu (values/ic_launcher_background.xml)."""
    c = VARIANTS["brand"]
    s = 4
    size = px * s
    u = (62 / (2 * DISC_R)) * (px / 108) * s     # đơn vị logo sang điểm ảnh: bánh rộng 62 dp
    ox = size / 2 - DISC_C[0] * u                # đưa tâm bánh về giữa khung
    oy = size / 2 - DISC_C[1] * u
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([ox + (DISC_C[0] - DISC_R) * u, oy + (DISC_C[1] - DISC_R) * u,
               ox + (DISC_C[0] + DISC_R) * u, oy + (DISC_C[1] + DISC_R) * u], fill=c["disc"])
    for x, y, r in bite_circles():               # miếng cắn là lỗ trong suốt, lộ nền cam phía sau
        d.ellipse([ox + (x - r) * u, oy + (y - r) * u, ox + (x + r) * u, oy + (y + r) * u], fill=(0, 0, 0, 0))
    stamp_path(d, u, c["ink"], ox, oy)
    return img.resize((px, px), Image.LANCZOS)


def write(path, data, mode="w"):
    p = os.path.join(R, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if mode == "w":
        open(p, "w", encoding="utf-8", newline="\n").write(data)
    return p


write("assets/brand/breakbite_logo.svg", svg("brand"))
write("assets/brand/breakbite_logo_soft.svg", svg("soft"))
png("brand", 1024).save(os.path.join(R, "assets/brand/breakbite_logo.png"))

for folder, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    png("brand", size).save(os.path.join(R, f"android/app/src/main/res/mipmap-{folder}/ic_launcher.png"))

for folder, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
    foreground(px).save(os.path.join(R, f"android/app/src/main/res/mipmap-{folder}/ic_launcher_foreground.png"))

write("android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml", """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""")
write("android/app/src/main/res/values/ic_launcher_background.xml", """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F69D39</color>
</resources>
""")
print("Đã ghi assets/brand/ và icon app (kiểu cũ và adaptive) trong android/app/src/main/res/")
