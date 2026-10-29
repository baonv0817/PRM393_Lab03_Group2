# firebase/

| File | Vai trò |
|---|---|
| `storage.rules` | `reports/{uid}` (PDF ≤ 5 MB), `incidents/{uid}` (ảnh sự cố), `menu/{kioskId}` (ảnh món, chỉ nhân viên kiosk đó ghi) |
| `firestore.rules` | Theo vai trò (user, staff, admin) và theo kiosk của nhân viên; mô hình dữ liệu ở `docs/data-model.md` |
| `firestore.indexes.json` | Chỉ mục tổng hợp cho các truy vấn ở `docs/data-model.md` mục 5 |
| `remote-config-template.json` | Mẫu để đẩy Remote Config lên (`firebase deploy --only remoteconfig`) |
| `remote-config-defaults.json` | Giá trị mặc định trong app; đổi trên console là đổi hành vi, không cần build lại |

Tham số Remote Config và nơi dùng:

| Tham số | Tác dụng trên màn hình |
|---|---|
| `quick_items_limit` | Số món hiển thị ở mục "Món nhanh dưới 5 phút" (S02) |
| `promo_banner_enabled` | Hiện hoặc ẩn banner Combo Giờ Vàng (S02) |
| `pickup_slot_enabled` | Hiện hoặc ẩn dòng chọn giờ nhận ở giỏ hàng (S05, S25) |

Triển khai: `firebase deploy --only firestore:rules,firestore:indexes,remoteconfig` (cần Firebase CLI và đăng nhập). Thêm `storage` sau khi Storage được bật (cần gói Blaze).

## Test rules (Emulator)

`firebase/tests/rules.test.mjs` có ca được phép và bị từ chối cho từng vai trò (user, staff, admin) và từng collection, cộng quy tắc Storage (chủ thư mục, PDF, ảnh, ≤ 5 MB, nhân viên theo kiosk).

**Kết quả chạy ngày 29/10/2026 trên Emulator: 82 test, 82 đạt, 0 lỗi.** Dòng `Unexpected rules runtime error ... NullPointerException` in ra lúc tắt Emulator là vô hại.

```bash
cd firebase/tests
npm install
npm test        # cần Java 21; Firestore Emulator tải khoảng 140 MB lần đầu
```

### Lỗi "Unable to establish loopback connection" trên Windows

Nếu Emulator thoát với mã 1 và `firestore-debug.log` hoặc log Java ghi `Unable to establish loopback connection`, Java không tạo được socket nội bộ ở thư mục tạm mặc định. Cách sửa (đã áp dụng cho máy dựng):

```powershell
mkdir D:\tmp\java
setx JAVA_TOOL_OPTIONS "-Djava.io.tmpdir=D:/tmp/java -Djdk.net.unixdomain.tmpdir=D:/tmp/java"
```

Mở lại terminal rồi chạy lại. Biến này cũng cần cho `sdkmanager` và Gradle trên máy bị lỗi tương tự.

## Dữ liệu mẫu và vai trò (`firebase/seed/`)

Cài một lần: `cd firebase/seed && npm install`.

| Việc | Lệnh |
|---|---|
| Thử trên Emulator (tự dựng, nạp, kiểm tra, tắt) | `npm run seed:emulator` |
| Nạp vào project thật | `node seed.mjs --project=breakbite-1315b --yes` |
| Nạp lại sạch (xoá kiosks và slots, menu_items, vouchers rồi nạp lại; không đụng users, orders) | `node seed.mjs --project=breakbite-1315b --yes --reset` |
| Gán vai trò | `node set-role.mjs <email> <user\|staff\|admin> [kioskId] --project=breakbite-1315b --yes` |

Script dùng Admin SDK (bỏ qua Security Rules) nên project thật cần **khoá service account**: console, Project settings, Service accounts, Generate new private key. Lưu file **ngoài repo** (ví dụ `D:\secretsreakbite-admin.json`; `.gitignore` đã chặn `*firebase-adminsdk*.json`), rồi trong PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "D:\secretsreakbite-admin.json"
cd firebase\seed
node seed.mjs --project=breakbite-1315b --yes
node set-role.mjs email-nhan-vien@gmail.com staff q9-t2 --project=breakbite-1315b --yes
```

Không gửi nội dung file khoá cho ai, kể cả trong chat. `set-role.mjs` chỉ gán được cho tài khoản đã đăng nhập app ít nhất một lần.
