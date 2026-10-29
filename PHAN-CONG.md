# Phân công Lab 3 (4 người)

Cập nhật 29/10/2026, sau khi dựng xong nền. Chi tiết từng task, điều kiện xong và phụ thuộc: [`TASKS.md`](TASKS.md). Cách làm một màn và quy tắc file dùng chung: [`CONTRIBUTING.md`](CONTRIBUTING.md). Mỗi task có một issue trên GitHub cùng mã.

| Vai trò | Người nhận | GitHub | Rubric gánh chính (trên 10 điểm) |
|---|---|---|---|
| **P1** Đặt món: thực đơn, giỏ, thanh toán, theo dõi đơn | `[tên, MSSV]` | `[@…]` | UI/UX 0,75 · Kiến trúc 0,75 · Chức năng F1, F2, F3 |
| **P2** Đơn hàng, yêu thích, thông báo, test E2E | `[tên, MSSV]` | `[@…]` | Chức năng (các màn sau khi đặt) · FCM 0,5 · Test ARTEMIS 1,5 |
| **P3** Firebase, tài khoản, hồ sơ | `[tên, MSSV]` | `[@…]` | Firebase 2,0 · Auth, Firestore, Storage, Analytics, Crashlytics, Remote Config |
| **P4** App người bán, code review, báo cáo | `[tên, MSSV]` | `[@…]` | Chức năng (app người bán) · Code review 0,5 · Slide và video 2,0 |

---

## Đã có sẵn (không ai phải làm lại)

- Máy dựng: Flutter, Android SDK, máy ảo, Firebase CLI, Emulator. Chạy thử: `docs/setup.md`.
- Khung MVVM: router, DI, `ViewState`, theme từ token Lab 2, widget chung, font Nunito, logo BreakBite, ảnh món minh hoạ.
- Firebase project `breakbite-1315b`: Auth Google, Firestore (đã có dữ liệu mẫu), Remote Config, rules và chỉ mục (82 test rules đạt).
- **Hai màn mẫu đã xong, lấy làm khuôn:** S01 Onboarding và S02 Trang chủ (ViewModel, màn, test, đúng Figma). Làm màn mới = sao theo S02, xem `CONTRIBUTING.md`.
- Chạy được không cần Firebase: cấu hình F5 "đã đăng nhập" (khách hoặc người bán) dùng dữ liệu giả.

## Cách chia

Mỗi người giữ **một cụm màn liền mạch** để dùng chung ViewModel và dữ liệu, ít đụng nhau:

| Cụm | Màn | Người |
|---|---|---|
| Đặt món | S03, S04, S05 (+ rỗng, mã sai), S25 hẹn giờ, S29 chọn mã, S06 (+ biến thể thanh toán), S06-GATEWAY, S07 (+ tiền mặt, dialog huỷ), S08 | P1 |
| Sau khi đặt | S09 sửa đơn, S10 đơn đã huỷ, S11 lịch sử, S12 chi tiết đơn, S13 yêu thích, S14 đặt lại, S19 thông báo, S20 mã QR nhận món, S21 quán đóng, S22 món hết gợi ý, S23 đánh giá, S24 báo sự cố | P2 |
| Tài khoản và dùng chung | S15–S18 cá nhân, S26 đăng nhập, S27 chọn kiosk, S28 tìm kiếm, S30 mất kết nối, khu demo Firebase | P3 |
| App người bán | K01–K06, K08–K15 | P4 |

S01 và S02 đã xong. Bảng đầy đủ từng màn, route, ViewModel, nguồn dữ liệu: `docs/design-traceability.md`.

---

## Việc chung của cả 4 người

Bắt buộc, vì thầy có thể hỏi riêng từng người (khoảng 5 phút: chạy 1 test ARTEMIS, đổi 1 giá trị Remote Config trực tiếp, giải thích 1 ViewModel và 1 quyết định review).

