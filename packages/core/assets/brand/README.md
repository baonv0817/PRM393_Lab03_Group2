# BreakBite logo

A round cookie-like bun with a bite taken out of it (**Bite**) and a **B** in the middle; "Break" is the 15-minute class break. Brand orange background.

| File | Where it is used |
|---|---|
| `breakbite_logo.svg` | The Onboarding screen and anywhere else the app needs the logo (`BreakBiteLogo`) |
| `breakbite_logo_soft.svg` | Placeholder image on item cards when an item has no photo (`BreakBiteLogo(variant: LogoVariant.soft)`) |
| `breakbite_logo.png` (1024 px) | Report, slides, Figma. Not bundled into the app |

The Android app icon (`android/app/src/main/res/mipmap-*/ic_launcher.png`, plus the adaptive icon `ic_launcher_foreground.png`) is generated from the same parameters.

## Colors (Lab 2 tokens)

| Part | Color |
|---|---|
| Background | orange `#F69D39` |
| Bun | cream `#FFF5E5` |
| Letter B | cocoa brown `#622B14` |
| The name "Break" / "Bite" | brown `#622B14` / orange-brown `#B45309` (widget `BreakBiteWordmark`, Nunito ExtraBold) |

## Editing the logo

All sizes and colors are at the top of `scripts/make_logo.py`. Edit it, then re-run from the repo root:

```powershell
pip install pillow
python scripts/make_logo.py
```

The script overwrites the SVG, PNG and app-icon files in the table above. Remember to update Figma to match.
