# Design traceability: Lab 2 → Lab 3

Bản đồ từ thiết kế Lab 2 (Figma Page 03, các khung có hậu tố ` v2`) sang route, widget và nguồn dữ liệu của app Flutter. Viết **trước** khi làm tính năng; mỗi người cập nhật hàng của mình khi làm xong và đổi trạng thái (Chưa làm, Đang làm, Xong, Đã kiểm chứng).

Tài liệu Lab 2: repo `PRM323-Lab2-Group2` (`05-P4-ui-design/`, `04-P3-ui-concept/01-DESIGN.md`, `06-P5-kiem-thu-ban-giao/03-flutter-handoff.md`).

Quy ước: trạng thái (loading, empty, error, biến thể chọn) không phải route riêng mà là state của màn cha trong ViewModel.

## 1. App khách (S01–S30)

| Mã Figma | Màn hình | Route | Widget (màn) | ViewModel | Nguồn dữ liệu | Phụ trách | Trạng thái |
|---|---|---|---|---|---|---|---|
| S01 | Onboarding | /onboarding | OnboardingScreen | OnboardingViewModel | Remote Config | P1 | Chưa làm |
| S02 | Trang chủ | /home | HomeScreen | HomeViewModel | Firestore menu_items, kiosks | P1 | Chưa làm |
| S02-LOADING | Đang tải Trang chủ | (state của /home) | LoadingView | HomeViewModel | — | P1 | Chưa làm |
| S02-ADDED | Trang chủ, đã thêm vào giỏ | (state của /home) | AddedSnackbar | CartViewModel | Firestore carts/{uid} | P1 | Chưa làm |
| S03 | Thực đơn | /menu | MenuScreen | MenuViewModel | Firestore menu_items | P1 | Chưa làm |
| S03-ADDED | Thực đơn, đã thêm vào giỏ | (state của /menu) | AddedSnackbar | CartViewModel | Firestore carts/{uid} | P1 | Chưa làm |
| S04 | Chi tiết món | /menu/:id | ItemDetailScreen | ItemDetailViewModel | Firestore menu_items/{id} | P1 | Chưa làm |
| S05 | Giỏ hàng | /cart | CartScreen | CartViewModel | Firestore carts/{uid} | P1 | Chưa làm |
| S05-EMPTY | Giỏ hàng trống | (state của /cart) | EmptyView | CartViewModel | — | P1 | Chưa làm |
| S05-VOUCHER-ERR | Mã giảm giá sai | (state của /cart) | VoucherErrorField | CartViewModel | Firestore vouchers | P1 | Chưa làm |
| S06 | Thanh toán (MoMo mặc định) | /checkout | CheckoutScreen | CheckoutViewModel | Firestore orders | P1 | Chưa làm |
| S06-VNPAY | Thanh toán, chọn VNPAY-QR | (state của /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Chưa làm |
| S06-CARD | Thanh toán, chọn Thẻ SV / Ví | (state của /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Chưa làm |
| S06-CASH | Thanh toán, chọn Tiền mặt | (state của /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Chưa làm |
| S06-LOADING | Đang kết nối cổng | (state của /checkout) | LoadingView | CheckoutViewModel | — | P1 | Chưa làm |
| S06-LOADING-VNPAY | Đang kết nối VNPAY-QR | (state của /checkout) | LoadingView | CheckoutViewModel | — | P1 | Chưa làm |
| S06-GATEWAY | Cổng thanh toán (mô phỏng) | /checkout/gateway | GatewayScreen | CheckoutViewModel | Firestore orders | P1 | Chưa làm |
| S06-ERR | Lỗi thanh toán, giữ giỏ hàng | (state của /checkout) | ErrorView | CheckoutViewModel | — | P1 | Chưa làm |
| S07 | Theo dõi đơn | /orders/:id | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} (realtime) | P1 | Chưa làm |
| S07-CASH | Trả tại quầy | (state của /orders/:id) | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} | P1 | Chưa làm |
| S07-DIALOG | Xác nhận huỷ đơn | (dialog) | ConfirmDialog | OrderTrackingViewModel | Firestore orders/{id} | P1 | Chưa làm |
| S08 | Đơn hàng, lịch sử | /orders | OrdersScreen | OrdersViewModel | Firestore orders (uid) | P1 | Chưa làm |
| S08-EMPTY | Chưa có đơn | (state của /orders) | EmptyView | OrdersViewModel | — | P1 | Chưa làm |
| S09 | Sửa đơn | /orders/:id/edit | EditOrderScreen | EditOrderViewModel | Firestore orders/{id} | P2 | Chưa làm |
| S10 | Đơn đã huỷ | /orders/:id/cancelled | OrderCancelledScreen | OrderTrackingViewModel | Firestore orders/{id} | P2 | Chưa làm |
| S11 | Lịch sử theo tuần, tháng | /orders/history | HistoryScreen | HistoryViewModel | Firestore orders (uid) | P2 | Chưa làm |
| S12 | Chi tiết đơn | /orders/:id/detail | OrderDetailScreen | OrderDetailViewModel | Firestore orders/{id} | P2 | Chưa làm |
| S13 | Món yêu thích | /favorites | FavoritesScreen | FavoritesViewModel | Firestore users/{uid}/favorites | P2 | Chưa làm |
| S14 | Đặt lại nhanh | (bottom sheet) | ReorderSheet | ReorderViewModel | Firestore orders (uid) | P2 | Chưa làm |
| S15 | Cá nhân | /profile | ProfileScreen | ProfileViewModel | Firestore users/{uid} | P3 | Chưa làm |
| S16 | Hồ sơ sinh viên | /profile/info | StudentInfoScreen | ProfileViewModel | Firestore users/{uid} | P3 | Chưa làm |
| S17 | Phương thức thanh toán | /profile/payment | PaymentSettingsScreen | PaymentSettingsViewModel | Firestore users/{uid} | P3 | Chưa làm |
| S18 | Cài đặt thông báo | /profile/notifications | NotificationSettingsScreen | NotificationSettingsViewModel | Firestore users/{uid}, FCM | P3 | Chưa làm |
| S19 | Thông báo | /notifications | NotificationCenterScreen | NotificationCenterViewModel | Firestore users/{uid}/notifications, FCM | P2 | Chưa làm |
| S20 | Nhận món (mã QR) | /orders/:id/pickup | PickupQrScreen | PickupViewModel | Firestore orders/{id} | P2 | Chưa làm |
| S21 | Trang chủ khi quán đóng | (state của /home) | ClosedBanner | HomeViewModel | Firestore kiosks/{id} | P2 | Chưa làm |
| S22 | Món hết, gợi ý thay thế | /menu/:id/alternatives | AlternativesScreen | AlternativesViewModel | Firestore menu_items | P2 | Chưa làm |
| S23 | Đánh giá món | /orders/:id/review | ReviewScreen | ReviewViewModel | Firestore reviews | P2 | Chưa làm |
| S24 | Báo sự cố | /orders/:id/incident | IncidentScreen | IncidentViewModel | Firestore incidents | P2 | Chưa làm |
| S25 | Hẹn giờ theo slot | /cart/pickup-time | PickupTimeScreen | PickupTimeViewModel | Firestore kiosks/{id} | P2 | Chưa làm |
| S26 | Đăng nhập (Google thay cho email OTP) | /sign-in | SignInScreen | AuthViewModel | Firebase Auth | P3 | Chưa làm |
| S26-OTP | Nhập mã xác nhận (bỏ, xem sai lệch D01) | — | — | — | — | P3 | Chưa làm |
| S27 | Chọn kiosk (Q9 tầng 2, tầng 4, Nhà văn hóa SV) | /kiosks | KioskPickerScreen | KioskViewModel | Firestore kiosks | P2 | Chưa làm |
| S28 | Kết quả tìm kiếm | /search | SearchScreen | SearchViewModel | Firestore menu_items | P2 | Chưa làm |
| S28-EMPTY | Không có kết quả | (state của /search) | EmptyView | SearchViewModel | — | P2 | Chưa làm |
| S29 | Chọn mã giảm giá | /cart/vouchers | VoucherPickerScreen | VoucherViewModel | Firestore vouchers | P2 | Chưa làm |
| S30 | Mất kết nối | (state toàn app) | OfflineView | ConnectivityViewModel | connectivity_plus | P2 | Chưa làm |

## 2. App người bán (K01–K15)

K07 không tồn tại trong thiết kế.

| Mã Figma | Màn hình | Route | Widget (màn) | ViewModel | Nguồn dữ liệu | Phụ trách | Trạng thái |
|---|---|---|---|---|---|---|---|
| K01 | Đăng nhập nhân viên | /seller/sign-in | SellerGateScreen | AuthViewModel | Firebase Auth, users/{uid}.role | P3 | Chưa làm |
| K02 | Danh sách đơn | /seller/orders | SellerOrdersScreen | SellerOrdersViewModel | Firestore orders (realtime) | P3 | Chưa làm |
| K02-EMPTY | Chưa có đơn mới | (state của /seller/orders) | EmptyView | SellerOrdersViewModel | — | P3 | Chưa làm |
| K03 | Chi tiết đơn | /seller/orders/:id | SellerOrderDetailScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P3 | Chưa làm |
| K04 | Đang chuẩn bị | /seller/orders/:id/preparing | PreparingScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P3 | Chưa làm |
| K05 | Quét mã nhận món | /seller/scan | ScanScreen | ScanViewModel | Firestore orders, camera | P3 | Chưa làm |
| K05-ERR | Mã không hợp lệ | (state của /seller/scan) | ErrorView | ScanViewModel | — | P3 | Chưa làm |
| K06 | Xác nhận giao món | /seller/orders/:id/deliver | DeliverScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P3 | Chưa làm |
| K06-CASH | Giao món, thu tiền mặt | (state của deliver) | DeliverScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P3 | Chưa làm |
| K08 | Quản lý món | /seller/menu | SellerMenuScreen | SellerMenuViewModel | Firestore menu_items | P4 | Chưa làm |
| K09 | Đánh dấu hết món | (dialog) | SoldOutDialog | SellerMenuViewModel | Firestore menu_items/{id} | P4 | Chưa làm |
| K10 | Quán | /seller/shop | ShopScreen | ShopViewModel | Firestore kiosks/{id} | P4 | Chưa làm |
| K11 | Thống kê ca | /seller/stats | ShiftStatsScreen | ShiftStatsViewModel | Firestore orders (aggregation) | P4 | Chưa làm |
| K12 | Từ chối đơn | (dialog) | RejectDialog | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Chưa làm |
| K13 | Sự cố từ khách | /seller/incidents | IncidentsScreen | IncidentsViewModel | Firestore incidents | P4 | Chưa làm |
| K14 | Thêm món mới | /seller/menu/new | MenuItemFormScreen | MenuItemFormViewModel | Firestore menu_items | P4 | Chưa làm |
| K14-ERR | Thiếu thông tin món | (state của form) | FormErrorField | MenuItemFormViewModel | — | P4 | Chưa làm |
| K15 | Sửa món | /seller/menu/:id/edit | MenuItemFormScreen | MenuItemFormViewModel | Firestore menu_items/{id} | P4 | Chưa làm |

## 3. Flow

| Flow | Điểm vào | Màn đi qua | Nhánh lỗi / phục hồi | Test case |
|---|---|---|---|---|
| F1 Đặt nhanh từ Trang chủ | S02 | S02-ADDED → S05 → S06 → S06-GATEWAY → S07 | Từ chối ở cổng → S06-ERR | TC-03 |
| F2 Tuỳ chỉnh món và mã giảm giá | S03 | S04 → S05 → S29 | Mã hết hạn → S05-VOUCHER-ERR | TC-04 |
| F3 Lỗi thanh toán, giữ giỏ | S06-ERR | S07-CASH → S07-DIALOG → S10 | Tiền mặt tại Kiosk | TC-05 |
| Người bán: nhận đơn tới giao món | K01 | K02 → K03 → K04 → K05 → K06 | Mã không hợp lệ → K05-ERR → K06-CASH | TC-12 |

## 4. Component Lab 2 → widget (`lib/widgets/`)

| Component Lab 2 | Widget Flutter | Variant, state (tham số) | Người làm |
|---|---|---|---|
| Button/Primary, Secondary, Text | `AppButton` | `variant`, `loading`, `enabled` | P1 |
| IconButton 48×48 | `AppIconButton` | `semanticLabel` | P1 |
| Chip | `AppChip` | `selected` | P1 |
| NavBar (4 tab) | `AppNavBar` | `tabs`, `selectedIndex` (khách và người bán) | P1 |
| Card/Food | `FoodCard` | `type`, `soldOut` | P1 |
| TextField | `AppTextField` | `error`, `helper` | P1 |
| AppBar | `AppTopBar` | `title`, `onBack` | P1 |
| Dialog | `AppDialog` | `destructive` | P1 |
| Loading, Empty, Error | `LoadingView`, `EmptyView`, `ErrorView` | `message`, `onRetry` | P1 |
| Snackbar thêm vào giỏ | `AddedSnackbar` | `onViewCart` | P1 |

## 5. Sai lệch so với thiết kế

Mọi chỗ khác Figma ghi ở đây kèm lý do và **cập nhật lại Figma** (người ghi chú trong cột cuối). Sai lệch không ghi bị chấm là lỗi.

| ID | Thiết kế Lab 2 | App Lab 3 | Lý do | Figma đã cập nhật |
|---|---|---|---|---|
| D01 | S26 đăng nhập email trường + OTP (S26-OTP) | Google Sign-In, bỏ màn OTP | Handout Lab 3 yêu cầu Google Sign-In | Chưa |
| D02 | S06-GATEWAY là màn mô phỏng cổng bên thứ ba | Giữ màn mô phỏng, không gọi cổng thật | Không có tài khoản cổng thanh toán; ghi rõ là mô phỏng | Không cần |
| D03 | Đăng nhập không bắt buộc (S01 mở thẳng Trang chủ) | Chưa đăng nhập thì chỉ thấy màn đăng nhập (S26); sau đăng nhập vào Trang chủ | Handout Lab 3: người chưa đăng nhập không được vào màn của app | Chưa |
| D04 | App khách và app người bán là hai khu riêng, Figma không nêu cách chọn | Tài khoản có vai trò staff hoặc admin vào app người bán; khách không mở được `/seller/*` | Handout Lab 3 mục kiến trúc và rules theo vai trò | Chưa |
| | | | | |

Thêm dòng khi gặp sai lệch mới.
