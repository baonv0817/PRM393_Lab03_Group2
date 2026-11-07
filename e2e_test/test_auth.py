"""TC-01 và TC-02 (docs/test-plan.md).

Mỗi test gửi MỘT chỉ dẫn nêu điểm bắt đầu, các bước và điều phải thấy; yêu cầu agent báo lại giá trị
cụ thể bằng `expected_output` rồi so sánh, không chỉ kiểm `result.succeeded`.
Bỏ qua khi chưa có máy chủ ARTEMIS hoặc `ARTEMIS_DEVICE_SERIAL` (fixture `artemis`).
"""
import json


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


async def test_tc01_sign_in(artemis):
    result = await artemis.run(
        "Ứng dụng BreakBite đã cài và đang đăng xuất. Mở app, chạm đăng nhập bằng Google, "
        "chọn tài khoản test. Xác nhận màn Trang chủ hiện và thanh dưới có 4 tab.",
        expected_output='JSON: {"tab_count": số tab ở thanh dưới, "kiosk": tên kiosk ở thanh trên cùng}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["tab_count"] == 4
    assert "Kiosk" in data["kiosk"]


async def test_tc02_sign_out(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập. Mở tab Cá nhân, chạm Đăng xuất. Xác nhận màn đăng nhập hiện; "
        "nhấn Back và xác nhận không vào lại được Trang chủ.",
        expected_output='JSON: {"sign_in_screen_visible": true hoặc false, "home_visible_after_back": true hoặc false}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["sign_in_screen_visible"] is True
    assert data["home_visible_after_back"] is False
