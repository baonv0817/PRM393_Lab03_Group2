"""TC-09, TC-10, TC-14, TC-15, TC-16 (docs/test-plan.md): khu demo Firebase, Remote Config và hồ sơ (P3).

TC-10 so số món "nhanh dưới 5 phút" agent đếm được với giá trị `quick_items_limit` hiện hành, đặt qua biến
môi trường `EXPECTED_QUICK_ITEMS` (mặc định là giá trị trong firebase/remote-config-defaults.json). Đổi giá
trị trong console thì đặt lại biến này trước khi chạy.
"""
import json
import os
import pathlib
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


def expected_quick_items() -> int:
    if value := os.environ.get("EXPECTED_QUICK_ITEMS"):
        return int(value)
    defaults = pathlib.Path(__file__).resolve().parent.parent / "firebase" / "remote-config-defaults.json"
    return int(json.loads(defaults.read_text(encoding="utf-8"))["quick_items_limit"])


async def test_tc09_export_and_upload(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập và có ít nhất một đơn. Mở tab Cá nhân, chạm "Khu demo Firebase", chạm '
        '"Xuất và tải lên". Quan sát thanh tiến trình, đợi link tải về hiện ra, rồi xem mục "Tệp của tôi".',
        expected_output=(
            'JSON: {"progress_seen": true hoặc false, "url": link hiện ra, "size_kb": dung lượng tệp bằng KB, '
            '"listed_in_my_files": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["progress_seen"] is True
    assert str(data["url"]).startswith("http")
    assert float(re.sub(r"[^\d.]", "", str(data["size_kb"]))) > 0
    assert data["listed_in_my_files"] is True


async def test_tc10_remote_config_quick_items(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập, đang ở Trang chủ. Tìm mục có tiêu đề "Món nhanh · tối đa 5 phút". Các món của mục '
        "này xếp DỌC, mỗi món một thẻ có nút +, và món cuối thường nằm dưới mép màn hình. Để xem các món phía dưới, "
        "VUỐT TỪ DƯỚI LÊN (đặt ngón tay gần đáy màn hình rồi kéo lên trên), từng đoạn ngắn, cho tới khi thấy mục kế "
        'tiếp ("Đặt lại đơn gần đây") hoặc hết trang. Ghi tên từng món của mục theo thứ tự, mỗi món một lần, không '
        "ghi món của mục khác.",
        expected_output='JSON: {"quick_items": [tên các món trong mục Món nhanh], "quick_item_count": số món}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    names = data.get("quick_items") or []
    assert len(set(names)) == len(names), f"một món bị ghi hai lần: {names}"
    assert int(data["quick_item_count"]) == len(names) == expected_quick_items()


async def test_tc14_change_kiosk_empties_cart(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập, đang ở Trang chủ của "Kiosk Q9 · Tầng 2". Nếu giỏ đang trống, chạm nút + của món '
        "đầu tiên một lần để giỏ có 1 món (biểu tượng giỏ hiện số 1). Chạm tên kiosk, chọn "
        '"Kiosk Q9 · Tầng 4", chạm "Chọn kiosk này". Ghi nội dung hộp thoại cảnh báo, xác nhận, rồi ghi tên kiosk '
        "ở Trang chủ và số trên biểu tượng giỏ.",
        expected_output=(
            'JSON: {"warning": nội dung hộp thoại, "kiosk": tên kiosk sau khi đổi, '
            '"cart_count": số trên biểu tượng giỏ hoặc 0}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "giỏ" in data["warning"].lower()
    assert "Tầng 4" in data["kiosk"]
    assert int(data["cart_count"] or 0) == 0


async def test_tc15_student_profile_validation(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập. Mở tab Cá nhân, chạm "Hồ sơ sinh viên". Gõ "SE12" vào ô mã số sinh viên và '
        'chạm "Lưu hồ sơ"; ghi thông báo lỗi dưới ô. Sau đó sửa thành "SE183398" và chạm "Lưu hồ sơ" lần nữa. '
        "Thông báo xác nhận tự biến mất sau vài giây nên KHÔNG cần ghi nó; thay vào đó thoát ra, mở lại "
        'màn "Hồ sơ sinh viên" và ghi giá trị đang có trong ô MSSV.',
        expected_output='JSON: {"error_message": thông báo lỗi lần đầu, "student_id_after_reopen": MSSV đang có trong ô}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert data["error_message"].strip()
    # The "Đã lưu hồ sơ." snackbar disappears before the agent can read it, so the saved value is asserted.
    assert data["student_id_after_reopen"].strip() == "SE183398"


async def test_tc16_default_payment_method(artemis):
    result = await artemis.run(
        'BreakBite đang đăng nhập. Mở tab Cá nhân, chạm "Phương thức thanh toán", chọn tiền mặt, chạm '
        '"Lưu mặc định". Thông báo xác nhận tự biến mất sau vài giây nên KHÔNG cần ghi nó. Thoát ra rồi mở lại '
        "màn này và ghi phương thức đang được chọn (thẻ có dấu chọn).",
        expected_output='JSON: {"selected_after_reopen": phương thức đang chọn}',
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    # The "Đã đặt … làm mặc định." snackbar disappears before the agent can read it; the saved choice is asserted.
    assert "tiền mặt" in data["selected_after_reopen"].lower()
