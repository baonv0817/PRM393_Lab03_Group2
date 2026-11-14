"""Generate the PRMTacos logo: SVG (used in the app) and PNG (launcher icons, docs) from one parameter set.

Run from the repository root: `python scripts/make_logo.py` (requires Pillow: `pip install pillow`).

Concept: a warm golden tortilla medallion with a crispy bite taken out of the top-right rim, framing a folded
taco shell with wavy toppings and a bold 'T' monogram in cocoa brown on the brand orange tile.
Palette (Lab 2 tokens): brand orange #F69D39, cocoa brown #622B14, warm cream #FFF5E5, salsa accent #D94E1F.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8")
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

W = 512
TILE_R = 112
DISC_C, DISC_R = (256, 266), 172
BITE = [(-68, 38), (-44, 50), (-20, 38)]

VARIANTS = {
    "brand": dict(
        tile="#F69D39",
        disc="#FFF5E5",
        shell="#F8C67A",
        ink="#622B14",
        salsa="#D94E1F",
        herb="#2E7D32",
    ),
    "soft": dict(
        tile="#F3F0EA",
        disc="#F9CF98",
        shell="#F3B867",
        ink="#8A5D48",
        salsa="#C26D53",
        herb="#5E8B60",
    ),
}


def bite_circles():
    out = []
    for deg, r in BITE:
        a = math.radians(deg)
        out.append((DISC_C[0] + DISC_R * math.cos(a), DISC_C[1] + DISC_R * math.sin(a), r))
    return out


# Taco shell dome (flat bottom at y=332, arched top of radius 108)
TACO_ARC_CENTER = (256, 332)
TACO_ARC_R = 108
STROKE_OUTER = 20
STROKE_T = 22

# Filling puffs peeking out along the curved top arch of the taco shell (angle_deg, dist, radius, color_key)
FILLING_PUFFS_SPEC = [
    (208, 106, 24, "herb"),
    (232, 110, 26, "salsa"),
    (256, 112, 27, "herb"),
    (284, 112, 27, "salsa"),
    (308, 110, 26, "herb"),
    (332, 106, 24, "salsa"),
]


def filling_puffs():
    cx, cy = TACO_ARC_CENTER
    out = []
    for deg, dist, r, k in FILLING_PUFFS_SPEC:
        a = math.radians(deg)
        out.append((cx + dist * math.cos(a), cy + dist * math.sin(a), r, k))
    return out


# Tortilla toast spots on the taco shell
TOAST_DOTS = [
    (188, 296, 6.5),
    (324, 296, 6.5),
    (216, 310, 5.5),
    (296, 310, 5.5),
]


def svg(v):
    c = VARIANTS[v]
    bites = "\n  ".join(
        f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{c["tile"]}"/>' for x, y, r in bite_circles()
    )
    puffs = "\n  ".join(
        f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{c[k]}" stroke="{c["ink"]}" stroke-width="12"/>'
        for x, y, r, k in filling_puffs()
    )
    dots = "\n  ".join(
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c["salsa"]}"/>' for x, y, r in TOAST_DOTS
    )
    cx, cy = TACO_ARC_CENTER
    r = TACO_ARC_R
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{W}" viewBox="0 0 {W} {W}">
  <title>PRMTacos</title>
  <rect width="{W}" height="{W}" rx="{TILE_R}" fill="{c['tile']}"/>
  <circle cx="{DISC_C[0]}" cy="{DISC_C[1]}" r="{DISC_R}" fill="{c['disc']}"/>
  {bites}
  {puffs}
  <path d="M {cx - r} {cy} A {r} {r} 0 0 1 {cx + r} {cy} Z" fill="{c['shell']}" stroke="{c['ink']}" stroke-width="{STROKE_OUTER}" stroke-linejoin="round"/>
  {dots}
  <path d="M 226 262 H 286 M 256 262 V 314" fill="none" stroke="{c['ink']}" stroke-width="{STROKE_T}" stroke-linecap="round"/>
</svg>
"""


def stamp_line(draw, p1, p2, width, scale, color, ox=0, oy=0):
    rr = width / 2 * scale
    (x1, y1), (x2, y2) = p1, p2
    n = int(max(abs(x2 - x1), abs(y2 - y1)) * scale / 2) + 1
    for i in range(n + 1):
        x = x1 + (x2 - x1) * i / n
        y = y1 + (y2 - y1) * i / n
        draw.ellipse([x * scale + ox - rr, y * scale + oy - rr, x * scale + ox + rr, y * scale + oy + rr], fill=color)


def stamp_arc(draw, center, r, deg_start, deg_end, width, scale, color, ox=0, oy=0):
    rr = width / 2 * scale
    cx, cy = center
    n = int(math.pi * r * scale * abs(deg_end - deg_start) / 180 / 2) + 1
    for i in range(n + 1):
        deg = deg_start + (deg_end - deg_start) * i / n
        a = math.radians(deg)
        x = cx + r * math.cos(a)
        y = cy + r * math.sin(a)
        draw.ellipse([x * scale + ox - rr, y * scale + oy - rr, x * scale + ox + rr, y * scale + oy + rr], fill=color)


