"""TC-06, TC-07, TC-08 (docs/test-plan.md): tìm kiếm, các tab chính và màn chi tiết.

Mỗi test gửi MỘT chỉ dẫn và so sánh giá trị agent báo lại. Điều kiện đầu: tài khoản test đã đăng nhập;
TC-08 cần ít nhất một đơn đã nhận. Bỏ qua khi chưa có máy chủ ARTEMIS hoặc `ARTEMIS_DEVICE_SERIAL`.
"""
import json
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


async def test_tc06_search_no_results(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, đang ở Trang chủ. Chạm ô tìm kiếm, gõ \"pizza hải sản\" (không có trong thực "
        "đơn) và đợi kết quả. Ghi thông báo của màn không có kết quả và số món tìm thấy.",
        expected_output='JSON: {"result_count": số món tìm thấy, "empty_message": thông báo hiện ra}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert int(data["result_count"]) == 0
    assert data["empty_message"].strip()


async def test_tc07_main_tabs(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập. Lần lượt chạm các tab ở thanh dưới: "Thực đơn", "Đơn hàng", "Cá nhân", '
        '"Trang chủ". Sau mỗi lần chạm, ghi tiêu đề hoặc nội dung chính ở đầu màn hình.',
        expected_output=(
            'JSON: {"menu": tiêu đề màn Thực đơn, "orders": tiêu đề màn Đơn hàng, '
            '"profile": tiêu đề màn Cá nhân, "home_has_kiosk_name": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "thực đơn" in data["menu"].lower()
    assert "đơn" in data["orders"].lower()
    assert data["profile"].strip()
    assert data["home_has_kiosk_name"] is True


async def test_tc08_item_and_order_detail(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có ít nhất một đơn đã nhận. Ở tab Thực đơn chạm vào món đầu tiên để mở "
        "chi tiết, ghi tên và giá. Quay lại, mở tab Đơn hàng, chạm một đơn đã nhận để mở chi tiết đơn; ghi mã "
        "đơn, trạng thái và tổng tiền trong phần hoá đơn.",
        expected_output=(
            'JSON: {"item_name": tên món, "item_price": giá món, "order_code": mã đơn, '
            '"order_status": trạng thái, "order_total": tổng tiền}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["item_name"].strip()
    assert int(re.sub(r"\D", "", str(data["item_price"]))) > 0
    assert str(data["order_code"]).strip()
    assert data["order_status"].strip()
    assert int(re.sub(r"\D", "", str(data["order_total"]))) > 0
