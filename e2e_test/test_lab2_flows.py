"""TC-32, TC-33, TC-34 (docs/test-plan.md): the Lab 2 flows F6 and F8 on the phone, against the real project.

- TC-32, F6 from Profile: an item's heart (S04) → "Món yêu thích" (S13) → + puts it in the cart.
- TC-33, F6 from Home: "Đặt lại đơn gần đây" (S14) → "Thêm vào giỏ" → the cart (S05) holds that order's dishes.
- TC-34, F8: the kiosk marks an order ready → the inbox (S19) has "Đơn #… đã sẵn sàng" → "Xem mã nhận món" opens
  the pickup code (S20).

Each test checks what the agent reports AND what the app wrote to Firestore (favorite, cart), so a misread screen
cannot pass. Data is set up and cleaned with `project_data` (the fields the app itself writes); every run leaves the
customer's cart and favorites as they were.

Preconditions: the phone is signed in with the customer account, Kiosk Q9 · Tầng 2 chosen, empty cart; the customer
has at least one delivered order (TC-33) and one order being prepared (TC-34, one is used per run);
CUSTOMER_UID (or CROSS_ROLE_CUSTOMER_UID) is that account's uid; `firebase login` done on this machine.
"""
import datetime as dt
import json
import os
import re
import subprocess
import time

import pytest

import project_data as pd

KIOSK = "q9-t2"
COFFEE_ID = "q9-t2-cafe-sua"
COFFEE = "Cà Phê Sữa Đá"


def parsed(result) -> dict:
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


def digits(text) -> str:
    return re.sub(r"\D", "", str(text))


def _value(v: dict):
    if "stringValue" in v:
        return v["stringValue"]
    if "integerValue" in v:
        return int(v["integerValue"])
    return next(iter(v.values()), None)


def cart_lines(uid: str) -> list[dict]:
    """The customer's cart as [{itemId, name, quantity, priceVnd}], [] when there is none."""
    doc = pd.get(f"carts/{uid}")
    if not doc:
        return []
    items = doc.get("fields", {}).get("items", {}).get("arrayValue", {}).get("values", [])
    return [{k: _value(v) for k, v in item["mapValue"]["fields"].items()} for item in items]


def favorite_ids(uid: str) -> set[str]:
    docs = pd.call("GET", f"{pd.DOCS}/users/{uid}/favorites").get("documents", [])
    return {d["name"].rsplit("/", 1)[1] for d in docs}


@pytest.fixture
def uid() -> str:
    value = os.environ.get("CUSTOMER_UID") or os.environ.get("CROSS_ROLE_CUSTOMER_UID")
    if not value:
        pytest.skip("CUSTOMER_UID is not set")
    return value


@pytest.fixture
def empty_cart(uid):
    """An empty cart before the test, and again after it."""
    pd.remove(f"carts/{uid}")
    yield
    pd.remove(f"carts/{uid}")


def restart_to_home(timeout_s: float = 60) -> None:
    """Restarts the app and waits until it shows Home with the bell, so it watches the customer's orders from a
    fresh start (an earlier test may have left it on another screen). The status notifier only announces changes
    it sees after its first snapshot, so the kiosk's change must come after this."""
    serial = os.environ["ARTEMIS_DEVICE_SERIAL"]
    package = "vn.edu.fpt.breakbite"
    subprocess.run(["adb", "-s", serial, "shell", "am", "force-stop", package], capture_output=True)
    subprocess.run(
        ["adb", "-s", serial, "shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1"],
        capture_output=True,
    )
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        subprocess.run(["adb", "-s", serial, "shell", "uiautomator", "dump", "/sdcard/ui.xml"], capture_output=True)
        dump = subprocess.run(
            ["adb", "-s", serial, "shell", "cat", "/sdcard/ui.xml"], capture_output=True, text=True, encoding="utf-8"
        ).stdout
        if 'content-desc="Thông báo' in dump:
            time.sleep(3)
            return
        time.sleep(2)
    raise AssertionError("Home with the bell did not appear on the phone")


GO_HOME = "Nếu app không ở Trang chủ, chạm tab \"Trang chủ\" ở thanh dưới cùng trước. "


