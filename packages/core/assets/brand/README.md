# PRMTacos logo

A round tortilla medallion with a bite taken out of it, framing a folded taco shell (`⌓`) with herb and salsa toppings and a bold **T** monogram in the middle. Brand orange background.

| File | Where it is used |
|---|---|
| `breakbite_logo.svg` | The Onboarding screen and anywhere else the app needs the logo (`BreakBiteLogo`) |
| `breakbite_logo_soft.svg` | Placeholder image on item cards when an item has no photo (`BreakBiteLogo(variant: LogoVariant.soft)`) |
| `breakbite_logo.png` (1024 px) | Report, slides, Figma. Not bundled into the app |

The Android app icon (`mobile/android/app/src/main/res/mipmap-*/ic_launcher.png`, plus the adaptive icon `ic_launcher_foreground.png`) and Web Admin icons (`web/web/favicon.png`, `web/web/icons/Icon-*.png`) are generated from the same parameters.

## Colors (Lab 2 tokens)

| Part | Color |
|---|---|
| Background | orange `#F69D39` |
| Tortilla medallion | cream `#FFF5E5` |
| Taco shell | golden tortilla `#F8C67A` |
| Letter T & outline | cocoa brown `#622B14` |
| Salsa / herb toppings | `#D94E1F` / `#2E7D32` |
| The name "PRM" / "Tacos" | brown `#622B14` / orange-brown `#B45309` (widget `BreakBiteWordmark`, Nunito ExtraBold) |

## Editing the logo

All sizes and colors are at the top of `scripts/make_logo.py`. Edit it, then re-run from the repo root:

```powershell
pip install pillow
python scripts/make_logo.py
```

The script overwrites the SVG, PNG and app-icon files in the table above. Remember to update Figma to match.
