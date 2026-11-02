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
| S02-LOADING | Home loading | (state of /home) | Skeleton of the header, search, banner and 3 item cards (`SkeletonList`) | HomeViewModel | — | P1 | Done |
| S02-ADDED | Home, item added to cart | (state of /home) | Fly-to-cart animation, quantity stepper on the card, floating cart button | HomeViewModel | Firestore carts/{uid} | P1 | Done |
| S03 | Menu (Thực đơn) | /menu | MenuScreen | MenuViewModel | Firestore menu_items, kiosks, carts/{uid} | P1 | Done |
| S03-ADDED | Menu, item added to cart | (state of /menu) | Fly-to-cart animation, quantity stepper on the card, floating cart button (as S02-ADDED, D12); adding from S04 shows the "Xem giỏ" snackbar | MenuViewModel | Firestore carts/{uid} | P1 | Done |
| S04 | Item detail | /menu/:id | ItemDetailScreen | ItemDetailViewModel | Firestore menu_items/{id}, carts/{uid} | P1 | Done |
| S05 | Cart (Giỏ hàng) | /cart | CartScreen | CartViewModel | Firestore carts/{uid} | P1 | Done |
| S05-EMPTY | Empty cart | (state of /cart) | EmptyView | CartViewModel | — | P1 | Done |
| S05-VOUCHER-ERR | Wrong voucher code | (state of /cart) | Voucher row with the reason and "Bỏ mã" | CartViewModel | Firestore vouchers | P1 | Done |
| S06 | Checkout (MoMo by default) | /checkout | CheckoutScreen | CheckoutViewModel | Firestore orders | P1 | Done |
| S06-VNPAY | Checkout, VNPAY-QR selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Done |
| S06-CARD | Checkout, student card / wallet selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Done |
| S06-CASH | Checkout, cash selected | (state of /checkout) | PaymentMethodTile | CheckoutViewModel | — | P1 | Done |
| S06-LOADING | Connecting to the gateway | (state of /checkout) | Loading confirm button | CheckoutViewModel | — | P1 | Done |
| S06-LOADING-VNPAY | Connecting to VNPAY-QR | (state of /checkout) | Loading confirm button | CheckoutViewModel | — | P1 | Done |
| S06-GATEWAY | Payment gateway (simulated) | /checkout/gateway | GatewayScreen | CheckoutViewModel | Firestore orders | P1 | Done |
| S06-ERR | Payment error, cart kept | (state of /checkout) | Failure card, other methods | CheckoutViewModel | — | P1 | Done |
| S07 | Order tracking | /orders/:id | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} (realtime) | P1 | Done |
| S07-CASH | Pay at the counter | (state of /orders/:id) | OrderTrackingScreen | OrderTrackingViewModel | Firestore orders/{id} | P1 | Done |
| S07-DIALOG | Confirm cancelling the order | (dialog) | showAppDialog | OrderTrackingViewModel | Firestore orders/{id} | P1 | Done |
| S08 | Orders, history (Đơn hàng) | /orders | OrdersScreen | OrdersViewModel | Firestore orders (uid) | P1 | Done |
| S08-EMPTY | No orders yet | (state of /orders) | EmptyView with "Xem thực đơn" | OrdersViewModel | — | P1 | Done |
| S09 | Edit order | /orders/:id/edit | EditOrderScreen | EditOrderViewModel | Firestore orders/{id} | P2 | Not started |
| S10 | Cancelled order | /orders/:id/cancelled | OrderCancelledScreen | OrderCancelledViewModel | Firestore orders/{id} (realtime), carts/{uid} (reorder) | P2 | Done |
| S11 | History by week and month | /orders/history | HistoryScreen | HistoryViewModel | Firestore orders (uid) | P2 | Not started |
| S12 | Order detail | /orders/:id/detail | OrderDetailScreen | OrderDetailViewModel | Firestore orders/{id} (realtime), reports (receipts of this order), carts/{uid} (reorder), file storage (receipt upload) | P2 | Done (S23 and S24 links come with those screens) |
| S13 | Favorite items | /favorites | FavoritesScreen | FavoritesViewModel | Firestore users/{uid}/favorites | P5 | Not started |
| S14 | Quick reorder | (bottom sheet) | ReorderSheet | ReorderViewModel | Firestore orders (uid) | P5 | Not started |
| S15 | Profile (Cá nhân) | /profile | ProfileScreen | ProfileViewModel, AuthViewModel | Firebase Auth, Firestore orders (count) | P3 | Done |
| S16 | Student profile | /profile/info | StudentInfoScreen | StudentInfoViewModel | Firestore users/{uid}, kiosks | P3 | Done |
| S17 | Payment methods | /profile/payment | PaymentSettingsScreen | PaymentSettingsViewModel | Firestore users/{uid} | P3 | Done |
| S18 | Notification settings | /profile/notifications | NotificationSettingsScreen | NotificationSettingsViewModel | Firestore users/{uid}, FCM | P5 | Not started |
| S19 | Notifications | /notifications | NotificationCenterScreen | NotificationCenterViewModel | Firestore users/{uid}/notifications, FCM | P5 | Not started |
| S20 | Pickup (QR code) | /orders/:id/pickup | PickupQrScreen | PickupViewModel | Firestore orders/{id} | P2 | Not started |
| S21 | Home when the counter is closed | (state of /home) | ClosedBanner | HomeViewModel | Firestore kiosks/{id} | P1 | Not started |
| S22 | Item sold out, suggested alternatives | /menu/:id/alternatives | AlternativesScreen | AlternativesViewModel | Firestore menu_items | P1 | Not started |
| S23 | Review an item | /orders/:id/review | ReviewScreen | ReviewViewModel | Firestore reviews | P2 | Not started |
| S24 | Report an incident | /orders/:id/incident | IncidentScreen | IncidentViewModel | Firestore incidents | P2 | Not started |
| S25 | Pick a time slot | /cart/pickup-time | PickupTimeScreen | PickupTimeViewModel | Firestore kiosks/{id}/slots (`SlotRepository`), carts/{uid}; Remote Config `pickup_slot_enabled` | P1 | Done |
| S26 | Sign-in (Google instead of email OTP) | /sign-in | SignInScreen | AuthViewModel | Firebase Auth, users/{uid} | P3 | Done |
| S26-OTP | Enter the verification code (dropped, see deviation D01) | — | — | — | — | P3 | Dropped (D01) |
| S27 | Choose a kiosk (Q9 floor 2, floor 4, Student Cultural House) | /kiosks | KioskPickerScreen | KioskViewModel | Firestore kiosks, carts/{uid}; SessionRepository | P3 | Done |
| S28 | Search results | /search | SearchScreen | SearchViewModel | Firestore menu_items | P5 | Not started |
| S28-EMPTY | No results | (state of /search) | EmptyView | SearchViewModel | — | P5 | Not started |
| S29 | Choose a voucher | /cart/vouchers | VoucherPickerScreen | VoucherPickerViewModel | Firestore vouchers (`VoucherRepository`), carts/{uid} | P1 | Done |
| S30 | Offline | (app-wide state) | OfflineView | ConnectivityViewModel | connectivity_plus | P5 | Not started |
| DEMO | Firebase demo area (Khu demo Firebase), not in the Lab 2 design, see D08 | /profile/firebase-demo | FirebaseDemoScreen | FirebaseDemoViewModel | Remote Config, Crashlytics, Cloudinary, Firestore reports, link to S19 | P3 | Done |

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

