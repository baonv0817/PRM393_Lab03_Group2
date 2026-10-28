# Phân công Lab 3 (4 người)

Tài liệu gốc: handout *PRM393 Lab 3: Cloud-Enabled Mobile App*. Chi tiết từng task, điều kiện xong và phụ thuộc nằm ở [`TASKS.md`](TASKS.md); mỗi task có một issue trên GitHub cùng mã.

Ghi tên người nhận vào bảng dưới rồi gán issue tương ứng.

| Vai trò | Người nhận | Rubric gánh chính (trên 10 điểm) |
|---|---|---|
| **P1** Kiến trúc, design system, luồng đặt món | `[tên, MSSV]` | Kiến trúc 0,75 · UI/UX 0,75 · Chức năng (F1, F3) |
| **P2** App khách mở rộng, thông báo, test E2E | `[tên, MSSV]` | Chức năng (F2, các màn còn lại) · FCM 0,5 · Test ARTEMIS 1,5 |
| **P3** Firebase và tài khoản | `[tên, MSSV]` | Firebase 2,0 (trừ FCM phần màn hình) · Auth, Storage, Analytics, Crashlytics, Remote Config |
| **P4** App người bán, code review, báo cáo | `[tên, MSSV]` | Chức năng (app người bán) · Code review 0,5 · Slide và video 2,0 |

---

## Việc chung của cả 4 người

Bắt buộc, ai cũng phải làm, vì thầy có thể hỏi riêng từng người (khoảng 5 phút: chạy 1 test ARTEMIS, đổi 1 giá trị Remote Config trực tiếp, giải thích 1 ViewModel và 1 quyết định review).

1. Commit đều đặn qua nhiều ngày, mỗi commit mở đầu bằng mã task, ví dụ `[T41] Add history screen states`. Không dồn code lên một người.
2. Làm trên nhánh riêng, mở PR, nhờ người khác duyệt rồi mới merge vào `main`.
3. Màn nào mình làm thì mình: điền hàng của mình trong `docs/design-traceability.md`, đặt `Semantics` label (T61), viết test case vào `docs/test-plan.md`, quyết định các phát hiện review thuộc file của mình (T71), viết mục báo cáo và quay đoạn video của phần mình.
4. Không gọi SDK trong widget, không viết logic trong `build()`, không màu hay cỡ chữ cứng (dùng theme và widget chung của P1).
5. Mỗi màn tải dữ liệu có đủ loading, empty, error kèm nút thử lại; nút Back đi đúng chỗ.
6. Không commit khoá, mật khẩu, keystore.
7. Đọc và chạy thử được phần của người khác ít nhất một lần trước buổi nộp.

---

## P1 · Kiến trúc, design system, luồng đặt món

**Mục tiêu:** dựng nền để 3 người còn lại làm song song, và làm trọn luồng đặt món F1, F3.

| Tuần | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T00 | Hoàn tất repo: mời thành viên, bật bắt buộc PR cho `main` | Repo có 4 người |
| 1 | T03 | `flutter create`, ghim phiên bản, `flutterfire configure`, cập nhật README | App rỗng chạy được |
| 1 | T10 | Dẫn việc hoàn thiện `design-traceability.md` (mỗi người sửa hàng của mình) | Ma trận đầy đủ |
| 1 | T20 | `docs/architecture.md` và khung MVVM: thư mục, DI, router, lớp `ViewState` dùng chung | Khung chạy, tài liệu khớp code |
| 1–2 | T21 | `lib/theme/` và thư viện widget Lab 2 (nút, ô nhập, thẻ món, thanh dưới, app bar, dialog, loading, empty, error, snackbar); kiểm 360 dp, 412 dp | Màn mẫu hiển thị đủ biến thể |
| 2–3 | T40 | S01–S08 và biến thể: onboarding, trang chủ, thực đơn, chi tiết món, giỏ, chọn phương thức, cổng mô phỏng, theo dõi đơn, lịch sử | F1 và F3 chạy trọn trên máy |
| 4 | T72 | Kiểm quy tắc MVVM toàn repo, đối chiếu `architecture.md` | Không còn vi phạm |
| 4 | T83 | Cập nhật Figma theo các sai lệch đã ghi; chạy checklist nộp bài | Checklist tích đủ |