async def test_tc32_f6_favorite_from_the_item_page_to_the_cart(artemis, uid, empty_cart):
    before = favorite_ids(uid)
    try:
        result = await artemis.run(
            "BreakBite đang đăng nhập bằng tài khoản khách, kiosk đang chọn là Kiosk Q9 · Tầng 2, giỏ hàng trống. "
            + GO_HOME
            + f'Mở tab "Thực đơn", chạm thẻ món "{COFFEE}" để mở trang món. Ở trang món, chạm nút trái tim '
            '"Thêm vào món yêu thích" ở thanh trên cùng đúng một lần, rồi chạm nút quay lại ở góc trên bên trái. Mở '
            'tab "Cá nhân", chạm "Món yêu thích". Ghi tên các món trong danh sách. Trên thẻ món '
            f'"{COFFEE}", chạm nút + tròn ở góc dưới bên phải của thẻ đúng một lần (chỉ chạm nút +, KHÔNG chạm ảnh '
            "hay tên món vì sẽ mở trang món); sau khi chạm, nút + đổi thành bộ đếm hiện số 1.",
            expected_output='JSON: {"favorites": danh sách tên món trong "Món yêu thích", "added": true nếu đã chạm +}',
        )
        assert result.succeeded, result.error or result.status
        data = parsed(result)
        assert any(COFFEE.lower() in str(name).lower() for name in data["favorites"]), data
        # What the app wrote: the favorite, and the item in the cart.
        assert "cafe-sua" in favorite_ids(uid) - before
        lines = cart_lines(uid)
        assert [(line["itemId"], line["quantity"]) for line in lines] == [(COFFEE_ID, 1)], lines
    finally:
        for dish in favorite_ids(uid) - before:
            pd.remove(f"users/{uid}/favorites/{dish}")


async def test_tc33_f6_quick_reorder_from_home_fills_the_cart(artemis, uid, empty_cart):
    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản khách, kiosk đang chọn là Kiosk Q9 · Tầng 2, giỏ hàng trống. "
        + GO_HOME
        + 'Trên Trang chủ tìm thẻ "Đặt lại đơn gần đây" (cuộn xuống nếu cần). KHÔNG chạm vào thân thẻ (chạm thân '
        'thẻ sẽ thêm ngay đơn đó vào giỏ). Chạm nút hình đồng hồ "Chọn đơn khác để đặt lại" ở mép phải của thẻ, '
        'đúng một lần. Một bảng "Đặt lại đơn gần đây" hiện lên từ dưới, đơn đầu tiên đã được chọn sẵn. Ghi nguyên '
        'văn nhãn của nút "Thêm vào giỏ · …" rồi chạm nút đó đúng một lần. Khi màn "Giỏ hàng" mở ra, ghi tên và '
        "số lượng của từng món trong giỏ.",
        expected_output=(
            'JSON: {"button_label": nhãn nút "Thêm vào giỏ · …", '
            '"cart_items": danh sách {"name": tên món, "quantity": số lượng}}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["button_label"].startswith("Thêm vào giỏ"), data
    lines = cart_lines(uid)
    assert lines, "the cart is still empty in Firestore"
    # The agent read the same cart the app wrote, and the button's total is that cart's total.
    assert sorted(str(i["name"]).lower() for i in data["cart_items"]) == sorted(l["name"].lower() for l in lines)
    assert int(digits(data["button_label"])) == sum(l["priceVnd"] * l["quantity"] for l in lines)


async def test_tc34_f8_ready_notification_opens_the_pickup_code(artemis, uid):
    preparing = pd.query(
        "orders", [("uid", "EQUAL", {"stringValue": uid}), ("status", "EQUAL", {"stringValue": "preparing"})]
    )
    if not preparing:
        pytest.skip("the customer has no order being prepared")
    order = max(preparing, key=lambda d: pd.ts(d["fields"]["createdAt"]))
    fields = order["fields"]
    code, pickup = fields["orderCode"]["stringValue"], fields["pickupCode"]["stringValue"]

    # The kiosk marks it ready (what K04 and the web write: FirestoreOrderRepository.markReady), once the phone
    # shows Home and watches the orders again.
    restart_to_home()
    accepted = pd.ts(fields["acceptedAt"]) if "acceptedAt" in fields else dt.datetime.now(dt.timezone.utc)
    seconds = max(0, int((dt.datetime.now(dt.timezone.utc) - accepted).total_seconds()))
    pd.update(
        order["name"],
        {"status": {"stringValue": "ready"}, "prepSeconds": {"integerValue": str(seconds)}},
        stamps=("readyAt", "updatedAt"),
    )
    time.sleep(5)

    result = await artemis.run(
        "BreakBite đang đăng nhập bằng tài khoản khách. "
        + GO_HOME
        + "Chạm nút chuông thông báo ở góc trên bên phải của Trang chủ. Màn \"Thông báo\" mở ra; thông báo trên cùng "
        'có tiêu đề dạng "Đơn #… đã sẵn sàng". Ghi nguyên văn tiêu đề đó, rồi chạm nút "Xem mã nhận món" của chính '
        'thông báo đó. Màn "Mã nhận món" hiện ra: ghi 6 chữ số ngay dưới chữ "Mã số".',
        expected_output='JSON: {"notification_title": tiêu đề thông báo trên cùng, "pickup_code": 6 chữ số dưới "Mã số"}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["notification_title"].replace(" ", "") == f"Đơn#{code}đãsẵnsàng", data
    assert digits(data["pickup_code"]) == pickup, data
