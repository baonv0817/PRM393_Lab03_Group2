"""TC-18 đến TC-24 (docs/test-plan.md): các màn sau khi đặt món của P2 (S09–S12, S20, S23, S24).

Mỗi test gửi MỘT chỉ dẫn nêu điểm bắt đầu, các bước và điều phải thấy; agent phải báo lại giá trị cụ thể
bằng `expected_output` để test so sánh, không chỉ kiểm `result.succeeded`.

Điều kiện đầu của từng test là tài khoản test đã đăng nhập và đã có đơn như cột Precondition trong test plan
(một đơn đã nhận, một đơn vừa đặt bằng tiền mặt chưa được bếp nhận). Test chỉ chạy khi có máy chủ ARTEMIS và
`ARTEMIS_DEVICE_SERIAL`; nếu không, fixture `artemis` bỏ qua test.
"""
import json
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


async def test_tc18_export_receipt(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có ít nhất một đơn đã nhận. Mở tab Đơn hàng, chạm một đơn đã nhận, "
        'chạm "Xuất biên nhận PDF". Quan sát thanh tiến trình "Đang tải lên …%", đợi đến khi hiện '
        '"Đã tải lên", ghi tên tệp và dung lượng. Thoát ra rồi mở lại đúng đơn đó và xem mục "Biên nhận đã xuất".',
        expected_output=(
            'JSON: {"progress_seen": true hoặc false, "file_name": tên tệp, "size_kb": số nguyên KB, '
            '"listed_after_reopen": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["progress_seen"] is True
    assert data["file_name"].lower().endswith(".pdf")
    assert int(data["size_kb"]) > 0
    assert data["listed_after_reopen"] is True


async def test_tc19_export_receipt_offline(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập, đang mở chi tiết một đơn đã nhận (màn Chi tiết đơn). Bật chế độ máy bay từ "
        'thanh cài đặt nhanh, quay lại app, chạm "Xuất biên nhận PDF". Ghi thông báo hiện ra, xem có thẻ '
        '"Đã tải lên" không và nút xuất có bấm lại được không. Tắt chế độ máy bay sau khi xong.',
        expected_output=(
            'JSON: {"message": nội dung thông báo, "uploaded_card_visible": true hoặc false, '
            '"export_button_enabled": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["message"].strip()
    assert data["uploaded_card_visible"] is False
    assert data["export_button_enabled"] is True


async def test_tc20_order_history(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có ít nhất hai đơn đã nhận hoặc đã huỷ. Mở tab Đơn hàng, tab Lịch sử, chạm "
        '"Xem toàn bộ lịch sử". Ghi số tiền ở thẻ "Chi tiêu tuần này", rồi chạm tab "Tháng" (thẻ đổi thành '
        '"Chi tiêu tháng …"), rồi tab "Tuần". Ghi tiêu đề nhóm đầu tiên và dòng tóm tắt của nó. Chạm đơn đầu tiên.',
        expected_output=(
            'JSON: {"week_total": số tiền ở thẻ chi tiêu, "month_card_title": tiêu đề thẻ ở tab Tháng, '
            '"first_heading": tiêu đề nhóm đầu, "summary_line": dòng tóm tắt dưới tiêu đề, '
            '"detail_opened": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "đ" in data["week_total"]
    assert data["month_card_title"].startswith("Chi tiêu tháng")
    assert data["first_heading"].startswith("Tuần")
    assert "đơn" in data["summary_line"]
    assert data["detail_opened"] is True


async def test_tc21_edit_pending_order(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có một đơn tiền mặt vừa đặt mà bếp chưa nhận. Mở tab Đơn hàng, mở đơn đó, "
        'chạm "Sửa đơn", chạm + ở món đầu tiên, chạm "Lưu thay đổi". Ghi thông báo hiện ra và tổng tiền mới '
        "trên màn theo dõi đơn.",
        expected_output='JSON: {"message": nội dung thông báo, "new_total": tổng tiền mới}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Đã cập nhật đơn" in data["message"]
    assert "đ" in data["new_total"]


async def test_tc22_enlarge_pickup_qr(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có một đơn vừa đặt mà bếp chưa nhận. Mở tab Đơn hàng, mở đơn đó, chạm "
        '"Phóng to mã QR". Ghi mã 6 chữ số hiện dưới mã QR và dòng chữ giải thích trạng thái. Chạm nút đóng (X) '
        "và xem có quay lại màn theo dõi đơn không.",
        expected_output='JSON: {"code": mã 6 chữ số, "state_message": dòng giải thích, "returned_to_order": true hoặc false}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert re.fullmatch(r"\d{3}\s?\d{3}", data["code"].strip())
    assert "Kiosk chưa nhận đơn" in data["state_message"]
    assert data["returned_to_order"] is True


async def test_tc23_report_incident(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có một đơn đã nhận chưa báo sự cố. Mở tab Đơn hàng, mở đơn đã nhận, chạm "
        '"Báo sự cố với đơn này", chọn "Thiếu món", gõ "Thiếu 1 ly trà đào", chạm "Gửi báo cáo". Ghi thông báo '
        "và trạng thái báo cáo hiện ra. Thoát rồi mở lại đơn, chạm lại nút báo sự cố và xem form có hiện lại không.",
        expected_output=(
            'JSON: {"message": nội dung thông báo, "status": trạng thái của báo cáo, '
            '"form_shown_again": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Đã gửi báo cáo" in data["message"]
    assert "chờ kiosk" in data["status"].lower()
    assert data["form_shown_again"] is False


async def test_tc24_review_item(artemis):
    result = await artemis.run(
        "BreakBite đang đăng nhập và có một đơn đã nhận chưa đánh giá. Mở tab Đơn hàng, mở đơn đã nhận, chạm "
        '"Đánh giá món", chạm vòng tròn số 4 của món đầu tiên, chọn "Ngon", gõ "Vỏ giòn", chạm "Gửi đánh giá". '
        'Ghi thông báo. Mở lại "Đánh giá món" và ghi xem món đó có nhãn "Đã đánh giá" không và từ nằm dưới vòng '
        "tròn đang được chọn.",
        expected_output=(
            'JSON: {"message": nội dung thông báo, "reviewed_badge": true hoặc false, '
            '"selected_word": từ dưới vòng tròn đang chọn}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "Đã gửi 1 đánh giá" in data["message"]
    assert data["reviewed_badge"] is True
    assert data["selected_word"] == "Ngon"
