"""TC-42, TC-43 (docs/test-plan.md, docs/cross-role-flow.md): bước trên điện thoại của luồng liên vai trò.

Khách đặt đơn trên điện thoại → quầy duyệt (TC-42) hoặc từ chối kèm lý do (TC-43) → màn "Theo dõi đơn" (S07) của
khách đổi ngay, không cần mở lại.

ARTEMIS làm phần của khách trên điện thoại. Phần của quầy do `StaffDecision` làm thay trong lúc agent đang chờ ở S07:
nó đợi đơn mới của khách xuất hiện trong Firestore rồi ghi đúng các trường mà web admin (W03) ghi khi bấm
"Duyệt đơn" / "Từ chối đơn" (`FirestoreOrderRepository.accept` / `reject`). Lệnh ghi đi qua API REST của Firestore với
quyền của thành viên dự án (Security Rules không áp dụng cho quyền này), vì test này kiểm tra phía điện thoại; phía
web và rules đã có bằng chứng riêng: ba lần chạy thật trên hệ thống đã deploy (docs/cross-role-flow.md) và các test
rules R-47, R-48 (firebase/tests).

Điều kiện đầu:
- điện thoại đăng nhập bằng tài khoản khách, kiosk đang chọn là Kiosk Q9 · Tầng 2, giỏ hàng trống;
- Kiosk Q9 · Tầng 2 đang mở và giờ mở cửa ở K10 bao giờ chạy test;
- biến môi trường CROSS_ROLE_CUSTOMER_UID là uid của tài khoản khách đó (Firebase console, Authentication);
- đã `firebase login` trên máy chạy test (token lấy từ cấu hình của Firebase CLI), hoặc đặt sẵn
  CROSS_ROLE_ACCESS_TOKEN là một access token OAuth có quyền trên dự án.

Mỗi lần chạy tạo một đơn tiền mặt mới (được duyệt hoặc bị huỷ), nên các lần chạy không phụ thuộc nhau.
"""
import datetime as dt
import json
import os
import threading
import time

import pytest

from project_data import DOCS
from project_data import call as _call
from project_data import ts as _ts

REJECT_REASON = "Hết nguyên liệu"


class StaffDecision(threading.Thread):
    """Plays the kiosk on the web: waits for the customer's new pending order, then approves or rejects it."""

    def __init__(self, uid: str, action: str, *, delay_s: float = 15, timeout_s: float = 300):
        super().__init__(daemon=True)
        self.uid, self.action, self.delay_s, self.timeout_s = uid, action, delay_s, timeout_s
        self.started_at = dt.datetime.now(dt.timezone.utc)
        self.order_code: str | None = None
        self.decided_at: dt.datetime | None = None
        self.error: str | None = None

    def _new_pending_order(self) -> dict | None:
        query = {
            "structuredQuery": {
                "from": [{"collectionId": "orders"}],
                "where": {
                    "compositeFilter": {
                        "op": "AND",
                        "filters": [
                            {"fieldFilter": {"field": {"fieldPath": "uid"}, "op": "EQUAL", "value": {"stringValue": self.uid}}},
                            {"fieldFilter": {"field": {"fieldPath": "status"}, "op": "EQUAL", "value": {"stringValue": "pending"}}},
                        ],
                    }
                },
            }
        }
        rows = _call("POST", f"{DOCS}:runQuery", query)
        fresh = [
            row["document"]
            for row in rows
            if "document" in row and _ts(row["document"]["fields"]["createdAt"]) > self.started_at
        ]
        return max(fresh, key=lambda d: _ts(d["fields"]["createdAt"])) if fresh else None

    def _decide(self, order: dict) -> None:
        now = dt.datetime.now(dt.timezone.utc)
        if self.action == "approve":
            fields = {
                "status": {"stringValue": "preparing"},
                "readyBy": {"timestampValue": (now + dt.timedelta(minutes=10)).isoformat().replace("+00:00", "Z")},
            }
            stamps = ["acceptedAt", "updatedAt"]
        else:
            fields = {
                "status": {"stringValue": "cancelled"},
                "cancelledBy": {"stringValue": "staff"},
                "cancelReason": {"stringValue": REJECT_REASON},
            }
            stamps = ["cancelledAt", "updatedAt"]
        write = {
            "update": {"name": order["name"], "fields": fields},
            "updateMask": {"fieldPaths": list(fields)},
            "updateTransforms": [{"fieldPath": f, "setToServerValue": "REQUEST_TIME"} for f in stamps],
            "currentDocument": {"exists": True},
        }
        _call("POST", f"{DOCS}:commit", {"writes": [write]})

    def run(self) -> None:
        try:
            deadline = time.monotonic() + self.timeout_s
            while time.monotonic() < deadline:
                order = self._new_pending_order()
                if order:
                    self.order_code = order["fields"].get("orderCode", {}).get("stringValue")
                    # Give the agent time to land on S07 and start waiting, as a person at the counter would.
                    time.sleep(self.delay_s)
                    self._decide(order)
                    self.decided_at = dt.datetime.now(dt.timezone.utc)
                    return
                time.sleep(3)
            self.error = "no new pending order from the customer within the timeout"
        except Exception as error:  # noqa: BLE001 - reported by the test
            self.error = repr(error)


