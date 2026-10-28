# Kế hoạch sự kiện analytics

Viết **trước** khi viết code theo dõi. Tối thiểu 7 sự kiện, đủ phủ: đăng nhập, đăng xuất, hành động chính (tìm kiếm, đặt món), mở màn chi tiết, xuất và tải tệp. Dùng tên Firebase khuyến nghị khi có (`login`, `search`, `add_to_cart`, `begin_checkout`, `purchase`), còn lại `snake_case`. Tham số không chứa dữ liệu cá nhân (không email, không tên).

Mục tiêu thành công Lab 2: đặt xong dưới 35 giây, tối đa 8 chạm.

| Sự kiện | Khi nào | Tham số (kiểu) | Câu hỏi sản phẩm | Bước flow Lab 2 |
|---|---|---|---|---|
| `login` | Đăng nhập thành công | `method` (string) | Bao nhiêu người quay lại mỗi tuần? | S26 |
| `logout` | Đăng xuất | `session_minutes` (int) | Một phiên kéo dài bao lâu? | S15 |
| `search` | Chạy tìm kiếm | `search_term` (string), `result_count` (int) | Người dùng tìm gì, và từ khoá nào không ra kết quả? | S28 |
| `view_menu_item` | Mở chi tiết món | `item_id` (string), `item_name` (string), `category` (string) | Món nào được xem nhiều nhưng ít được thêm? | S04 |
| `add_to_cart` | Thêm món vào giỏ | `item_id` (string), `quantity` (int), `source` (string: home, menu, detail) | Thêm từ đâu nhanh nhất? | S02, S03, S04 |
| `begin_checkout` | Vào màn thanh toán | `value_vnd` (int), `item_count` (int) | Bao nhiêu giỏ đi tới thanh toán? | S05 → S06 |
| `purchase` | Đặt đơn thành công | `transaction_id` (string), `value_vnd` (int), `payment_method` (string), `taps_from_home` (int) | Đạt mục tiêu ≤ 8 chạm và < 35 giây không? | S06-GATEWAY → S07 |
| `payment_failed` | Thanh toán bị từ chối hoặc mất mạng | `payment_method` (string), `reason` (string) | Phương thức nào lỗi nhiều, và bao nhiêu người chuyển sang tiền mặt? | S06-ERR |
| `export_report` | Tạo và tải lên tệp | `order_id` (string), `file_size_kb` (int) | Đơn nào được xuất biên lai? | Khu demo, S12 |
| `order_accepted` | Người bán nhận đơn | `order_id` (string), `wait_seconds` (int) | Quầy nhận đơn nhanh cỡ nào? | K03 |
| `order_delivered` | Người bán giao món | `order_id` (string), `paid_cash` (bool) | Bao nhiêu đơn thu tiền mặt? | K06 |

Thuộc tính người dùng: `setUserId(uid)` sau đăng nhập; không đưa email hay tên vào user property.

## Bằng chứng

Mỗi sự kiện cần ảnh DebugView (Analytics debug mode bật) lưu trong `evidence/analytics/`. Ghi tên file vào bảng khi có.

| Sự kiện | Ảnh DebugView |
|---|---|
| | |
