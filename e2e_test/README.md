# e2e_test/

Bộ test ARTEMIS (pytest). Xem `docs/test-plan.md` cho danh sách test và quy tắc.

Chạy (sau khi cài ARTEMIS và ghim commit):

```bash
cd e2e_test
uv sync
export ARTEMIS_DEVICE_SERIAL=<adb devices>
export ARTEMIS_PROFILE=flash
uv run pytest -v
```

Mỗi test chạy ≥ 3 lần; ghi kết quả vào bảng ở `docs/test-plan.md` mục 3. Nhóm file theo tính năng: `test_auth.py`, `test_order.py`, `test_search.py`, `test_detail.py`, `test_export.py`, `test_profile.py`, `test_seller.py`.
