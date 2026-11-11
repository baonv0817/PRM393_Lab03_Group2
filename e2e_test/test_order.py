"""TC-03, TC-04, TC-05, TC-17, TC-30, TC-31 (docs/test-plan.md): luồng đặt món của P1 (F1, F2, F3, S21, S22).

Mỗi test gửi MỘT chỉ dẫn nêu điểm bắt đầu, các bước và điều phải thấy; agent phải báo lại giá trị cụ thể
bằng `expected_output` để test so sánh, không chỉ kiểm `result.succeeded`.

Điều kiện đầu: tài khoản test đã đăng nhập, kiosk "Kiosk Q9 · Tầng 2" đang chọn, dữ liệu mẫu của seed.
Test chỉ chạy khi có máy chủ ARTEMIS và `ARTEMIS_DEVICE_SERIAL`; nếu không, fixture `artemis` bỏ qua test.
"""
import json
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


def vnd(text) -> int:
    """'78.000đ' hoặc 78000 thành 78000."""
    return int(re.sub(r"\D", "", str(text)))


async def test_tc03_quick_order(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, giỏ hàng trống, đang ở Trang chủ. Chạm nút + của món đầu tiên, rồi chạm nút "
        '"Giỏ hàng" ở góc dưới bên phải. Chạm tiếp tục để thanh toán, giữ phương thức MoMo, chạm "Xác nhận", '
        "rồi xác nhận thanh toán ở màn cổng thanh toán. Đợi màn Theo dõi đơn hiện ra.",
        expected_output=(
            'JSON: {"tracking_screen_visible": true hoặc false, "pickup_code": mã nhận món đang hiện, '
            '"total": tổng tiền đang hiện}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["tracking_screen_visible"] is True
    assert re.fullmatch(r"\d{6}", re.sub(r"\s", "", str(data["pickup_code"])))
    assert vnd(data["total"]) > 0


async def test_tc04_wrong_voucher(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập. Nếu giỏ đang trống, chạm nút + của món đầu tiên ở Trang chủ một lần để giỏ có "
        "đúng 1 món. Mở giỏ hàng, chạm ô voucher. Chạm vào ô nhập có chữ gợi ý "
        "\"Nhập mã giảm giá\", GÕ BB20 vào ô đó (kiểm tra ô đã hiện BB20), rồi mới chạm \"Áp dụng\"; "
        "ghi trạng thái của BB20 trong danh sách và thông báo dưới ô nhập. Quay lại, thêm một món thứ hai vào giỏ, "
        "mở lại ô voucher, chọn BBSTUDENT, quay về giỏ rồi xoá bớt một món. Ghi thông báo giỏ hàng hiện ra, "
        'xem nút thanh toán có bấm được không và ghi tổng tiền trước và sau khi chọn "Bỏ mã".',
        expected_output=(
            'JSON: {"bb20_label": chữ cạnh BB20 trong danh sách, "bb20_message": thông báo dưới ô nhập, '
            '"cart_message": thông báo giỏ hàng sau khi xoá món, "checkout_enabled": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "hết hạn" in data["bb20_label"].lower()
    assert "BB20" in data["bb20_message"] and "hết hạn" in data["bb20_message"].lower()
    assert "40.000" in data["cart_message"] and "BBSTUDENT" in data["cart_message"]
    assert data["checkout_enabled"] is False


async def test_tc05_payment_declined_then_cash_then_cancel(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, giỏ có 1 món. Mở giỏ, tiếp tục thanh toán, chạm \"Xác nhận\". Ở màn cổng "
        'thanh toán chạm "Từ chối". Ghi xem giỏ còn món không. Chọn "Tiền mặt tại Kiosk" và đặt lại. Ở màn đơn '
        'hàng chạm "Huỷ đơn" và xác nhận. Ghi mã đơn và câu hiện trên màn "Đơn đã huỷ".',
        expected_output=(
            'JSON: {"cart_kept_after_decline": true hoặc false, "order_code": mã đơn, '
            '"cancelled_screen_visible": true hoặc false, "cancel_line": câu trên màn đơn đã huỷ}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["cart_kept_after_decline"] is True
    assert str(data["order_code"]).strip()
    assert data["cancelled_screen_visible"] is True
    assert "Bạn đã huỷ đơn này" in data["cancel_line"]


async def test_tc17_home_stepper(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, giỏ trống, đang ở Trang chủ. Chạm + của món đầu tiên, rồi chạm + trên bộ đếm "
        "của món đó hai lần. Ghi số trên bộ đếm và số trên biểu tượng giỏ. Sau đó chạm − ba lần. Ghi xem nút + "
        "đơn có hiện lại không và giỏ còn số không.",
        expected_output=(
            'JSON: {"stepper_count": số trên bộ đếm, "cart_badge": số trên biểu tượng giỏ, '
            '"plus_button_back": true hoặc false, "cart_badge_after": số trên biểu tượng giỏ sau cùng hoặc 0}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert int(data["stepper_count"]) == 3
    assert int(data["cart_badge"]) == 3
    assert data["plus_button_back"] is True
    assert int(data["cart_badge_after"] or 0) == 0


async def test_tc30_sold_out_alternatives(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, kiosk Q9 · Tầng 2, giỏ trống, có một món ăn đang tạm hết. Mở tab Thực đơn, "
        'chạm thẻ có nhãn "Tạm hết". Trên màn "Món tạm hết", chạm + của món đầu tiên trong mục '
        '"Gợi ý thay thế còn hàng", rồi chạm + trên bộ đếm của nó thêm một lần.',
        expected_output=(
            'JSON: {"screen_title": tiêu đề màn hình, "first_alternative": tên món thay thế đầu tiên, '
            '"cart_badge": số trên nút giỏ hàng}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "tạm hết" in data["screen_title"].lower()
    assert data["first_alternative"].strip()
    assert int(data["cart_badge"]) == 2


async def test_tc31_closed_kiosk(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập, đang ở Trang chủ. Chạm tên kiosk, chọn "Nhà văn hóa SV · Tầng 1" và xác nhận. '
        "Ghi dòng trạng thái dưới tên kiosk và tiêu đề thẻ thông báo. Sau đó chạm \"Chọn kiosk khác\" trên thẻ, "
        'chọn "Kiosk Q9 · Tầng 2" và xác nhận; xem mục "Món nhanh" có hiện lại không.',
        expected_output=(
            'JSON: {"status_line": dòng trạng thái, "card_title": tiêu đề thẻ, '
            '"quick_section_back": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Đóng" in data["status_line"] and "07:00" in data["status_line"]
    assert "đóng cửa" in data["card_title"].lower()
    assert data["quick_section_back"] is True
