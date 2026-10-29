# Kế hoạch task (nhóm 4 người)

Phân công theo người: [`PHAN-CONG.md`](PHAN-CONG.md). Thứ tự bám đúng quy trình handout: **Plan, Architect, Integrate, Instrument, Test, Review, Report**. Git history phải cho thấy các bước này theo thứ tự, và commit của từng người phải thấy được.

Hạn nộp: `[điền ngày]`. Số commit và số ngày tối thiểu: `[điền khi thầy công bố]`.

## Phân công

| Người | Vai trò | Phụ trách chính | Điểm rubric gánh chính |
|---|---|---|---|
| **P1** | Kiến trúc, design system, luồng đặt món | Repo, khung MVVM, theme và thư viện widget, `design-traceability.md`, `architecture.md`, màn S01–S08 và biến thể | Kiến trúc 0,75, UI/UX 0,75, một phần Chức năng |
| **P2** | App khách mở rộng, thông báo, test E2E | Màn S09–S14, S19–S25, S27–S30; sinh PDF và tải lên; FCM và trung tâm thông báo; bộ test ARTEMIS | Chức năng, FCM 0,5, Test 1,5 |
| **P3** | Firebase và tài khoản | Auth, Storage, Analytics, Crashlytics, Remote Config, tầng service bọc SDK; S15–S18, S26; khu demo Firebase | Firebase 2,0 |
| **P4** | App người bán, code review, báo cáo | Toàn bộ app người bán K01–K15; AI code review; gom báo cáo, slide, video | Chức năng (người bán), Review 0,5, Slide và video 2,0 |

Quy tắc chung:
- Mỗi người **tự viết test case (bước, kết quả mong đợi) cho màn mình làm** vào `docs/test-plan.md`; P2 gom, chạy và đánh giá độ tin cậy.
- Mỗi người **tự đặt `Semantics` label** cho màn mình để ARTEMIS đọc được.
- Mỗi người **viết phần báo cáo và quay đoạn video của phần mình**; P4 ghép.
- Ai cũng phải giải thích được code của mình và một quyết định review (có thể bị hỏi vấn đáp 5 phút).

## Quy ước Git

- Nhánh `feat/T41-ten-ngan`, `docs/T10-...`, `fix/CR-01-...`; không commit thẳng vào `main`.
- Mỗi PR do **người khác** duyệt; commit message mở đầu bằng mã task: `[T41] Add cart screen states`.
- Commit sửa lỗi review ghi ID phát hiện: `[CR-01] Move API call out of HomeScreen`.
- Không commit khoá service-account, API key, keystore; dùng biến môi trường. `google-services.json` được commit.

## Danh sách task theo thứ tự

Cột "Phụ thuộc" cho biết task nào phải xong trước.

### Giai đoạn 0 · Chuẩn bị (tuần 1, ngày 1–2)

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T00 | P1 | Tạo repo GitHub `PRM393_Lab03_<MSSV>`, mời 3 thành viên, bật bắt buộc PR cho `main`, đẩy khung repo này lên | Cả 4 người clone và push được | — |
| T01 | P3 | Tạo Firebase project (Spark), đăng ký app Android, bật Auth (Google), Firestore, Storage, Cloud Messaging, Analytics, Crashlytics, Remote Config; thêm SHA-1 máy của từng người; mời 3 người vào project | Cả nhóm đăng nhập console được; có `google-services.json` | T00 |
| T02 | P2 | Chuẩn bị máy test: thiết bị Android hoặc emulator, ADB, ARTEMIS (Python 3.12, uv), API key mô hình đặt trong biến môi trường, tài khoản Google dành riêng cho test; ghi commit ARTEMIS đã ghim | Chạy được 1 lệnh ARTEMIS mẫu | T00 |
| T03 | P1 | `flutter create`, ghim phiên bản trong `pubspec.yaml`, `flutterfire configure`, cập nhật `README.md` mục phiên bản | App rỗng chạy trên thiết bị, Firebase khởi tạo không lỗi | T01 |

