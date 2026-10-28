# e2e_test/

Bộ test ARTEMIS (pytest). Xem `docs/test-plan.md` cho danh sách test và quy tắc.

## Cài một lần

1. Máy chủ ARTEMIS (Python 3.12, uv), ghim commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`:
   ```powershell
   git clone https://github.com/google/artemis.git
   cd artemis
   git checkout 351ca8422f7b5b54e80a9c1ce03a222e02415b6b
   copy .env.example .env      # điền khoá API của một mô hình (GEMINI_API_KEY, ANTHROPIC_API_KEY…), không commit
   .\start.bat                 # cài ADB, scrcpy, FFmpeg; mở http://localhost:8000
   ```
2. Điện thoại Android: bật **Tuỳ chọn nhà phát triển** và **Gỡ lỗi USB**, cắm cáp, bấm "Cho phép" trên máy. Kiểm tra bằng `adb devices`.
3. Cài app lên máy: `flutter run` hoặc `flutter install` (xem README gốc).

## Chạy test

```powershell
cd e2e_test
uv sync
$env:ARTEMIS_DEVICE_SERIAL = "<số seri trong adb devices>"
$env:ARTEMIS_PROFILE = "flash"     # "pro" chỉ cho phiên khám phá
uv run pytest -v
```

Mỗi test chạy ≥ 3 lần (`uv run pytest --count` cần plugin, hoặc lặp bằng vòng for); ghi kết quả vào bảng ở `docs/test-plan.md` mục 3 và lưu dấu vết (trace ID) trong `evidence/artemis/`.

Nhóm file theo tính năng: `test_auth.py`, `test_order.py`, `test_search.py`, `test_detail.py`, `test_export.py`, `test_profile.py`, `test_seller.py`.
