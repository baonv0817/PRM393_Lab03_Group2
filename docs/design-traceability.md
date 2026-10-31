# Design traceability: Lab 2 → Lab 3

A map from the Lab 2 design (Figma Page 03, the frames with the ` v2` suffix) to the routes, widgets and data sources of the Flutter app. Write it **before** building a feature; everyone updates their own rows when done and changes the status (Not started, In progress, Done, Verified).

Lab 2 documents: repo `PRM323-Lab2-Group2` (`05-P4-ui-design/`, `04-P3-ui-concept/01-DESIGN.md`, `06-P5-kiem-thu-ban-giao/03-flutter-handoff.md`).

Convention: states (loading, empty, error, selected variants) are not separate routes; they are state of the parent screen inside the ViewModel. Owners are P1 to P5 (see `ASSIGNMENTS.md`).

The Figma and the app UI are in Vietnamese, so each screen name is followed by its Vietnamese UI title in parentheses.

## 1. Customer app (S01–S30)

| Figma code | Screen | Route | Widget (screen) | ViewModel | Data source | Owner | Status |
|---|---|---|---|---|---|---|---|
| S01 | Onboarding | /onboarding | OnboardingScreen | AuthViewModel (onboardingDone) | — | P1 | Done |
| S02 | Home (Trang chủ) | /home | HomeScreen | HomeViewModel | Firestore menu_items, kiosks | P1 | Done |
| S02-LOADING | Home loading | (state of /home) | LoadingView | HomeViewModel | — | P1 | Done |
| S02-ADDED | Home, item added to cart | (state of /home) | AddedSnackbar | CartViewModel | Firestore carts/{uid} | P1 | Done |
| S03 | Menu (Thực đơn) | /menu | MenuScreen | MenuViewModel | Firestore menu_items | P1 | Not started |
| S03-ADDED | Menu, item added to cart | (state of /menu) | AddedSnackbar | CartViewModel | Firestore carts/{uid} | P1 | Not started |
| S04 | Item detail | /menu/:id | ItemDetailScreen | ItemDetailViewModel | Firestore menu_items/{id} | P1 | Not started |
| S05 | Cart (Giỏ hàng) | /cart | CartScreen | CartViewModel | Firestore carts/{uid} | P1 | Not started |
| S05-EMPTY | Empty cart | (state of /cart) | EmptyView | CartViewModel | — | P1 | Not started |
| S05-VOUCHER-ERR | Wrong voucher code | (state of /cart) | VoucherErrorField | CartViewModel | Firestore vouchers | P1 | Not started |
| S06 | Checkout (MoMo by default) | /checkout | CheckoutScreen | CheckoutViewModel | Firestore orders | P1 | Not started |
| S06-VNPAY | Checkout, VNPAY-QR selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Not started |
| S06-CARD | Checkout, student card / wallet selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Not started |
| S06-CASH | Checkout, cash selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Not started |
| S06-LOADING | Connecting to the gateway | (state of /checkout) | LoadingView | CheckoutViewModel | — | P1 | Not started |
| S06-LOADING-VNPAY | Connecting to VNPAY-QR | (state of /checkout) | LoadingView | CheckoutViewModel | — | P1 | Not started |
| S06-GATEWAY | Payment gateway (simulated) | /checkout/gateway | GatewayScreen | CheckoutViewModel | Firestore orders | P1 | Not started |
| S06-ERR | Payment error, cart kept | (state of /checkout) | ErrorView | CheckoutViewModel | — | P1 | Not started |
| S07 | Order tracking | /orders/:id | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} (realtime) | P1 | Not started |
| S07-CASH | Pay at the counter | (state of /orders/:id) | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} | P1 | Not started |
| S07-DIALOG | Confirm cancelling the order | (dialog) | ConfirmDialog | OrderTrackingViewModel | Firestore orders/{id} | P1 | Not started |
| S08 | Orders, history (Đơn hàng) | /orders | OrdersScreen | OrdersViewModel | Firestore orders (uid) | P1 | Not started |
| S08-EMPTY | No orders yet | (state of /orders) | EmptyView | OrdersViewModel | — | P1 | Not started |
| S09 | Edit order | /orders/:id/edit | EditOrderScreen | EditOrderViewModel | Firestore orders/{id} | P2 | Not started |
| S10 | Cancelled order | /orders/:id/cancelled | OrderCancelledScreen | OrderTrackingViewModel | Firestore orders/{id} | P2 | Not started |
| S11 | History by week and month | /orders/history | HistoryScreen | HistoryViewModel | Firestore orders (uid) | P2 | Not started |
| S12 | Order detail | /orders/:id/detail | OrderDetailScreen | OrderDetailViewModel | Firestore orders/{id} | P2 | Not started |
| S13 | Favorite items | /favorites | FavoritesScreen | FavoritesViewModel | Firestore users/{uid}/favorites | P5 | Not started |
| S14 | Quick reorder | (bottom sheet) | ReorderSheet | ReorderViewModel | Firestore orders (uid) | P5 | Not started |
| S15 | Profile (Cá nhân) | /profile | ProfileScreen | ProfileViewModel | Firestore users/{uid} | P3 | Not started |
| S16 | Student profile | /profile/info | StudentInfoScreen | ProfileViewModel | Firestore users/{uid} | P3 | Not started |
| S17 | Payment methods | /profile/payment | PaymentSettingsScreen | PaymentSettingsViewModel | Firestore users/{uid} | P3 | Not started |
| S18 | Notification settings | /profile/notifications | NotificationSettingsScreen | NotificationSettingsViewModel | Firestore users/{uid}, FCM | P5 | Not started |
| S19 | Notifications | /notifications | NotificationCenterScreen | NotificationCenterViewModel | Firestore users/{uid}/notifications, FCM | P5 | Not started |
| S20 | Pickup (QR code) | /orders/:id/pickup | PickupQrScreen | PickupViewModel | Firestore orders/{id} | P2 | Not started |
| S21 | Home when the counter is closed | (state of /home) | ClosedBanner | HomeViewModel | Firestore kiosks/{id} | P1 | Not started |
| S22 | Item sold out, suggested alternatives | /menu/:id/alternatives | AlternativesScreen | AlternativesViewModel | Firestore menu_items | P1 | Not started |
| S23 | Review an item | /orders/:id/review | ReviewScreen | ReviewViewModel | Firestore reviews | P2 | Not started |
| S24 | Report an incident | /orders/:id/incident | IncidentScreen | IncidentViewModel | Firestore incidents | P2 | Not started |
| S25 | Pick a time slot | /cart/pickup-time | PickupTimeScreen | PickupTimeViewModel | Firestore kiosks/{id} | P1 | Not started |
| S26 | Sign-in (Google instead of email OTP) | /sign-in | SignInScreen | AuthViewModel | Firebase Auth | P3 | Not started |
| S26-OTP | Enter the verification code (dropped, see deviation D01) | — | — | — | — | P3 | Not started |
| S27 | Choose a kiosk (Q9 floor 2, floor 4, Student Cultural House) | /kiosks | KioskPickerScreen | KioskViewModel | Firestore kiosks | P3 | Not started |
| S28 | Search results | /search | SearchScreen | SearchViewModel | Firestore menu_items | P5 | Not started |
| S28-EMPTY | No results | (state of /search) | EmptyView | SearchViewModel | — | P5 | Not started |
| S29 | Choose a voucher | /cart/vouchers | VoucherPickerScreen | VoucherViewModel | Firestore vouchers | P1 | Not started |
| S30 | Offline | (app-wide state) | OfflineView | ConnectivityViewModel | connectivity_plus | P5 | Not started |

