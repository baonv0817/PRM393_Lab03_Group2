# Test plan (Google ARTEMIS)

Mọi test là một hàm pytest gửi **một** chỉ dẫn qua ARTEMIS. Chỉ dẫn nêu điểm bắt đầu, các bước và điều phải thấy cuối cùng, yêu cầu agent trả về giá trị cụ thể (số lượng, tên, giá trị Remote Config) để so sánh, không chỉ dựa vào `status == "SUCCESS"`. Mỗi test chạy ít nhất 3 lần; không đạt 3 trên 3 là test chập chờn, phải tìm nguyên nhân (app, thời gian, hay chỉ dẫn mơ hồ) và ghi cách sửa.

Test độc lập nhau, mỗi test tự bắt đầu từ tiền điều kiện của nó. Tài khoản Google dành riêng cho test; khoá và mật khẩu đặt trong biến môi trường, không commit.

## 1. Flow quan trọng và màn hình

| Flow | Màn hình |
|---|---|
| Đăng nhập, đăng xuất | S26, S15 |
| F1 Đặt nhanh | S02, S02-ADDED, S05, S06, S06-GATEWAY, S07 |
| F2 Mã giảm giá | S03, S04, S05, S29 |
| F3 Lỗi thanh toán | S06-GATEWAY, S06-ERR, S07-CASH |
| Tìm kiếm | S28, S28-EMPTY |
| Xuất và tải lên | Khu demo Firebase, S12 |
| Thông báo đẩy | S19 |
| Người bán | K01, K02, K03, K04, K05, K06 |

## 2. Test case

| ID | Flow | Tiền điều kiện | Chỉ dẫn (tóm tắt) | Kết quả mong đợi | Loại | Kết quả |
|---|---|---|---|---|---|---|
| TC-01 | Đăng nhập | Đã cài app, chưa đăng nhập | Mở app, chạm đăng nhập Google, chọn tài khoản test | Màn Trang chủ hiện, thanh dưới có 4 tab; báo cáo tên kiosk đang chọn | Native | Chưa chạy |
| TC-02 | Đăng xuất | Đã đăng nhập | Mở Cá nhân, chạm Đăng xuất | Màn đăng nhập hiện, không vào được Trang chủ khi bấm Back | Happy path | Chưa chạy |
| TC-03 | F1 đặt nhanh | Đã đăng nhập, giỏ trống | Trang chủ, chạm + ở món đầu, Xem giỏ, Tiếp tục thanh toán, giữ MoMo, Xác nhận, xác nhận ở cổng | Màn Theo dõi đơn hiện; báo mã nhận và tổng tiền | Happy path | Chưa chạy |
| TC-04 | F2 mã giảm giá sai | Giỏ có 1 món | Giỏ hàng, chạm ô mã, chọn mã đã hết hạn | Báo lỗi mã hết hạn ngay ở giỏ; báo tổng tiền không đổi | Error path | Chưa chạy |
| TC-05 | F3 lỗi thanh toán | Giỏ có 1 món | Thanh toán, xác nhận, ở cổng chạm Từ chối, chọn Tiền mặt tại Kiosk | Màn lỗi giữ giỏ; sau khi chọn tiền mặt có đơn trả tại quầy; báo trạng thái đơn | Error path | Chưa chạy |
| TC-06 | Tìm kiếm không có kết quả | Đã đăng nhập | Tìm từ khoá không có trong thực đơn | Màn trạng thái rỗng kèm thông báo; báo số kết quả = 0 | Error path | Chưa chạy |
| TC-07 | Các tab chính | Đã đăng nhập | Lần lượt chạm Thực đơn, Đơn hàng, Cá nhân, Trang chủ | Mỗi tab hiện đúng tiêu đề màn gốc | Happy path | Chưa chạy |
| TC-08 | Màn chi tiết món và đơn | Có ít nhất 1 đơn | Mở chi tiết một món, rồi mở chi tiết một đơn trong lịch sử | Báo tên món và giá; báo mã đơn và trạng thái | Happy path | Chưa chạy |
| TC-09 | Xuất và tải lên | Có ít nhất 1 đơn | Mở khu demo Firebase, chạm Xuất biên lai và tải lên | Hiện tiến trình rồi URL tải xuống; báo kích thước tệp | Happy path | Chưa chạy |
| TC-10 | Giá trị Remote Config | Giá trị mặc định | Mở Trang chủ, đếm số món trong mục lấy nhanh dưới 5 phút | Báo số món bằng giá trị `quick_items_limit` hiện tại | Happy path | Chưa chạy |
| TC-11 | Mở thông báo đẩy | App ở nền, đã cấp quyền | Chạm thông báo trong màn hình thông báo của hệ thống | App mở màn liên quan tới thông báo | Native | Chưa chạy |
| TC-12 | Người bán nhận và giao đơn | Có 1 đơn pending, đăng nhập vai trò staff | Mở đơn, Nhận đơn, Báo sẵn sàng, Quét mã và xác nhận giao | Trạng thái đơn chuyển sang đã giao; báo mã đơn | Happy path | Chưa chạy |
| TC-13 | Sự kiện analytics đã ghi | Analytics debug bật | Thực hiện TC-03 rồi kiểm Logcat | Có sự kiện `purchase` với tham số đúng | Happy path | Chưa chạy |

Các chỉ dẫn trên là tóm tắt; bản đầy đủ nằm trong `e2e_test/`. Mỗi người thêm case cho màn mình phụ trách (nếu thiếu so với mục 7 của handout).

## 3. Kết quả chạy (điền sau khi chạy)

| Test | Số lần chạy | Tỉ lệ đạt | Thời gian trung bình | Ghi chú (chập chờn, lỗi, bỏ qua) |
|---|---|---|---|---|
| | | | | |

Lệnh chạy bộ test: `[điền]`. Dấu vết hoặc ảnh từng lần chạy lưu trong `evidence/artemis/`.

## 4. Phiên khám phá (hồ sơ Pro, 15 đến 30 phút)

| Thời gian | Lỗi hoặc vấn đề tìm thấy | Mức độ | Đã xử lý |
|---|---|---|---|
| | | | |