1. Commit đều qua nhiều ngày, mỗi commit mở đầu bằng mã task hoặc mã màn, ví dụ `[S03] Thực đơn có chọn loại món`. Không dồn code lên một người.
2. Làm trên nhánh riêng, mở PR, nhờ người khác duyệt rồi mới merge vào `main`.
3. Màn nào mình làm thì mình: điền hàng của mình trong `docs/design-traceability.md`, đặt `Semantics` label (T61), viết test case vào `docs/test-plan.md`, quyết định các phát hiện review thuộc file của mình (T71), viết mục báo cáo và quay đoạn video của phần mình.
4. Không gọi SDK trong widget, không viết logic trong `build()`, không màu hay cỡ chữ cứng (dùng theme và widget chung).
5. Mỗi màn tải dữ liệu có đủ loading, empty, error kèm nút thử lại; nút Back đi đúng chỗ.
6. Không commit khoá, mật khẩu, keystore. File khoá service account để ngoài repo.
7. Đọc và chạy thử được phần của người khác ít nhất một lần trước buổi nộp.

---

## P1 · Đặt món

**Mục tiêu:** làm trọn luồng đặt món F1, F2, F3 từ thực đơn đến theo dõi đơn, và giữ chất lượng giao diện và kiến trúc của cả nhóm.

| Thứ tự | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T40 | S03 Thực đơn, S04 Chi tiết món, S05 Giỏ hàng (rỗng, mã sai) | Thêm món, sửa số lượng, thấy tổng tiền |
| 2 | T40 | S25 Hẹn giờ, S29 Chọn mã, S06 Thanh toán + biến thể, S06-GATEWAY, S07 Theo dõi đơn, S08 Đơn hàng | F1, F2, F3 chạy trọn |
| 3 | T34 | `SlotService` (đặt chỗ slot) và `VoucherService` (danh sách mã): interface, bản giả, bản Firestore | S25, S29 dùng dữ liệu thật |
| song song | T10, T20 | Cập nhật `docs/architecture.md` cho khớp code; dẫn việc điền `design-traceability.md` | Tài liệu khớp |
| cuối | T72, T83 | Kiểm quy tắc MVVM toàn repo; cập nhật Figma theo các sai lệch (D01–D06); chạy checklist nộp bài | Checklist tích đủ |

**Làm được ngay hôm nay:** S03 đến S08 với dữ liệu giả (F5 "khách, đã đăng nhập"). Chưa cần chờ ai.
**Chờ ai:** P3 xong T33 (dịch vụ Firestore) để nối dữ liệu thật; P3 xong T30 để đăng nhập thật.
**Ai chờ mình:** P2 chờ S07, S08 (đơn và danh sách) để làm S09–S12; P4 chờ đơn đặt thật để làm K02–K06.
**Báo cáo và slide:** kiến trúc MVVM, sơ đồ tầng, design system trong code, so sánh Figma và app.
**Vấn đáp:** giải thích luồng dữ liệu của `CartViewModel` hoặc `CheckoutViewModel`, vì sao trạng thái là sealed class.

---

## P2 · Sau khi đặt, thông báo, test E2E

**Mục tiêu:** làm các màn quản lý đơn và tương tác sau khi đặt, thông báo đẩy, và gánh bộ test ARTEMIS.

| Thứ tự | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T02 | Chuẩn bị máy test: thiết bị Android hoặc emulator, ADB, ARTEMIS, API key trong biến môi trường, tài khoản Google riêng cho test | Chạy được 1 lệnh ARTEMIS mẫu |
| 2 | T41 | S13 Yêu thích, S20 Mã QR nhận món, S22 Món hết gợi ý, S23 Đánh giá, S24 Báo sự cố, S21 Quán đóng (làm được ngay với dữ liệu giả) | Mỗi màn đủ trạng thái |
| 3 | T41 | S09 Sửa đơn, S10 Đơn đã huỷ, S11 Lịch sử, S12 Chi tiết đơn, S14 Đặt lại (sau khi P1 xong S07, S08) | F3 chạy tiếp được |
| 4 | T34 | `ReviewService`, `FavoriteService`, `NotificationService`, `IncidentService` (tạo sự cố): interface, bản giả, bản Firestore | Màn dùng dữ liệu thật |
| 5 | T53 | S19 Thông báo và FCM: nhận ở 3 trạng thái app, xin quyền Android 13+, chạm mở đúng màn | Tin thử từ console tới ở cả 3 trạng thái |
| 6 | T43 | Sinh PDF biên lai, tải lên qua `StorageService` (cần Storage bật) | File ở `reports/{uid}/…` |
| song song | T60 | Khung `docs/test-plan.md`, gom case từ các bạn | ≥ 10 test case |
| cuối | T62, T63 | Test ARTEMIS ≥ 3 lần mỗi test, bảng tỉ lệ đạt, phiên khám phá | Bảng kết quả, dấu vết |