## 4. Lab 2 components → widgets (`lib/ui/core/widgets/`)

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

Design tokens: the colors and sizes come from the **v2 frames** (Page 03), checked pixel by pixel on 2026-11-01: background `#FAF8F5`, card `#FFFFFF`, selected `#FFF1DE`, input fill `#F3F0EA`, border `#E4DFD8`, primary `#F69D39`, primary text `#622B14`, secondary text `#6B5F55`, link text `#B45309`, input border `#8A7A70`. The token board on Page 04 is older (background `#FFF5E5`, secondary text `#8A5D48`, Body Large 15 sp) and must be brought in line with the v2 frames (T83). Every text color pair is checked for WCAG AA contrast ≥ 4.5:1 in `test/ui/core/theme_test.dart`. Top bars use Headline 20 sp Bold with a 1 dp bottom border, as in the v2 frames.

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
| D07 | S15 ends with "Xoá dữ liệu trên máy này" and has 5 rows; S26 has a Back button and "Tiếp tục không cần tài khoản" | S15 ends with "Đăng xuất" behind a confirmation dialog and adds a sixth row "Khu demo Firebase"; S26 has no Back button and no way to continue without an account | Sign-out is required by the Lab 3 handout (it also clears the local data); the demo area must be reachable from Profile; a consequence of D01 and D03 | Not yet |
| D08 | No Firebase demo area | S15 has a sixth row "Khu demo Firebase" that opens a demo screen: link to the notification center, Remote Config values with where each came from, Crashlytics test error and test crash (behind a confirmation), PDF export and upload with progress, URL and the list of my files | The Lab 3 handout requires a Firebase demo area on the Profile screen; built only from existing components (section, list rows, buttons, empty and error states) so it matches the rest of the app | Not yet |
| D09 | S27 cards end with "Cách bạn khoảng 2 phút đi bộ"; choosing a kiosk only switches it | The third line is the kiosk's location; a closed kiosk also shows its notice; switching away from a cart of another kiosk asks first, because a cart belongs to one kiosk | The app has no location permission or walking distances; the data model allows one kiosk per cart, so the customer must know the cart will be emptied | Not yet |
| D10 | S17 shows a wallet balance ("Số dư ví: 120.000đ") and a counter number for cash; S16 has no hint for the default kiosk | S17 subtitles describe the method ("Trừ vào thẻ sinh viên", "Trả khi nhận món tại kiosk"); S16 explains that the default kiosk is picked at every sign-in and shows field errors under each field | There is no wallet or counter data, and payments are simulated (D02); showing invented numbers would be hard-coded data | Not yet |
| D11 | The app opens straight on Onboarding or Home | A splash screen (logo and spinner) shows for the moment the app needs to learn the sign-in state, then opens Onboarding, sign-in, Home or the seller app | Without it Home was built before the user was known and wrote the cart for an empty user id; the splash is not a new screen in the flow | Not yet |
| D12 | S02 item card: price on the left, a + button on the right; S02-ADDED shows an "added" snackbar after every add | Price and action share the bottom row of the card. The first + makes the dish photo fly into the cart button (the button bounces) and turns into a stepper [− n +] (a bin icon at 1); later taps change the number in place, which updates at once and is saved in the background. No snackbar: the flight, the stepper and the cart button already show the result, and screen readers hear "Đã thêm … vào giỏ". Reduce motion turns the flight off | Adding the same item again only raised a hidden count; the stepper shows what is in the cart and lets the customer correct it without opening the cart, and one notice per add was noise | Not yet |
| D13 | S02 has the cart icon at the top right, next to the notification bell | A round cart button with a count sits at the bottom right above the tab bar and only appears once the cart has items; the bell stays at the top | The cart is the next step after adding, so it belongs within thumb reach on large phones; an empty cart has nothing to open | Not yet |
| D14 | S05 lines show options ("Cay vừa · Thêm phô mai") and a dish icon; S06-GATEWAY shows the order code; S06-ERR says the order is held until a time; S07 "Chỉ đường tới Kiosk" opens a map | S05 lines show the note for the kitchen, editable in place (items have no options, DB-02/04); the gateway shows the method instead of an order code; S06-ERR says the cart is kept as it is; "Chỉ đường tới kiosk" opens a sheet with the kiosk location, hours and pickup code | The order is created only when payment succeeds (the gateway is simulated, D02), so there is no code yet and nothing expires; the app has no maps or location permission | Not yet |
| D15 | S03 title "Thực đơn Campus Q9", a cart icon at the top right, chips "Dưới 5 phút", "Giảm giá", "Món chay" | Title "Thực đơn" with the kiosk and its status on a tappable line (opens S27); the cart is the floating button of D13; chips "Dưới 5 phút", "Món ăn", "Đồ uống" (tap again to clear); the search filters in place, ignoring accents; no match offers "Xoá bộ lọc" | Items have no discount or vegetarian flag (DB-02), so those chips would filter nothing; a kiosk can be switched from the menu without going back to Home | Not yet |
| D16 | S04 has a heart (favorite), "Mức độ cay" and topping options with extra prices | No heart (favorites are S13, P5); no spicy level or toppings, the kitchen note carries the wish; the bottom bar has the quantity on its own line above a full-width "Thêm vào giỏ · total" button, so the label never wraps at 360 dp or with large text; a sold-out item says when it is back, a cart of another kiosk explains why adding is blocked; after adding, the screen returns to the menu with a "Xem giỏ" snackbar | Items have no option groups (DB-02/04); every reason that blocks adding is shown next to the button instead of failing after the tap | Not yet |
| D17 | S29 lets any listed voucher be selected; a wrong code is only caught in the cart (S05-VOUCHER-ERR) | Only vouchers usable right now can be selected; the others say what is missing ("Mua thêm 1.000đ để dùng mã", "Chỉ áp dụng 10:15–10:30", "Đã hết hạn"); a typed code is checked before it is applied and its error shows under the field. S05-VOUCHER-ERR remains for a voucher that stops applying after the cart changes | The customer learns why a code cannot be used before leaving the screen; a code that cannot apply never reaches the cart | Not yet |
| D18 | S25 asks for the class timetable ("Lịch học của bạn (tự nhập)") and suggests 10:15, 10:20, 10:25 | "Sớm nhất" (as soon as the kiosk can make it) or one of the kiosk's break slots, grouped by day; full slots say "Đã đủ", slots the kiosk cannot make in time say "Không kịp"; the line under the slots says when the food will be ready | The data model books kiosk slots with a capacity (`kiosks/{id}/slots`) and has no timetable; disabling what cannot work removes guesswork | Not yet |
| D19 | S08 recent orders only show "Đặt lại món này"; tapping a finished order is not designed | A finished order opens its detail (S12, P2) and the History tab ends with "Xem toàn bộ lịch sử" (S11, P2); an order in progress opens S07 | S11 and S12 are designed screens owned by P2; S08 links to them instead of duplicating them | Not yet |
| D20 | S06-GATEWAY: "Từ chối giao dịch" and "Xác nhận thanh toán" are text only; S07: "Sửa đơn", "Huỷ đơn", "Về trang chủ" are three identical text links, shown in every state | The gateway pair keeps the same heights (56 dp) and adds icons (close, lock). S07 shows the three as an action row with an icon above each label; "Huỷ đơn" uses the error color; once the kitchen has accepted, "Sửa đơn" and "Huỷ đơn" are greyed out in place with the reason under them; a finished or cancelled order only keeps "Về trang chủ" as a secondary button. The cancelled badge now uses a light red background (`errorContainer`) | A destructive action must not look like a navigation link, and an action that disappears without a reason confuses; icons let the choices be told apart without reading | Not yet |
| | | | | |

Add a row whenever you find a new deviation.
