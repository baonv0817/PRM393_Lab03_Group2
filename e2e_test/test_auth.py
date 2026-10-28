"""TC-01 và TC-02. Mẫu theo handout; điền kết quả khi có app.

Mỗi test: một chỉ dẫn nêu điểm bắt đầu, các bước, điều phải thấy; yêu cầu agent báo lại giá trị
để so sánh, không chỉ kiểm status.
"""
import pytest

pytestmark = pytest.mark.skip(reason="Chưa có app để chạy")


async def test_tc01_sign_in(artemis):
    result = await artemis.run(
        "Ứng dụng BreakBite đã cài và đang đăng xuất. Mở app, chạm đăng nhập bằng Google, "
        "chọn tài khoản test. Xác nhận màn Trang chủ hiện, thanh dưới có 4 tab, "
        "và báo lại tên kiosk hiển thị ở thanh trên cùng."
    )
    assert result.status == "SUCCESS", result.error
    # TODO: so sánh tên kiosk báo về với giá trị mong đợi


async def test_tc02_sign_out(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập. Mở tab Cá nhân, chạm Đăng xuất. Xác nhận màn đăng nhập hiện; "
        "nhấn Back và xác nhận không vào lại được Trang chủ."
    )
    assert result.status == "SUCCESS", result.error
