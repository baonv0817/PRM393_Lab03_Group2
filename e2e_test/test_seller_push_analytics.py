"""TC-11, TC-12, TC-13 (docs/test-plan.md): thông báo đẩy, quầy giao đơn (P4) và một sự kiện Analytics.

TC-11 cần app ở nền và một thông báo vừa gửi từ console (Messaging > tin thử tới token của thiết bị).
TC-12 cần tài khoản có quyền staff (`firebase/seed/set-role.mjs`) và một đơn đang chờ ở Kiosk Q9 · Tầng 2.
TC-13 đọc Logcat qua ADB sau khi bật chế độ debug của Analytics:
  adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite
"""
import json
import os
import re
import shutil
import subprocess

import pytest


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


def adb(*args: str) -> str:
    serial = os.environ["ARTEMIS_DEVICE_SERIAL"]
    return subprocess.run(
        ["adb", "-s", serial, *args], capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
    ).stdout


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


async def test_tc13_purchase_event_logged(artemis):
    if not shutil.which("adb"):
        pytest.skip("Không có adb trong PATH")
    adb("logcat", "-c")
    result = await artemis.run(
        'BreakBite đang đăng nhập, giỏ trống. Ở Trang chủ chạm + của món đầu tiên, chạm "Giỏ hàng", tiếp tục '
        'thanh toán, giữ MoMo, chạm "Xác nhận" và xác nhận ở cổng thanh toán. Đợi màn Theo dõi đơn hiện ra.',
        expected_output='JSON: {"tracking_screen_visible": true hoặc false}',
    )
    assert result.succeeded, result.error or result.status
    assert parsed(result)["tracking_screen_visible"] is True
    log = adb("logcat", "-d", "-s", "FA", "FA-SVC")
    purchase = [line for line in log.splitlines() if "purchase" in line]
    assert purchase, "Không thấy sự kiện purchase trong Logcat (đã bật debug.firebase.analytics.app chưa?)"
    assert any("transaction_id" in line for line in purchase)