### Giai đoạn 1 · Plan

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T10 | P1 (mỗi người sửa hàng của mình) | Hoàn thiện `docs/design-traceability.md`: ma trận màn, flow, component và danh sách sai lệch | Mọi màn S01–S30, K01–K15 có route, widget, nguồn dữ liệu, người phụ trách | T00 |
| T11 | P4 | Chốt phạm vi với thầy bằng văn bản: nhóm 4 người, app khách và app người bán, các sai lệch D01 (Google Sign-In thay OTP) | Có xác nhận của thầy, lưu trong `docs/` | — |

### Giai đoạn 2 · Architect

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T20 | P1 | `docs/architecture.md`: cấu trúc thư mục, sơ đồ tầng, sơ đồ tuần tự một flow đầy đủ, bảng ViewModel và service; dựng khung `lib/` (models, services, firebase, viewmodels, screens, widgets, utils), DI bằng Provider hoặc Riverpod, lớp trạng thái dùng chung (sealed class loading, empty, error, data), router | Khung chạy, `architecture.md` khớp code | T03, T10 |
| T21 | P1 | `lib/theme/`: token thành `ColorScheme`, `TextTheme`, hằng số khoảng cách, bo góc; thư viện widget ở mục 4 của traceability; kiểm 360 dp và 412 dp, vùng bấm ≥ 48 dp, chữ ≥ 14 sp | Widget catalog hiển thị đủ biến thể, không tràn | T20 |
| T22 | P3 | Tầng service bọc SDK (`AuthService`, `StorageService`, `MessagingService`, `AnalyticsService`, `CrashService`, `RemoteConfigService`): interface và bản giả đã có; **viết bản Firebase trong `lib/firebase/`** và `bootstrap.dart` | Không widget nào gọi SDK trực tiếp | T20 |

### Giai đoạn 3 · Integrate (Firebase và dữ liệu)

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T30 | P3 | Google Sign-In, định tuyến theo trạng thái đăng nhập, đăng xuất xoá dữ liệu local, xử lý huỷ và mất mạng; lưu `users/{uid}` kèm `role` | Ảnh hai trạng thái, tab Users trong console | T22 |
| T31 | P3 | Mô hình dữ liệu Firestore và `firebase/firestore.rules` mặc định từ chối, theo vai trò; script nạp dữ liệu mẫu thật vào Firestore (thực đơn, kiosk, voucher) | Rules đã kiểm trong Emulator; không dữ liệu cứng trong app | T30 |
| T32 | P3 | `firebase/storage.rules` theo từng người dùng; `StorageService` tải lên có tiến trình, trả URL | Người khác không đọc được thư mục của mình | T30 |
| T33 | P3 | Bản Firestore của `MenuService`, `CartService`, `OrderService` (kiosk, voucher, slot) trong `lib/firebase/`: truy vấn theo `docs/data-model.md` mục 5, đặt đơn bằng một batch (tạo đơn, xoá giỏ, tăng slot) | Đơn đặt ở app khách hiện ngay ở app người bán; không dữ liệu cứng trong app | T22, T31 |
| T34 | Mỗi chủ màn | Dịch vụ theo tính năng, mỗi người làm của mình (interface ở `lib/services/<tên>_service.dart`, bản giả ở `lib/dev/dev_<tên>.dart`, bản Firestore ở `lib/firebase/`): P1 `SlotService`, `VoucherService`; P2 `ReviewService`, `FavoriteService`, `NotificationService`, `IncidentService` (tạo); P4 phần xử lý sự cố cho K13 | Màn của mình dùng dữ liệu thật; có test ViewModel với bản giả | T33 |