## 2. Seller app (K01–K15)

K07 does not exist in the design.

| Figma code | Screen | Route | Widget (screen) | ViewModel | Data source | Owner | Status |
|---|---|---|---|---|---|---|---|
| K01 | Staff sign-in | /seller/sign-in | SellerGateScreen | AuthViewModel | Firebase Auth, users/{uid}.role | P4 | Not started |
| K02 | Order list | /seller/orders | SellerOrdersScreen | SellerOrdersViewModel | Firestore orders (realtime) | P4 | Not started |
| K02-EMPTY | No new orders | (state of /seller/orders) | EmptyView | SellerOrdersViewModel | — | P4 | Not started |
| K03 | Order detail | /seller/orders/:id | SellerOrderDetailScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Not started |
| K04 | Preparing | /seller/orders/:id/preparing | PreparingScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Not started |
| K05 | Scan the pickup code | /seller/scan | ScanScreen | ScanViewModel | Firestore orders, camera | P4 | Not started |
| K05-ERR | Invalid code | (state of /seller/scan) | ErrorView | ScanViewModel | — | P4 | Not started |
| K06 | Confirm handover | /seller/orders/:id/deliver | DeliverScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Not started |
| K06-CASH | Handover, collect cash | (state of deliver) | DeliverScreen | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Not started |
| K08 | Menu management | /seller/menu | SellerMenuScreen | SellerMenuViewModel | Firestore menu_items | P2 | Not started |
| K09 | Mark item sold out | (dialog) | SoldOutDialog | SellerMenuViewModel | Firestore menu_items/{id} | P2 | Not started |
| K10 | Shop | /seller/shop | ShopScreen | ShopViewModel | Firestore kiosks/{id} | P2 | Not started |
| K11 | Shift statistics | /seller/stats | ShiftStatsScreen | ShiftStatsViewModel | Firestore orders (aggregation) | P2 | Not started |
| K12 | Reject order | (dialog) | RejectDialog | SellerOrderDetailViewModel | Firestore orders/{id} | P4 | Not started |
| K13 | Incidents from customers | /seller/incidents | IncidentsScreen | IncidentsViewModel | Firestore incidents | P4 | Not started |
| K14 | Add a new item | /seller/menu/new | MenuItemFormScreen | MenuItemFormViewModel | Firestore menu_items | P2 | Not started |
| K14-ERR | Item information missing | (state of the form) | FormErrorField | MenuItemFormViewModel | — | P2 | Not started |
| K15 | Edit an item | /seller/menu/:id/edit | MenuItemFormScreen | MenuItemFormViewModel | Firestore menu_items/{id} | P2 | Not started |

