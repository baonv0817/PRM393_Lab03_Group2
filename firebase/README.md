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

```bash
cd firebase/tests
npm install
npm test        # cần Java 21; Firestore Emulator tải khoảng 140 MB lần đầu
```

Lưu ý: trên máy dựng khung, Firestore Emulator báo `Unable to establish loopback connection` (lỗi mạng loopback của Java trên máy đó), nên bộ test **chưa được chạy**. Chạy trên máy khác hoặc sửa lỗi loopback rồi ghi kết quả vào `docs/` khi có.