**Làm được ngay hôm nay:** S13, S20, S22, S23, S24, S21 và T02. S09–S12, S14 cần P1 xong S07, S08.
**Chờ ai:** P1 (S07, S08); P3 (T22 `MessagingService`, T32 Storage bật được).
**Ai chờ mình:** P4 cần bảng kết quả test để làm slide và video; P4 cần `IncidentService` để làm K13.
**Báo cáo và slide:** test plan, kết quả ARTEMIS, phiên khám phá, FCM.
**Vấn đáp:** chạy trực tiếp 1 test ARTEMIS, giải thích vì sao assert theo giá trị báo về chứ không chỉ `SUCCESS`.

---

## P3 · Firebase, tài khoản, hồ sơ

**Mục tiêu:** nối app với Firebase thật (đủ 6 dịch vụ, có xử lý lỗi và bằng chứng trên console) và làm các màn dùng chung. Đây là vai trò gánh nhiều việc tích hợp nhất, nên mọi người xin dữ liệu sớm qua interface và bản giả, không chờ.

| Thứ tự | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T01 | Còn lại: bật Crashlytics, thêm SHA-1 máy cả nhóm, mời 3 người vào Firebase; Storage khi nhóm quyết nâng Blaze | Cả nhóm vào console, Google Sign-In chạy trên máy ai cũng được |
| 2 | T22 | Viết `lib/firebase/bootstrap.dart` và bản Firebase của `AuthService`, `RemoteConfigService`, `AnalyticsService`, `CrashService`, `MessagingService`, `StorageService` | App chạy với Firebase thật (bỏ cờ dữ liệu giả) |
| 3 | T33 | Bản Firestore của `MenuService`, `CartService`, `OrderService` (kiosk, voucher, slot): truy vấn theo `docs/data-model.md` mục 5, đặt đơn bằng batch | Đơn đặt ở app khách hiện ngay ở app người bán |
| 4 | T30 | Màn S26 Google Sign-In, định tuyến theo đăng nhập, đăng xuất, báo lỗi khi huỷ hoặc mất mạng, tạo `users/{uid}` | Ảnh 2 trạng thái, tab Users |
| 5 | T42 | S15–S18 Cá nhân, S27 Chọn kiosk, S28 Tìm kiếm, S30 Mất kết nối, khu demo Firebase | Khu demo dùng được |
| 6 | T50, T51, T52 | Analytics (≥ 7 sự kiện, ảnh DebugView), Crashlytics (1 lỗi không crash, 1 crash thử), Remote Config (≥ 2 tham số đổi hành vi) | Bằng chứng trên console |
| song song | T31, T32 | Giữ rules và dữ liệu mẫu (đã có khung); sau khi nhóm có thành viên đăng nhập, gán vai trò staff bằng `set-role.mjs` | Rules có ca được phép và bị từ chối |

**Làm được ngay hôm nay:** T01 phần còn lại, T22, T33. S15–S18, S27, S28, S30 làm với dữ liệu giả.
**Chờ ai:** không chờ ai, nhưng cả nhóm chờ mình.
**Ai chờ mình:** P1 chờ T33; P4 chờ T30 (vai trò người bán) và T33; P2 chờ T22 (`MessagingService`) và Storage.
**Báo cáo và slide:** mỗi dịch vụ Firebase một mục, cách xử lý lỗi, ảnh console, mô hình dữ liệu và rules.
**Vấn đáp:** đổi 1 giá trị Remote Config trực tiếp và cho thấy app đổi theo; giải thích 1 rule Firestore hoặc Storage.

---

## P4 · App người bán, code review, báo cáo

**Mục tiêu:** làm trọn app người bán, điều phối AI code review, gom báo cáo, slide, video.