## 3. Flows

| Flow | Entry point | Screens passed | Error / recovery branch | Test case |
|---|---|---|---|---|
| F1 Quick order from Home | S02 | S02-ADDED → S05 → S06 → S06-GATEWAY → S07 | Declined at the gateway → S06-ERR | TC-03 |
| F2 Customize an item and use a voucher | S03 | S04 → S05 → S29 | Expired code → S05-VOUCHER-ERR | TC-04 |
| F3 Payment error, keep the cart | S06-ERR | S07-CASH → S07-DIALOG → S10 | Cash at the kiosk | TC-05 |
| Seller: from accepting an order to handover | K01 | K02 → K03 → K04 → K05 → K06 | Invalid code → K05-ERR → K06-CASH | TC-12 |

## 4. Lab 2 components → widgets (`lib/widgets/`)

| Lab 2 component | Flutter widget | Variants, state (parameters) | Built by |
|---|---|---|---|
| Button/Primary, Secondary, Text | `AppButton` | `variant`, `loading`, `enabled` | P1 |
| IconButton 48×48 | `AppIconButton` | `semanticLabel` | P1 |
| Chip | `AppChip` | `selected` | P1 |
| NavBar (4 tabs) | `AppNavBar` | `tabs`, `selectedIndex` (customer and seller) | P1 |
| Card/Food | `FoodCard` | `type`, `soldOut` | P1 |
| TextField | `AppTextField` | `error`, `helper` | P1 |
| AppBar | `AppTopBar` | `title`, `onBack` | P1 |
| Dialog | `AppDialog` | `destructive` | P1 |
| Loading, Empty, Error | `LoadingView`, `EmptyView`, `ErrorView` | `message`, `onRetry` | P1 |
| Snackbar "added to cart" | `AddedSnackbar` | `onViewCart` | P1 |

## 5. Deviations from the design

Every place that differs from Figma is recorded here with the reason, and **Figma must be updated** (the person making the note, in the last column). A deviation that is not recorded is graded as an error.

| ID | Lab 2 design | Lab 3 app | Reason | Figma updated |
|---|---|---|---|---|
| D01 | S26 sign-in with school email + OTP (S26-OTP) | Google Sign-In, the OTP screen is dropped | The Lab 3 handout requires Google Sign-In | Not yet |
| D02 | S06-GATEWAY is a simulated third-party gateway screen | Keep the simulated screen, do not call a real gateway | There is no payment-gateway account; clearly labeled as simulated | Not needed |
| D03 | Sign-in is optional (S01 opens straight to Home) | A signed-out user only sees the sign-in screen (S26); after sign-in they reach Home | Lab 3 handout: a signed-out user must not reach the app's screens | Not yet |
| D04 | The customer app and the seller app are two separate areas, Figma does not say how one is chosen | An account with the staff or admin role goes to the seller app; a customer cannot open `/seller/*` | Lab 3 handout, architecture section and role-based rules | Not yet |
| D05 | S01 has a link "Đăng nhập bằng email @fpt.edu.vn"; "Bắt đầu đặt món" and "Bỏ qua" open Home directly | The link reads "Đăng nhập bằng Google"; all three buttons go to the sign-in screen S26 (S01 only shows to signed-out users, each time the app opens). The location line, the sub-text and the three-benefit card were removed, and the logo and the BreakBite name were added | A consequence of D01 and D03; fewer meaningless texts | Not yet |
| D06 | S02 has category chips (Tất cả, Tacos, Mì trộn…), a banner with an "Đặt ngay" button and a price-tag icon, and a "Đặt lại đơn gần đây" row that is always shown | Chips removed (filtering items belongs to the Menu tab S03; chips on Home only filter a short list and confuse); the banner is compact and the whole block is tappable; "Reorder" only shows once there is an order and states the items and total; item cards use real photos instead of icons; the title is "Món nhanh · tối đa 5 phút" (a 5-minute item still counts as quick) | Less visual clutter, no redundant parts, everything on screen is backed by real data | Not yet |
| | | | | |

Add a row whenever you find a new deviation.
