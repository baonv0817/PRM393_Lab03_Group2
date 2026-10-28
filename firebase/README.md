# firebase/

| File | Vai trò |
|---|---|
| `storage.rules` | Mỗi người dùng chỉ đọc và ghi `reports/{uid}/…` (PDF ≤ 5 MB) |
| `firestore.rules` | Bản nháp theo vai trò (user, staff, admin); phải kiểm trong Emulator |
| `remote-config-defaults.json` | Giá trị mặc định trong app; đổi trên console là đổi hành vi, không cần build lại |

Tham số Remote Config và nơi dùng:

| Tham số | Tác dụng trên màn hình |
|---|---|
| `quick_items_limit` | Số món hiển thị ở mục "Món nhanh dưới 5 phút" (S02) |
| `promo_banner_enabled` | Hiện hoặc ẩn banner Combo Giờ Vàng (S02) |
| `pickup_slot_enabled` | Hiện hoặc ẩn dòng chọn giờ nhận ở giỏ hàng (S05, S25) |

Triển khai rules: `firebase deploy --only firestore:rules,storage` (cần Firebase CLI và đăng nhập).

## Test rules (Emulator)

`firebase/tests/rules.test.mjs` có ca được phép và bị từ chối cho từng vai trò (user, staff, admin) và từng collection, cộng quy tắc Storage (chủ thư mục, PDF, ≤ 5 MB).

**Kết quả chạy ngày 28/10/2026 trên Emulator: 37 test, 37 đạt, 0 lỗi.** Dòng `Unexpected rules runtime error ... NullPointerException` in ra lúc tắt Emulator là vô hại.

```bash
cd firebase/tests
npm install
npm test        # cần Java 21; Firestore Emulator tải khoảng 140 MB lần đầu
```

### Lỗi "Unable to establish loopback connection" trên Windows

Nếu Emulator thoát với mã 1 và `firestore-debug.log` hoặc log Java ghi `Unable to establish loopback connection`, Java không tạo được socket nội bộ ở thư mục tạm mặc định. Cách sửa (đã áp dụng cho máy dựng):

```powershell
mkdir D:	mp\java
setx JAVA_TOOL_OPTIONS "-Djava.io.tmpdir=D:/tmp/java -Djdk.net.unixdomain.tmpdir=D:/tmp/java"
```

Mở lại terminal rồi chạy lại. Biến này cũng cần cho `sdkmanager` và Gradle trên máy bị lỗi tương tự.
