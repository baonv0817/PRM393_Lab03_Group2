"""TC-40, TC-41 (docs/test-plan.md, docs/ai-feature.md): tính năng AI của bài cuối kỳ, "Điền bằng AI" ở K14.

Điều kiện đầu:
- đăng nhập bằng tài khoản có vai staff và `kioskId` là Kiosk Q9 · Tầng 2 (như TC-25 đến TC-29);
- Remote Config `ai_enabled` = true trên console;
- ảnh trong thư viện của máy, thư mục Pictures/BreakBiteAI (`banh-mi.jpg`, `breakbite_logo.png`), đẩy lên bằng:
  adb push packages/core/assets/images/menu/banh-mi.jpg /sdcard/Pictures/BreakBiteAI/banh-mi.jpg
  adb push packages/core/assets/brand/breakbite_logo.png /sdcard/Pictures/BreakBiteAI/breakbite_logo.png
  rồi quét thư viện: adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/BreakBiteAI/<tên>

Hai test không lưu món nào, nên chạy lại bao nhiêu lần thực đơn cũng không đổi và không phụ thuộc thứ tự.
"""
import json
import re


def parsed(result) -> dict:
    """Kết quả có cấu trúc agent trả về (chuỗi JSON hoặc dict)."""
    out = result.output
    return out if isinstance(out, dict) else json.loads(out)


OPEN_K14 = (
    "BreakBite đang đăng nhập bằng tài khoản nhân viên của Kiosk Q9 · Tầng 2. Mở tab Món, chạm dấu + ở thanh trên "
    'để mở form "Thêm món mới". Ở phần "Ảnh món" chạm "Thư viện", mở thư mục BreakBiteAI (hoặc Pictures) và chọn '
)
CLOSE_WITHOUT_SAVING = 'Không chạm "Lưu món". Cuối cùng chạm dấu X ở góc trên để đóng form, nếu có hỏi thì chọn bỏ thay đổi.'


async def test_tc40_ai_fills_the_new_item_from_a_dish_photo(artemis):
    result = await artemis.run(
        OPEN_K14 + 'ảnh "banh-mi.jpg". Chạm nút "Điền bằng AI" và chờ đến khi khung "Gợi ý từ AI" hiện ra (có thể mất '
        "vài giây). Ghi lại chữ trong ô Tên món, số trong ô Giá, danh mục đang được chọn, và có dòng chữ "
        '"Gợi ý từ AI" dưới ô Tên món hay không. ' + CLOSE_WITHOUT_SAVING,
        expected_output=(
            'JSON: {"name": chữ trong ô Tên món, "price": chữ trong ô Giá, "category": danh mục đang chọn, '
            '"ai_label_under_name": true hoặc false}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "bánh mì" in data["name"].lower(), data
    price = int(re.sub(r"\D", "", str(data["price"])) or 0)
    assert 5_000 <= price <= 100_000, data
    assert data["category"] == "Món ăn", data
    assert data["ai_label_under_name"] is True, data


async def test_tc41_ai_refuses_a_photo_that_is_not_food(artemis):
    result = await artemis.run(
        OPEN_K14 + 'ảnh "breakbite_logo.png" (logo, không phải món ăn). Chạm nút "Điền bằng AI" và chờ đến khi một '
        'dòng chữ màu đỏ hiện ngay dưới nút "Điền bằng AI" (có thể mất vài giây). Ghi lại nguyên văn dòng chữ đó, và '
        'ô Tên món có còn trống không. Sau đó gõ tên "Món thử" vào ô Tên món và ghi lại chữ trong ô. '
        + CLOSE_WITHOUT_SAVING,
        expected_output=(
            'JSON: {"message": nguyên văn dòng chữ đỏ dưới nút, "name_empty_after_ai": true hoặc false, '
            '"typed_name": chữ trong ô Tên món sau khi gõ}'
        ),
    )
    assert result.succeeded, result.error or result.status
    data = parsed(result)
    assert "không giống món ăn" in data["message"].lower(), data
    assert data["name_empty_after_ai"] is True, data
    assert data["typed_name"] == "Món thử", data
