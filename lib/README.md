# lib/

Khung thư mục theo MVVM (xem `docs/architecture.md`). Phụ thuộc chỉ đi xuống: `screens → widgets, viewmodels → services → firebase, models`.

| Thư mục | Chứa gì |
|---|---|
| `models/` | Lớp dữ liệu thuần (MenuItem, Order, Kiosk, Voucher…) |
| `services/` | Interface và bản cài đặt cho mọi lời gọi ra ngoài (Auth, Firestore, Storage, FCM, Analytics, Crashlytics, Remote Config) |
| `firebase/` | Khởi tạo Firebase, `firebase_options.dart` |
| `viewmodels/` | Trạng thái màn hình và logic nghiệp vụ |
| `screens/` | Màn hình (không gọi SDK, không logic trong `build()`) |
| `widgets/` | Component Lab 2 dùng lại |
| `theme/` | Token thành `ThemeData` |
| `utils/` | Hàm tiện ích không phụ thuộc UI |
