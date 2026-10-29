# Cách làm việc trong repo

Đọc một lần trước khi viết code. Phân công: [`PHAN-CONG.md`](PHAN-CONG.md). Cài môi trường: [`docs/setup.md`](docs/setup.md).

## 1. Chạy app

Mở VS Code, bấm **F5**, chọn cấu hình:

| Cấu hình | Dùng khi |
|---|---|
| BreakBite khách (dữ liệu giả, đã đăng nhập) | Làm màn của app khách. Mặc định cho mọi người |
| BreakBite người bán (dữ liệu giả, đã đăng nhập) | Làm màn của app người bán (K01–K15) |
| BreakBite (dữ liệu giả, từ đầu: Onboarding rồi Đăng nhập) | Thử luồng mở app |
| BreakBite (Firebase thật) | Sau khi P3 xong `bootstrap.dart` và T33 |

Sửa code rồi lưu là giao diện tự cập nhật. Thiết bị: máy ảo Android, Chrome hoặc điện thoại Android (xem `docs/setup.md`). iPhone không chạy được app này từ máy Windows.

## 2. Làm một màn: sao theo S02

Màn mẫu: `lib/screens/home_screen.dart`, `lib/viewmodels/home_view_model.dart`, `test/home_screen_test.dart`, `test/home_view_model_test.dart`, và cách nối ở `lib/router/routes_p1.dart`.

1. **Đọc hàng của màn** trong `docs/design-traceability.md` (route, ViewModel, nguồn dữ liệu) và ảnh Figma trong thư mục `assets/figma/` của repo Lab 2 (`final-ui-v2` cho S01–S07, `final-ui-s09-s25` cho S09–S25; app người bán và S26 trở đi: hỏi P1 hoặc xem Page 03 trong Figma). Figma là tham khảo: bỏ phần thừa hoặc rối mắt được, nhưng **ghi sai lệch** vào mục 5 của file đó (mã D07, D08…).
2. **Viết ViewModel** `lib/viewmodels/<tên>_view_model.dart`: nhận service qua constructor, giữ `ViewState` (loading, empty, error, data), mọi logic ở đây. Không import `package:firebase_*`.
3. **Viết màn** `lib/screens/<tên>_screen.dart`: chỉ đọc ViewModel (`context.watch`) và vẽ. Dùng widget trong `lib/widgets/`, màu và cỡ chữ từ theme (`context.appColors`, `Theme.of(context).textTheme`), khoảng cách từ `AppSpacing`.
4. **Nối route** trong file `lib/router/routes_pX.dart` của mình: thay `placeholderRoute(...)` bằng `GoRoute` tạo ViewModel như `homeRoute`.
5. **Viết test**: một test ViewModel (dữ liệu, lỗi, rỗng) và một test widget (hiện đúng, bấm đúng). Dữ liệu giả lấy từ `lib/dev/`.
6. **Chạy kiểm tra** trước khi mở PR (mục 5).
7. **Cập nhật** trạng thái hàng của màn trong `design-traceability.md` thành `Xong`.

## 3. Quy tắc cho file dùng chung

Đây là chỗ cả nhóm dễ giẫm lên nhau. Sửa file chung thì làm **PR riêng, nhỏ, merge nhanh**, đừng gộp vào PR của màn.

| File hoặc thư mục | Ai sửa | Quy tắc |
|---|---|---|
| `lib/theme/`, `lib/widgets/` | P1 | Cần widget hoặc biến thể mới: mở issue hoặc PR nhỏ cho P1 duyệt. Không tự thêm màu, cỡ chữ cứng trong màn |
| `lib/router/app_router.dart` | P1 | Không sửa. Mỗi người chỉ sửa `routes_p1.dart` đến `routes_p4.dart` của mình |
| `lib/router/routes_pX.dart` | chủ file | Chỉ sửa file của mình |
| `lib/services/services.dart`, `lib/services/app_services.dart` | cả nhóm | **Không nhét thêm interface vào `services.dart`.** Dịch vụ mới nằm file riêng `lib/services/<tính năng>_service.dart`; thêm đúng một trường vào `AppServices` |
| `lib/dev/dev_services.dart` | cả nhóm | Bản giả của dịch vụ mới nằm file riêng `lib/dev/dev_<tính năng>.dart`; thêm đúng một dòng vào `createDevServices` |
| `lib/models/models.dart` | cả nhóm | Chỉ **thêm**: lớp mới hoặc trường mới có giá trị mặc định ở cuối. Không đổi tên, không xoá, để code của người khác vẫn biên dịch. Đổi cấu trúc dữ liệu thì làm đủ 4 nơi (`docs/data-model.md`) |
| `firebase/firestore.rules`, `storage.rules`, `docs/data-model.md` | P3 duyệt | Sửa kèm test ở `firebase/tests/rules.test.mjs`; `npm test` phải đạt |
| `lib/firebase/` | P3 (dịch vụ chung); chủ tính năng (dịch vụ của mình) | Chỉ chỗ này được import SDK Firebase |
| `pubspec.yaml` | cả nhóm | Thêm gói thì ghi vào bảng phiên bản ở `README.md`; báo nhóm |

## 4. Git

- Nhánh: `feat/S03-thuc-don`, `fix/K02-crash`, tên theo mã màn hoặc task.
- Commit mở đầu bằng mã: `[S03] Thực đơn có chọn loại món`. Nhiều commit nhỏ qua nhiều ngày, không dồn một lần.
- Mở PR vào `main`, dùng mẫu PR có sẵn, **nhờ người khác duyệt**. Người duyệt chạy được app và đọc diff, không chỉ bấm Approve.
- Không đẩy thẳng lên `main`. Không commit khoá, mật khẩu, keystore, file `*adminsdk*.json`.
- Xung đột ở file chung: người merge sau là người sửa, và báo người kia.

## 5. Xong một màn khi

Chạy trong thư mục gốc (đều phải sạch):

```bash
flutter analyze
```

```bash
flutter test
```

Và tự kiểm bằng mắt trên máy ảo hoặc điện thoại:

- [ ] Giống Figma v2, hoặc sai lệch đã ghi ở `design-traceability.md` mục 5.
- [ ] Đủ loading, empty, error có nút thử lại; nút Back đi đúng chỗ.
- [ ] Vùng bấm ≥ 48 dp, chữ nội dung ≥ 14 sp, tương phản đạt (dùng token, không màu cứng).
- [ ] Mỗi nút và ô bấm có `Semantics` hoặc `tooltip` (ARTEMIS đọc cây trợ năng, T61).
- [ ] Không SDK trong widget, không logic trong `build()`.
- [ ] Chạy được bằng dữ liệu giả; khi đủ T33 thì chạy được bằng Firebase thật.
- [ ] Không dữ liệu cứng (tên món, giá, voucher) trong code màn hay ViewModel; dữ liệu đến từ service.
- [ ] Có test ViewModel và test widget; hàng trong `design-traceability.md` đã đổi thành `Xong`.

## 6. Dữ liệu giả và Firebase thật

Dữ liệu giả (`lib/dev/`) chỉ để dựng màn khi Firebase chưa nối và **phải xoá trước khi nộp** (T83), vì handout cấm dữ liệu cứng hay mock trong bản nộp. Đừng viết logic nghiệp vụ trong `lib/dev/`; logic nằm ở ViewModel để chạy giống hệt với dữ liệu thật.

Thực đơn mẫu, kiosk, voucher, slot đã nạp sẵn trên Firestore thật (`firebase/seed/`). Muốn có tài khoản người bán thử: đăng nhập app một lần rồi nhờ P3 chạy `set-role.mjs` gán vai trò và kiosk.
