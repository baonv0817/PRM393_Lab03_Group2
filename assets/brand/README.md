# Logo BreakBite

Chiếc bánh tròn bị cắn một miếng (**Bite**) với chữ **B** ở giữa; "Break" là giờ giải lao 15 phút. Nền cam thương hiệu.

| File | Dùng ở đâu |
|---|---|
| `breakbite_logo.svg` | Màn Onboarding và mọi nơi cần logo trong app (`BreakBiteLogo`) |
| `breakbite_logo_soft.svg` | Ảnh giữ chỗ trên thẻ món khi món chưa có ảnh (`BreakBiteLogo(variant: LogoVariant.soft)`) |
| `breakbite_logo.png` (1024 px) | Báo cáo, slide, Figma. Không đóng gói vào app |

Icon app Android (`android/app/src/main/res/mipmap-*/ic_launcher.png`) cũng sinh từ cùng bộ tham số.

## Màu (token Lab 2)

| Phần | Màu |
|---|---|
| Nền | cam `#F69D39` |
| Bánh | kem `#FFF5E5` |
| Chữ B | nâu cacao `#622B14` |
| Tên "Break" / "Bite" | nâu `#622B14` / cam nâu `#B45309` (widget `BreakBiteWordmark`, font Nunito ExtraBold) |

## Sửa logo

Mọi kích thước và màu nằm ở đầu `scripts/make_logo.py`. Sửa rồi chạy lại từ gốc repo:

```powershell
pip install pillow
python scripts/make_logo.py
```

Script ghi đè các file SVG, PNG và icon app ở bảng trên. Nhớ cập nhật Figma cho khớp.
