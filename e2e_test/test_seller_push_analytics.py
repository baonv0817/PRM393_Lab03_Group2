"""TC-11, TC-12 (docs/test-plan.md): thông báo đẩy và quầy giao đơn (P4).

TC-11 cần app ở nền và một thông báo vừa gửi từ console (Messaging > tin thử tới token của thiết bị).
TC-12 cần tài khoản có quyền staff (`firebase/seed/set-role.mjs`) và một đơn đang chờ ở Kiosk Q9 · Tầng 2.
TC-13 (sự kiện Analytics `purchase`) đã gộp vào TC-03 trong test_order.py: cùng luồng đặt món, thêm bước đọc Logcat.
"""
import json
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


async def test_tc11_open_push_notification(artemis):
    result = await artemis.run(
        "BreakBite đang chạy ở nền và vừa nhận một thông báo đẩy. Kéo thanh thông báo của hệ thống xuống, chạm "
        "thông báo của BreakBite. Ghi tiêu đề thông báo và tên màn hình app mở ra.",
        expected_output='JSON: {"notification_title": tiêu đề thông báo, "opened_screen": tên màn hình mở ra}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["notification_title"].strip()
    assert data["opened_screen"].strip()


async def test_tc12_seller_accepts_and_delivers(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2, có một đơn ở tab "Mới". Mở đơn '
        'đầu tiên, chạm "Nhận đơn", rồi đánh dấu món đã sẵn sàng. Ghi mã nhận món của đơn. Mở tab quét mã, gõ mã '
        "nhận món đó, rồi xác nhận giao món (nếu là đơn tiền mặt thì xác nhận đã thu tiền). Ghi mã đơn và trạng thái cuối.",
        expected_output='JSON: {"order_code": mã đơn, "final_status": trạng thái cuối của đơn}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert str(data["order_code"]).strip()
    assert re.search(r"đã giao|hoàn tất|đã nhận", data["final_status"].lower())