def parsed(result) -> dict:
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


PLACE_AND_WAIT = (
    "BreakBite đang đăng nhập bằng tài khoản khách, kiosk đang chọn là Kiosk Q9 · Tầng 2. Ở Trang chủ chạm dấu + "
    'của món "Cà Phê Sữa Đá" đúng một lần, rồi chạm nút giỏ hàng tròn ở góc dưới bên phải. Ở màn "Giỏ hàng" chạm '
    '"Tiếp tục thanh toán". Ở màn "Thanh toán" chọn "Tiền mặt tại kiosk" rồi chạm nút "Xác nhận đặt đơn". Màn '
    '"Theo dõi đơn" hiện ra, mã đơn bắt đầu bằng dấu #. Ở lại màn này: quầy sẽ xử lý đơn trên trang web. Chờ (mỗi lần '
    'chờ 5 giây, tối đa 90 giây) cho đến khi dòng chữ nhỏ ngay dưới mã đơn không còn là "Chờ kiosk nhận đơn". Ghi '
    "lại mã đơn, nguyên văn dòng chữ dưới mã đơn lúc đó, và tên bước đang được tô màu cam đậm ở thanh 4 bước (Đã nhận, "
    'Đang làm, Sẵn sàng, Hoàn tất; nếu thanh 4 bước không còn thì ghi "không có"). Cuối cùng chạm dấu X ở góc trên '
    "bên trái để rời màn."
)
EXPECTED = (
    'JSON: {"order_code": mã đơn có dấu #, "status_line": nguyên văn dòng chữ dưới mã đơn, '
    '"current_step": tên bước được tô hoặc "không có"}'
)


@pytest.fixture
def customer_uid() -> str:
    uid = os.environ.get("CROSS_ROLE_CUSTOMER_UID")
    if not uid:
        pytest.skip("CROSS_ROLE_CUSTOMER_UID is not set")
    return uid


async def test_tc42_web_approval_reaches_the_phone_live(artemis, customer_uid):
    staff = StaffDecision(customer_uid, "approve")
    staff.start()
    result = await artemis.run(PLACE_AND_WAIT, expected_output=EXPECTED)
    staff.join(timeout=5)
    assert staff.error is None, staff.error
    assert staff.decided_at is not None, "the order was never approved"
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["order_code"].lstrip("#") == staff.order_code, data
    assert "Dự kiến sẵn sàng" in data["status_line"], data
    assert data["current_step"] == "Đang làm", data


async def test_tc43_web_rejection_and_its_reason_reach_the_phone_live(artemis, customer_uid):
    staff = StaffDecision(customer_uid, "reject")
    staff.start()
    result = await artemis.run(PLACE_AND_WAIT, expected_output=EXPECTED)
    staff.join(timeout=5)
    assert staff.error is None, staff.error
    assert staff.decided_at is not None, "the order was never rejected"
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["order_code"].lstrip("#") == staff.order_code, data
    assert "Đơn đã huỷ" in data["status_line"], data
    assert REJECT_REASON in data["status_line"], data