**Chờ ai:** P3 xong T01 (Firebase project) trước T03; P3 xong T31 (dữ liệu Firestore) trước khi nối dữ liệu thật vào T40.
**Ai chờ mình:** cả nhóm chờ T20, T21. Phải xong trong tuần 1.
**Phần báo cáo và slide:** kiến trúc MVVM, sơ đồ tầng, design system trong code, so sánh Figma và app.
**Chuẩn bị vấn đáp:** giải thích luồng dữ liệu của `CartViewModel` hoặc `CheckoutViewModel`, vì sao trạng thái là sealed class.

---

## P2 · App khách mở rộng, thông báo, test E2E

**Mục tiêu:** làm phần lớn màn còn lại của app khách, trung tâm thông báo, file xuất ra, và gánh bộ test ARTEMIS.

| Tuần | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T02 | Chuẩn bị máy test: thiết bị Android hoặc emulator, ADB, ARTEMIS (Python 3.12, uv), API key mô hình trong biến môi trường, tài khoản Google riêng cho test; ghim commit ARTEMIS | Chạy được 1 lệnh ARTEMIS mẫu |
| 1–2 | T60 | Khung `docs/test-plan.md`: flow quan trọng, ≥ 10 test case phủ đủ mục 7 handout (nhánh lỗi, tương tác native, từng tab, màn chi tiết, xuất file, Remote Config, đăng xuất); gom case từ các bạn | Test plan hoàn chỉnh |
| 2–3 | T41 | S09–S14, S19–S25, S27–S30: sửa và huỷ đơn, lịch sử, yêu thích, đặt lại, thông báo, mã QR nhận món, quán đóng, món hết, đánh giá, báo sự cố, hẹn giờ, chọn kiosk, tìm kiếm, mã giảm giá, mất kết nối | F2 chạy trọn; mọi màn đủ trạng thái |
| 3 | T43 | Sinh PDF biên lai của đơn đang xem, tải lên qua `StorageService` (của P3), hiện tiến trình và URL | File nằm ở `reports/{uid}/…` |
| 3 | T53 | FCM: nhận ở 3 trạng thái app, xin quyền Android 13+, lưu danh sách trong S19, chạm thông báo mở đúng màn | Tin thử từ console tới ở cả 3 trạng thái |
| 4 | T62 | Viết test pytest trong `e2e_test/`, kiểm theo giá trị agent báo về, chạy ≥ 3 lần mỗi test, bảng tỉ lệ đạt, giải thích test chập chờn; 1 test kiểm sự kiện analytics | Bảng kết quả, dấu vết từng lần chạy trong `evidence/artemis/` |
| 4 | T63 | Phiên khám phá hồ sơ Pro 15 đến 30 phút | Danh sách lỗi tìm được |

**Chờ ai:** P1 (T21 widget, T40 màn đặt món) trước T41; P3 (T22 `MessagingService`, T32 `StorageService`) trước T43, T53.
**Ai chờ mình:** P4 cần bảng kết quả test để làm slide và video.
**Phần báo cáo và slide:** test plan, kết quả ARTEMIS, phiên khám phá, FCM.
**Chuẩn bị vấn đáp:** chạy trực tiếp 1 test ARTEMIS, giải thích vì sao assert theo giá trị báo về chứ không chỉ `SUCCESS`.

---

## P3 · Firebase và tài khoản

**Mục tiêu:** đủ 6 dịch vụ Firebase, mỗi dịch vụ có xử lý lỗi và có bằng chứng trên console.

| Tuần | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T01 | Tạo Firebase project (Spark), app Android, bật Auth (Google), Firestore, Storage, Messaging, Analytics, Crashlytics, Remote Config; thêm SHA-1 của từng máy; mời cả nhóm | Cả nhóm vào được console |
| 1 | T22 | Tầng service bọc SDK có interface và bản giả: `AuthService`, `StorageService`, `MessagingService`, `AnalyticsService`, `CrashService`, `RemoteConfigService` | Không widget nào gọi SDK |
| 2 | T30 | Google Sign-In, định tuyến theo trạng thái đăng nhập, đăng xuất xoá dữ liệu local, báo lỗi khi huỷ hoặc mất mạng; tạo `users/{uid}` có `role` | Ảnh 2 trạng thái, tab Users |
| 2 | T31 | Mô hình Firestore, hoàn thiện `firestore.rules` (kiểm trong Emulator), script nạp dữ liệu thật (thực đơn, kiosk, voucher) | Rules có ca được phép và bị từ chối |
| 2 | T32 | `storage.rules` theo từng người, `StorageService` có tiến trình và trả URL | Người khác không đọc được thư mục |
| 2–3 | T42 | S15–S18, S26 và khu demo Firebase trong Profile: trung tâm thông báo, xuất và tải lên, giá trị Remote Config, nút thử Crashlytics | Khu demo dùng được |
| 3 | T50 | Hoàn thiện `docs/analytics-plan.md` (≥ 7 sự kiện, có câu hỏi sản phẩm, không dữ liệu cá nhân), ghi sự kiện, `setUserId` | Ảnh DebugView cho từng sự kiện |
| 3 | T51 | Crashlytics: 1 lỗi không gây crash từ đường lỗi thật, 1 crash thử, kèm user ID và custom key | Dashboard thấy cả hai |
| 3 | T52 | Remote Config ≥ 2 tham số đổi hành vi trên màn (`quick_items_limit`, `promo_banner_enabled`), có giá trị mặc định | Ảnh trước và sau khi đổi trên console |