| Thứ tự | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T11 | Hỏi thầy và lưu xác nhận bằng văn bản: nhóm 4 người, phạm vi app khách và app người bán, các sai lệch D01–D06 | Xác nhận lưu trong `docs/` |
| 2 | T44 | K01–K06: cổng vai trò, hàng đợi đơn, chi tiết, đang chuẩn bị, quét mã, giao món và thu tiền mặt (F5 "người bán" dùng dữ liệu giả) | Một đơn xử lý được từ nhận tới giao |
| 3 | T45 | K08–K15: quản lý món, đánh dấu hết, quán, thống kê ca, từ chối đơn, sự cố, thêm và sửa món | Đổi món ở bên bán thấy ngay bên khách |
| 4 | T34 | Phần xử lý của `IncidentService` (xem, đổi trạng thái), bản Firestore cho K13 | K13 dùng dữ liệu thật |
| 5 | T70, T71 | Mở PR, chạy ≥ 1 công cụ AI review, điều phối quyết định từng phát hiện | `docs/code-review.md` đầy đủ |
| cuối | T80, T81, T82 | Gom báo cáo PDF, slide, video (mỗi người gửi mục và đoạn quay của mình) | 3 sản phẩm nộp |

**Làm được ngay hôm nay:** T11 và K01–K15 với dữ liệu giả (cấu hình F5 "người bán, đã đăng nhập").
**Chờ ai:** P3 (T30 vai trò, T33 đơn thật); P1 (đơn đặt thật để thử K02–K06); P2 (`IncidentService` tạo sự cố cho K13).
**Ai chờ mình:** cả nhóm chờ lịch gom báo cáo, slide, video.
**Báo cáo và slide:** app người bán, code review, khó khăn và bài học, danh sách công cụ AI.
**Vấn đáp:** giải thích 1 quyết định review (vì sao accept hay reject), luồng nhận và giao đơn của người bán.

**Lưu ý tải việc:** P4 giữ 14 màn cộng review, báo cáo, slide, video. Nếu sau tuần 2 P4 chậm, P1 hoặc P2 nhận K10–K13 (quán, thống kê, từ chối đơn, sự cố). Báo trong nhóm để chuyển issue.

---

## Điểm nghẽn và cách tránh

| Chỗ dễ nghẽn | Cách tránh |
|---|---|
| Mọi người cùng sửa `services.dart`, `app_services.dart`, `dev_services.dart`, `models.dart` | Mỗi dịch vụ mới nằm file riêng `lib/services/<tính năng>_service.dart`, bản giả ở `lib/dev/dev_<tính năng>.dart`; chỉ thêm một dòng vào file chung. PR sửa file chung phải nhỏ và merge nhanh. Chi tiết: `CONTRIBUTING.md` |
| Chờ P3 nối Firebase thật | Làm bằng dữ liệu giả; khi P3 xong chỉ đổi cờ chạy, không sửa màn |
| P2 chờ S07, S08 của P1 để làm S09–S12 | P2 làm S13, S20–S24 trước; P1 làm S07, S08 sớm trong tuần 2 |
| P4 chờ đơn thật để thử người bán | Dùng dev services trước (đơn giả); sau T33 thử với đơn thật |
| Sửa theme, widget chung | Chỉ P1 sửa `lib/theme/`, `lib/widgets/`; ai cần thì mở issue hoặc PR nhỏ cho P1 duyệt |

## Mốc kiểm tra cuối mỗi tuần

| Cuối tuần | Phải có |
|---|---|
| 1 | Cả nhóm clone, build, chạy được app bằng F5; Firebase mời đủ người, SHA-1 đủ máy; mỗi người xong ít nhất 2 màn đúng Figma với dữ liệu giả; `bootstrap.dart` chạy được |
| 2 | Đăng nhập Google và dữ liệu Firestore thật chạy; mỗi người có ít nhất 5 màn; F1 đặt món chạy trọn |
| 3 | Mọi màn S01–S30, K01–K15 chạy với đủ trạng thái; 6 dịch vụ Firebase có bằng chứng; test plan xong |
| 4 | Test ARTEMIS chạy ≥ 3 lần mỗi test; code review xong; báo cáo, slide, video; checklist nộp bài |

Ai trễ một mốc thì báo ngay trong nhóm để chia lại việc.