def draw_taco_emblem(d, c, scale, ox=0, oy=0):
    # 1. Wavy filling puffs peeking along the arched top of the taco shell
    for x, y, r, k in filling_puffs():
        ro = (r + 6) * scale
        ri = (r - 6) * scale
        px, py = x * scale + ox, y * scale + oy
        d.ellipse([px - ro, py - ro, px + ro, py + ro], fill=c["ink"])
        d.ellipse([px - ri, py - ri, px + ri, py + ri], fill=c[k])

    # 2. Filled half-moon taco shell (upper dome semicircle from 180 to 360 degrees)
    cx, cy = TACO_ARC_CENTER
    r = TACO_ARC_R
    bbox = [
        (cx - r) * scale + ox,
        (cy - r) * scale + oy,
        (cx + r) * scale + ox,
        (cy + r) * scale + oy,
    ]
    d.pieslice(bbox, start=180, end=360, fill=c["shell"])

    # 3. Outer cocoa brown border of the taco shell
    stamp_line(d, (cx - r, cy), (cx + r, cy), STROKE_OUTER, scale, c["ink"], ox, oy)
    stamp_arc(d, (cx, cy), r, 180, 360, STROKE_OUTER, scale, c["ink"], ox, oy)

    # 4. Subtle toast spots on tortilla
    for x, y, dr in TOAST_DOTS:
        px, py = x * scale + ox, y * scale + oy
        rr = dr * scale
        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=c["salsa"])

    # 5. Bold 'T' monogram in the center of the taco shell
    stamp_line(d, (226, 262), (286, 262), STROKE_T, scale, c["ink"], ox, oy)
    stamp_line(d, (256, 262), (256, 314), STROKE_T, scale, c["ink"], ox, oy)


def png(v, size):
    c = VARIANTS[v]
    s = 4
    big = W * s
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, big - 1, big - 1], radius=TILE_R * s, fill=c["tile"])
    cx, cy = DISC_C
    d.ellipse([(cx - DISC_R) * s, (cy - DISC_R) * s, (cx + DISC_R) * s, (cy + DISC_R) * s], fill=c["disc"])
    for x, y, r in bite_circles():
        d.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=c["tile"])
    draw_taco_emblem(d, c, s)
    return img.resize((size, size), Image.LANCZOS)


def foreground(px):
    """Android adaptive icon foreground (108 dp canvas, 66 dp safe zone)."""
    c = VARIANTS["brand"]
    s = 4
    size = px * s
    u = (62 / (2 * DISC_R)) * (px / 108) * s
    ox = size / 2 - DISC_C[0] * u
    oy = size / 2 - DISC_C[1] * u
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse(
        [
            ox + (DISC_C[0] - DISC_R) * u,
            oy + (DISC_C[1] - DISC_R) * u,
            ox + (DISC_C[0] + DISC_R) * u,
            oy + (DISC_C[1] + DISC_R) * u,
        ],
        fill=c["disc"],
    )
    for x, y, r in bite_circles():
        d.ellipse([ox + (x - r) * u, oy + (y - r) * u, ox + (x + r) * u, oy + (y + r) * u], fill=(0, 0, 0, 0))
    draw_taco_emblem(d, c, u, ox, oy)
    return img.resize((px, px), Image.LANCZOS)


def write(path, data):
    p = os.path.join(R, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(data)
    return p


write("packages/core/assets/brand/breakbite_logo.svg", svg("brand"))
write("packages/core/assets/brand/breakbite_logo_soft.svg", svg("soft"))
png("brand", 1024).save(os.path.join(R, "packages/core/assets/brand/breakbite_logo.png"))

for folder, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
    out_dir = os.path.join(R, f"mobile/android/app/src/main/res/mipmap-{folder}")
    os.makedirs(out_dir, exist_ok=True)
    png("brand", size).save(os.path.join(out_dir, "ic_launcher.png"))

for folder, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
    out_dir = os.path.join(R, f"mobile/android/app/src/main/res/mipmap-{folder}")
    os.makedirs(out_dir, exist_ok=True)
    foreground(px).save(os.path.join(out_dir, "ic_launcher_foreground.png"))

# Also update web icons so Web Admin tab icon matches PRMTacos
for web_icon, size in [
    ("web/web/favicon.png", 64),
    ("web/web/icons/Icon-192.png", 192),
    ("web/web/icons/Icon-512.png", 512),
    ("web/web/icons/Icon-maskable-192.png", 192),
    ("web/web/icons/Icon-maskable-512.png", 512),
]:
    full = os.path.join(R, web_icon)
    if os.path.exists(os.path.dirname(full)):
        png("brand", size).save(full)

print("Generated PRMTacos brand SVGs, 1024px PNG, Android adaptive launcher icons, and Web icons.")
