"""TC-25 đến TC-29 (docs/test-plan.md): quản lý món, quán và thống kê ca của nhân viên (K08–K11, K14, K15).

Điều kiện đầu: đăng nhập bằng tài khoản có vai staff và `kioskId` là Kiosk Q9 · Tầng 2 (P3 gán bằng
`set-role.mjs`). Mỗi test chỉ kiểm phần nhìn thấy trên máy của nhân viên; phần "khách thấy ngay" của TC-25,
TC-26, TC-27 cần máy thứ hai và đã được kiểm bằng `integration_test/firebase_emulator_test.dart`.
"""
import json


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


async def test_tc25_mark_item_sold_out(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2. Mở tab Món, gạt công tắc của món "
        'đầu tiên sang tắt, chọn "Máy hỏng" và mốc giờ thứ hai trong "Có lại lúc", chạm "Xác nhận hết món". '
        "Ghi dòng chữ dưới tên món đó và màu của nó.",
        expected_output='JSON: {"row_text": dòng chữ dưới tên món, "row_text_is_red": true hoặc false}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Hết · có lại" in data["row_text"]
    assert data["row_text_is_red"] is True


async def test_tc26_add_and_edit_item(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2. Mở tab Món, chạm dấu + ở thanh "
        'trên, chạm "Lưu món" khi form còn trống và ghi các thông báo lỗi dưới ô. Gõ tên "Bún bò Huế", giá 45000, '
        "chạm + một lần ở thời gian chuẩn bị, lưu. Chạm món mới trong danh sách, đổi giá thành 48000, lưu. "
        "Ghi dòng chữ dưới tên món mới trong danh sách.",
        expected_output='JSON: {"empty_form_errors": danh sách thông báo lỗi, "row_text": dòng chữ dưới tên món}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    errors = " ".join(data["empty_form_errors"])
    assert "Nhập tên món." in errors
    assert "Nhập giá món." in errors
    assert data["row_text"] == "48.000đ · Còn hàng"


async def test_tc27_pause_kiosk_and_wait(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2. Mở tab Quán, ghi thời gian chờ "
        'đang hiện. Chạm "30 phút" cạnh "Tạm ngưng lâu hơn" và ghi dòng trạng thái ở thẻ trên cùng. Chạm "Nhận '
        'đơn lại ngay". Chạm + ở thời gian chờ hai lần và ghi số mới. Gạt công tắc "Đang nhận đơn" sang tắt, ghi '
        "dòng trạng thái, rồi gạt bật lại.",
        expected_output=(
            'JSON: {"wait_before": số phút, "paused_status": dòng trạng thái khi tạm ngưng, "wait_after": số phút, '
            '"closed_status": dòng trạng thái khi tắt công tắc}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Tạm ngưng" in data["paused_status"]
    assert int(data["wait_after"]) - int(data["wait_before"]) == 2
    assert data["closed_status"] == "Đang đóng cửa"


async def test_tc28_save_shop_information(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2. Mở tab Quán, gõ thông báo "
        '"Hết sốt", giờ mở cửa 25:00, số đơn tối đa 0, chạm "Lưu thông tin" và ghi các lỗi hiện dưới ô. Sửa giờ mở '
        'cửa thành 06:30 và số đơn thành 8, chạm "Lưu thông tin" lần nữa. Ghi thông báo và xem nút "Lưu thông '
        'tin" còn không.',
        expected_output=(
            'JSON: {"errors": danh sách lỗi sau lần lưu đầu, "saved_message": thông báo sau lần lưu thứ hai, '
            '"save_button_visible_after": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    errors = " ".join(data["errors"])
    assert "Nhập giờ dạng 06:30." in errors
    assert "Nhập số từ 1 đến 999" in errors
    assert "Đã lưu thông tin quán." in data["saved_message"]
    assert data["save_button_visible_after"] is False


async def test_tc29_shift_statistics(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2; hôm nay đã có đơn đã giao, đơn "
        'bị từ chối và đơn đang xử lý. Mở tab Quán, chạm "Thống kê ca hôm nay". Ghi số ở các thẻ "Đơn đã làm", '
        '"Doanh thu", "Đơn huỷ", dòng "Đang xử lý" và giờ ở dòng "Cập nhật lúc". Chạm nút làm mới ở góc trên bên '
        "phải và ghi lại giờ cập nhật.",
        expected_output=(
            'JSON: {"delivered": số đơn đã làm, "revenue": doanh thu, "cancelled": số đơn huỷ, '
            '"active": số đơn đang xử lý, "updated_before": giờ cập nhật trước khi làm mới, '
            '"updated_after": giờ cập nhật sau khi làm mới}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert int(data["delivered"]) >= 1
    assert "đ" in data["revenue"]
    assert int(data["cancelled"]) >= 1
    assert int(data["active"]) >= 0
    assert data["updated_after"] >= data["updated_before"]