### Giai đoạn 4 · Features (song song sau T21 và T31)

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T40 | P1 | Luồng đặt món: S01 và S02 đã xong (màn mẫu); còn S03 thực đơn, S04 chi tiết, S05 giỏ, S25 hẹn giờ, S29 chọn mã, S06 và biến thể thanh toán, S06-GATEWAY, S07 theo dõi đơn, S08 đơn hàng; thông báo thêm vào giỏ | Chạy trọn F1 và F3 trên thiết bị | T21, T33 |
| T41 | P2 | S09–S14, S19–S25, S27–S30: sửa và huỷ đơn, lịch sử, yêu thích, đặt lại, thông báo, mã QR nhận món, đánh giá, báo sự cố, hẹn giờ, chọn kiosk, tìm kiếm, mã giảm giá, mất kết nối | F2 chạy trọn; mọi màn có loading, empty, error có thử lại | T21, T31 |
| T42 | P3 | S15–S18, S26, S27 chọn kiosk, S28 tìm kiếm, S30 mất kết nối và khu demo Firebase trong Profile (trung tâm thông báo, xuất file và tải lên, giá trị Remote Config, nút thử Crashlytics) | Khu demo thao tác được đủ các mục | T30 |
| T43 | P2 | Sinh PDF (biên lai hoặc tóm tắt đơn đang xem), tải lên qua `StorageService`, hiện tiến trình và URL | File tải lên đúng thư mục `reports/{uid}/…` | T32, T41 |
| T44 | P4 | App người bán K01–K06: cổng vai trò, hàng đợi đơn thời gian thực, chi tiết, đang chuẩn bị, quét mã, giao món và thu tiền mặt | Một đơn của khách xuất hiện và xử lý được ở app người bán | T33, T40 |
| T45 | P4 | K08–K15: quản lý món, đánh dấu hết món, trạng thái quán, thống kê ca, từ chối đơn, sự cố, thêm và sửa món | Đổi món ở app người bán thấy ngay ở app khách | T33, T44 |

### Giai đoạn 5 · Instrument

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T50 | P3 | `docs/analytics-plan.md` và code ghi sự kiện (≥ 7, đặt `userId` sau đăng nhập, không dữ liệu cá nhân) | Mỗi sự kiện có ảnh DebugView | T30 |
| T51 | P3 | Crashlytics: 1 lỗi không gây crash từ đường lỗi thật, 1 crash thử, kèm user ID và custom key | Dashboard thấy cả hai, kèm key | T30 |
| T52 | P3 | Remote Config ≥ 2 tham số đổi hành vi nhìn thấy trên màn (ví dụ số món "nhanh dưới 5 phút", bật tắt banner Combo Giờ Vàng); `firebase/remote-config-defaults.json` | Ảnh trước và sau, giá trị trên console | T40 |
| T53 | P2 (dùng `MessagingService` của P3) | FCM: nhận ở 3 trạng thái, xin quyền Android 13+, danh sách thông báo trong app, chạm vào mở màn liên quan | Tin thử từ console tới được ở mỗi trạng thái | T41 |

### Giai đoạn 6 · Test

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T60 | P2 (mỗi người nộp case của mình) | `docs/test-plan.md`: ≥ 10 test case, đủ phủ nội dung mục 7 handout (có nhánh lỗi, tương tác native, phiên khám phá) | Mọi flow Lab 2 và đường lỗi có test | T10 |
| T61 | Tất cả | Thêm `Semantics` label cho nút, ô danh sách, biểu đồ của màn mình | ARTEMIS đọc được cây trợ năng của màn | T40–T45 |
| T62 | P2 | Viết test ARTEMIS bằng pytest trong `e2e_test/`, kiểm theo giá trị agent trả về, ≥ 3 lần mỗi test, bảng tỉ lệ đạt, phân tích test chập chờn; 1 test kiểm sự kiện analytics đã ghi | Bảng kết quả, dấu vết hoặc ảnh cho mỗi lần chạy | T61, T50 |
| T63 | P2 | Phiên khám phá hồ sơ Pro 15 đến 30 phút, danh sách lỗi tìm được | Báo cáo phiên khám phá | T62 |

### Giai đoạn 7 · Review

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T70 | P4 | Mở PR, chạy ít nhất 1 công cụ AI review, lưu đầu ra | Đầu ra công cụ nằm trong `evidence/` | T40–T45 |
| T71 | Tất cả | Mỗi người quyết định (accept, modify, reject) các phát hiện thuộc file của mình, lý do dẫn tới yêu cầu cụ thể; tổng ≥ 5 phát hiện, ≥ 3 commit sửa lỗi nêu ID | `docs/code-review.md` đủ bảng, link commit | T70 |
| T72 | P1 | Kiểm tra quy tắc MVVM toàn repo (không SDK trong widget, không logic trong `build()`), đối chiếu `architecture.md` | Danh sách vi phạm bằng 0 hoặc đã ghi lý do | T71 |

### Giai đoạn 8 · Report