**Chờ ai:** P1 (T20 khung) trước T22.
**Ai chờ mình:** cả nhóm chờ T01; P1 chờ T31; P2 chờ T22, T32; P4 chờ T30 (vai trò người bán).
**Phần báo cáo và slide:** mỗi dịch vụ Firebase một mục hoặc một slide, kèm cách xử lý lỗi và ảnh console.
**Chuẩn bị vấn đáp:** đổi 1 giá trị Remote Config trực tiếp và cho thấy app đổi theo; giải thích 1 rule Storage hoặc Firestore.

---

## P4 · App người bán, code review, báo cáo

**Mục tiêu:** làm trọn app người bán, điều phối AI code review, gom báo cáo, slide, video.

| Tuần | Task | Việc | Sản phẩm |
|---|---|---|---|
| 1 | T11 | Hỏi thầy và lưu xác nhận bằng văn bản: nhóm 4 người, phạm vi app khách và app người bán, sai lệch D01 (Google Sign-In thay OTP), tên repo | Xác nhận lưu trong `docs/` |
| 2–3 | T44 | K01–K06: cổng vai trò, hàng đợi đơn thời gian thực, chi tiết đơn, đang chuẩn bị, quét mã, giao món và thu tiền mặt | Đơn khách đặt hiện và xử lý được ở app người bán |
| 3 | T45 | K08–K15: quản lý món, đánh dấu hết món, trạng thái quán, thống kê ca, từ chối đơn, sự cố, thêm và sửa món | Đổi món bên bán thấy ngay bên khách |
| 4 | T70 | Mở PR, chạy ít nhất 1 công cụ AI review (Copilot review, CodeRabbit, SonarCloud…), lưu đầu ra | Đầu ra trong `evidence/code-review/` |
| 4 | T71 | Điều phối: mỗi người quyết định phát hiện thuộc file mình; tổng ≥ 5 phát hiện, ≥ 2 loại, ≥ 3 commit sửa có ID | `docs/code-review.md` đầy đủ |
| 4 | T80 | Gom báo cáo PDF 8 đến 12 trang theo mục lục handout, mỗi khẳng định có bằng chứng | `report/Lab03_<MSSV>.pdf` |
| 4 | T81 | Slide 12 đến 15 trang, Figma và app đặt cạnh nhau, mỗi slide "chạy được" có ảnh | `slides/Lab03_<MSSV>_slides.pdf` |
| 4 | T82 | Video 5 đến 10 phút quay trực tiếp theo thứ tự test plan (mỗi người quay phần mình, P4 ghép), link trong README | Link video mở được |

**Chờ ai:** P3 (T30 vai trò) trước T44; P1 (T21 widget) trước T44, T45; cả nhóm gửi mục báo cáo và đoạn video trước T80, T82.
**Phần báo cáo và slide:** app người bán, code review, khó khăn và bài học, danh sách công cụ AI.
**Chuẩn bị vấn đáp:** giải thích 1 quyết định review (vì sao accept hay reject), luồng nhận và giao đơn của người bán.

---

## Mốc kiểm tra cuối mỗi tuần

| Cuối tuần | Phải có |
|---|---|
| 1 | Repo đủ người; Firebase project chạy; app rỗng build được; `architecture.md`, `design-traceability.md` xong; theme và widget cơ bản |
| 2 | Đăng nhập Google chạy; dữ liệu thật trên Firestore; rules bản đầu; mỗi người có ít nhất 3 màn chạy |
| 3 | Mọi màn S01–S30, K01–K15 chạy với đủ trạng thái; 6 dịch vụ Firebase có bằng chứng; test plan xong |
| 4 | Test ARTEMIS chạy ≥ 3 lần mỗi test; code review xong; báo cáo, slide, video; checklist nộp bài |

Ai trễ một mốc thì báo ngay trong nhóm để chia lại việc.