| ID | Người | Việc | Xong khi | Phụ thuộc |
|---|---|---|---|---|
| T80 | P4 (mỗi người viết mục của mình) | Báo cáo PDF 8 đến 12 trang theo mục lục handout, mỗi khẳng định có ảnh hoặc link bằng chứng | `report/Lab03_<MSSV>.pdf` | T72 |
| T81 | P4 | Slide 12 đến 15 trang PDF, mỗi slide "chạy được" có ảnh minh chứng, Figma và app đặt cạnh nhau | `slides/Lab03_<MSSV>_slides.pdf` | T80 |
| T82 | P4 (mỗi người quay phần mình) | Video 5 đến 10 phút quay trực tiếp trên thiết bị: đăng nhập, từng flow kể cả nhánh lỗi, xuất và tải lên, thông báo đẩy, đổi Remote Config không build lại, Crashlytics, chạy 1 test ARTEMIS, 1 phát hiện review và cách sửa | Link video công khai trong README | T80 |
| T83 | P1 | Cập nhật Figma theo `design-traceability.md` mục 5; chạy checklist nộp bài; mở repo, báo cáo, slide, video bằng cửa sổ ẩn danh | Mọi mục checklist đã tích | T82 |

## Mốc tham khảo (điều chỉnh theo hạn thật)

| Tuần | Mục tiêu |
|---|---|
| 1 | T00–T03, T10, T11, T20, T21, T22 |
| 2 | T30–T32, bắt đầu T40, T41, T42, T44 |
| 3 | Hoàn thành T40–T45, T50–T53 |
| 4 | T60–T63, T70–T72, T80–T83 |

Nên có buổi họp ngắn đầu và giữa mỗi tuần; người nào chậm hơn một mốc thì báo ngay để chia lại việc.

## Tiến độ nền (khung đã dựng sẵn)

Phần nền để 4 người làm song song đã có trong repo. Cần review chứ chưa coi là xong.

| Task | Trạng thái | Ghi chú |
|---|---|---|
| T03 | Xong | Đã `flutter create`, ghim phiên bản và `flutterfire configure` (project `breakbite-1315b`) |
| T20 | Xong khung | Khung MVVM, router, DI, `ViewState`; `docs/architecture.md` cần P1 cập nhật cho khớp code |
| T21 | Xong khung | Theme từ token Lab 2 và widget chung; font Nunito đã có trong `assets/fonts/`; S02 là màn mẫu đã làm theo Figma v2 |
| T22 | Một phần | Đã có interface, bản giả và model; **P3 cần viết bản cài đặt Firebase** và `bootstrap.dart` trong `lib/firebase/` |
| T31 | Một phần | Mô hình dữ liệu đã chốt khung (`docs/data-model.md`), rules và chỉ mục đã đẩy lên, **82/82 test rules đạt**. Script nạp dữ liệu mẫu và gán vai trò đã viết và kiểm trên Emulator (`firebase/seed/`). Đã nạp vào Firestore thật ngày 29/10/2026 (3 kiosk, 25 món, 3 voucher, 40 slot). **Còn:** gán vai trò staff và admin cho thành viên bằng `set-role.mjs` sau khi họ đăng nhập app một lần |
| T01 | Một phần | Project `breakbite-1315b` (Spark): app Android, SHA-1 máy P1, Auth Google, Firestore (`asia-southeast1`), rules và Remote Config đã đẩy lên. **Còn:** Storage (console đòi gói Blaze), Crashlytics, SHA-1 của 3 máy còn lại, mời 3 người vào project |
| T02 | Chưa | Cần thiết bị Android và API key ARTEMIS |
| T40 | Một phần | S01 Onboarding và S02 Trang chủ xong, làm theo Figma v2 (màn mẫu cho cả nhóm). Còn S03–S08, S25, S29 |
| T33, T34 | Chưa | Chưa ai viết bản Firestore của `MenuService`, `CartService`, `OrderService` và các dịch vụ theo tính năng |

Cách làm song song: mỗi người sửa file route của mình (`lib/router/routes_pX.dart`) để thay màn tạm bằng màn thật; dùng `--dart-define=USE_DEV_SERVICES=true` để chạy khi Firebase chưa nối. **Trước khi nộp xoá `lib/dev/` (T83).**
