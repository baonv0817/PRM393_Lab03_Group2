# Test plan (Google ARTEMIS)

Every test is a pytest function that sends **one** instruction through ARTEMIS. The instruction states the starting point, the steps and what must be visible at the end, and asks the agent to report a concrete value (a count, a name, a Remote Config value) so the test can compare it, rather than relying only on `status == "SUCCESS"`. Every test runs at least 3 times; anything below 3 out of 3 is a flaky test, and its cause (app, timing, or an ambiguous instruction) must be found and the fix recorded.

Tests are independent: each starts from its own precondition. Use a dedicated Google account for testing; keys and passwords go in environment variables and are never committed.

The app's UI is in Vietnamese, so labels the agent must tap or read are written in quotes after the English description.

## 1. Key flows and screens

| Flow | Screens |
|---|---|
| Sign-in, sign-out | S26, S15 |
| F1 Quick order | S02, S02-ADDED, S05, S06, S06-GATEWAY, S07 |
| F2 Voucher | S03, S04, S05, S29 |
| F3 Payment error | S06-GATEWAY, S06-ERR, S07-CASH |
| Search | S28, S28-EMPTY |
| Export and upload | Firebase demo area, S12 |
| Push notification | S19 |
| Seller | K01, K02, K03, K04, K05, K06 |
| Seller menu | K08, K09, K14, K15 |
| F9 Sold-out item | S03, S22 |
| Closed kiosk | S21, S27 |

## 2. Test cases

| ID | Flow | Precondition | Instruction (summary) | Expected result | Type | Result |
|---|---|---|---|---|---|---|
| TC-01 | Sign-in | App installed, signed out | Open the app, tap Google sign-in ("Đăng nhập bằng Google"), pick the test account | The Home screen shows with 4 tabs in the bottom bar; report the selected kiosk name | Native | Not run |
| TC-02 | Sign-out | Signed in | Open Profile ("Cá nhân"), tap Sign out ("Đăng xuất") | The sign-in screen shows; pressing Back does not return to Home | Happy path | Not run |
| TC-03 | F1 quick order | Signed in, empty cart | On Home tap + on the first item, tap the cart button at the bottom right ("Giỏ hàng"), Continue to checkout, keep MoMo, Confirm ("Xác nhận"), confirm at the gateway | The Order tracking screen shows; report the pickup code and the total | Happy path | Not run |
| TC-04 | F2 wrong voucher | Cart with 1 item | In the cart tap the voucher field; type BB20 and tap Áp dụng; then add a second item, choose BBSTUDENT, go back and remove one item | BB20 is listed as "Đã hết hạn", cannot be chosen and the typed code shows "Mã BB20 đã hết hạn."; after removing an item the cart shows "Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT." with "Bỏ mã" and checkout is blocked; report that the total is unchanged | Error path | Run: 0/3 pass (section 3) |
| TC-05 | F3 payment error | Cart with 1 item | Checkout, confirm, at the gateway tap Decline ("Từ chối"), choose Cash at the kiosk ("Tiền mặt tại Kiosk"), then on the order screen tap "Huỷ đơn" and confirm | The error screen keeps the cart; after choosing cash there is a pay-at-counter order; after cancelling, the "Đơn đã huỷ" screen (S10) shows "Bạn đã huỷ đơn này." and that nothing needs refunding; report the order code and the line shown | Error path | Not run |
| TC-06 | Search with no results | Signed in | Search for a term that is not on the menu | The empty-state screen shows with a message; report result count = 0 | Error path | Run: 3/3 pass (section 3) |
| TC-07 | Main tabs | Signed in | Tap Menu ("Thực đơn"), Orders ("Đơn hàng"), Profile ("Cá nhân"), Home ("Trang chủ") in turn | Each tab shows the right root screen title | Happy path | Run: 3/3 pass (section 3) |
| TC-08 | Item and order detail screens | At least 1 finished order | Open the detail of an item, then in Orders ("Đơn hàng") tap a finished order to open its detail (S12) | Report the item name and price; report the order code, the status and the total shown in the bill | Happy path | Run: 3/3 pass (section 3) |
| TC-09 | Export and upload | At least 1 order | Open Profile ("Cá nhân"), Firebase demo area ("Khu demo Firebase"), tap Export and upload ("Xuất và tải lên") | Progress shows, then the download URL; the file appears under My files ("Tệp của tôi"); report the file size | Happy path | Run: 3/3 pass (section 3) |
| TC-10 | Remote Config value | Default values | Open Home, count the items in the "quick under 5 minutes" section | Report an item count equal to the current `quick_items_limit` value | Happy path | Run: 2/3 pass (section 3) |
| TC-11 | Open a push notification | App in background, permission granted | Tap the notification in the system notification shade | The app opens the screen related to the notification | Native | Not run |
| TC-12 | Seller accepts and delivers an order | 1 pending order, signed in with the staff role | Open the order, Accept, mark Ready, Scan the code and confirm delivery | The order status changes to delivered; report the order code | Happy path | Not run |
| TC-13 | Analytics event logged | Analytics debug on | Run TC-03 then check Logcat | A `purchase` event with the right parameters is present | Happy path | Not run |
| TC-14 | Choose a kiosk (S27) | Signed in, 1 item in the cart from Kiosk Q9 · Tầng 2 | On Home tap the kiosk name, choose "Kiosk Q9 · Tầng 4", tap Choose this kiosk ("Chọn kiosk này") | A dialog warns that the cart will be emptied; after confirming, Home shows the new kiosk; report the kiosk name and the cart count | Error path | Run: 1/3 pass (section 3) |
| TC-15 | Student profile (S16) | Signed in | Profile, Student profile ("Hồ sơ sinh viên"), type "SE12" as the student ID, tap Save ("Lưu hồ sơ"); then type "SE183398" and save | First an error under the field, then "Đã lưu hồ sơ."; report both messages | Error path | Run: 1/3 pass (section 3) |
| TC-16 | Default payment method (S17) | Signed in | Profile, Payment methods ("Phương thức thanh toán"), choose cash, tap Save ("Lưu mặc định") | "Đã đặt Tiền mặt tại kiosk làm mặc định." shows and cash stays selected after reopening; report the selected method | Happy path | Run: 3/4 pass (section 3) |
| TC-17 | Change the quantity on Home (S02) | Signed in, empty cart | Tap + on the first item, then + twice on its stepper, then − three times | The stepper shows 3, the cart icon shows 3, then the + button comes back and the cart is empty; report the numbers shown | Happy path | Run: 2/3 pass (section 3) |
| TC-18 | Export an order receipt (S12) | At least 1 finished order | Orders ("Đơn hàng"), tap a finished order, tap Export receipt ("Xuất biên nhận PDF") | Progress ("Đang tải lên …%") shows, then "Đã tải lên · N KB" with the file name and link; the file is listed under "Biên nhận đã xuất" after reopening the order; report the file name and size | Happy path | Not run |
| TC-19 | Offline receipt export (S12) | Airplane mode on, 1 finished order open in S12 | Tap Export receipt ("Xuất biên nhận PDF") | A message says there is no network; no "Đã tải lên" card appears and the button works again; report the message shown | Error path | Not run |
| TC-20 | Order history by week and month (S11) | At least 2 finished or cancelled orders | Orders ("Đơn hàng"), tab History ("Lịch sử"), tap "Xem toàn bộ lịch sử", then "Tháng", then "Tuần"; open the first order | A card "Chi tiêu tuần này" ("Chi tiêu tháng …" on the other tab) shows the total and a bar for each day; orders are grouped under headings such as "Tuần này" and "Tháng này", each with a count and the amount spent; the order opens its detail; report the card's total and the first heading and its summary line | Happy path | Not run |
| TC-21 | Edit a pending order (S09) | 1 order just placed with cash, the kitchen has not accepted it | Orders ("Đơn hàng"), open the order, tap Edit ("Sửa đơn"), tap + on the first item, tap Save changes ("Lưu thay đổi") | "Đã cập nhật đơn." shows and the order screen lists the new quantity and total; report the new total; the Edit button is greyed out once the kitchen has accepted the order | Happy path | Not run |
| TC-22 | Enlarged pickup QR code (S20) | 1 order just placed, the kitchen has not accepted it | Orders ("Đơn hàng"), open the order, tap "Phóng to mã QR" | The QR code shows large with the 6-digit code in two groups and "Kiosk chưa nhận đơn. Mã dùng được khi món sẵn sàng."; closing returns to the order; report the code shown | Happy path | Not run |
| TC-23 | Report a problem (S24) | 1 delivered order | Orders ("Đơn hàng"), open the delivered order, tap "Báo sự cố với đơn này", choose "Thiếu món", type "Thiếu 1 ly trà đào", tap "Gửi báo cáo" | "Đã gửi báo cáo. Kiosk sẽ xem sớm." shows, then the report with "Đã gửi, chờ kiosk xem"; the form does not come back when the order is opened again; report the status shown | Happy path | Not run |
| TC-24 | Rate an item (S23) | 1 delivered order | Orders ("Đơn hàng"), open the delivered order, tap "Đánh giá món", tap the circle 4 of the first item, choose "Ngon", type "Vỏ giòn", tap "Gửi đánh giá" | "Đã gửi 1 đánh giá. Cảm ơn bạn!" shows and the order opens again; reopening "Đánh giá món" shows "Đã đánh giá" on that item with circle 4 selected; report the word under the selected circle ("Ngon") | Happy path | Not run |
| TC-25 | Mark an item sold out (K08, K09) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | Open the "Món" tab, switch off the first item, choose "Máy hỏng" and the second time offered, tap "Xác nhận hết món"; then, in the customer app, open the menu | The row says "… · Hết · có lại hh:mm" in red; the customer menu shows the item as sold out with "Có lại lúc hh:mm" and it cannot be added; report the row text | Happy path | Not run |
| TC-26 | Add and edit an item (K14, K15) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | Open the "Món" tab, tap "+" in the top bar, tap "Lưu món" with the form empty, then type "Bún bò Huế", price 45000, tap + once on the preparation time and save; then tap the new item in the list, change the price to 48000 and save | The empty form shows "Nhập tên món." and "Nhập giá món."; the item then appears in the list, and after the edit the row shows "48.000đ · Còn hàng" and the customer menu shows the new price; report the price shown | Happy path | Not run |
| TC-27 | Pause the kiosk and change the wait (K10) | Signed in with the staff role at Kiosk Q9 · Tầng 2; a second device or account signed in as a customer on the kiosk list | Open the "Quán" tab, tap "30 phút" next to "Tạm ngưng lâu hơn", then tap "Nhận đơn lại ngay"; tap + on the wait twice; switch "Đang nhận đơn" off and on | After the pause the status reads "Tạm ngưng · nhận đơn lại lúc hh:mm" and the customer's kiosk list shows it paused and refuses an order; the wait goes up by 2 minutes on both devices; with the switch off the status reads "Đang đóng cửa"; report each status line | Happy path | Not run |
| TC-28 | Save the shop information (K10) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | In the "Quán" tab type the notice "Hết sốt", opening time 25:00 and capacity 0, tap "Lưu thông tin"; then correct them to 06:30 and 8 and tap again | The first save shows "Nhập giờ dạng 06:30." and "Nhập số từ 1 đến 999, hoặc để trống." under the fields and nothing is saved; the second shows "Đã lưu thông tin quán." and the button disappears; report the messages | Error case | Not run |
| TC-29 | Shift statistics (K11) | Signed in with the staff role at Kiosk Q9 · Tầng 2; 2 orders delivered, 1 rejected and 1 pending today | Open the "Quán" tab, tap "Thống kê ca hôm nay"; then deliver another order in the orders tab, go back to the statistics and tap the refresh button | "Đơn đã làm" and "Doanh thu" match the delivered orders, "Đơn huỷ" and "Đang xử lý: N đơn" match the others, the chart has a bar for the current hour; after the refresh the figures include the new order and the update time changes; report the figures | Happy path | Not run |
| TC-30 | Sold-out item and its replacements (S03, S22) | Signed in, Kiosk Q9 · Tầng 2 selected, one food item sold out (TC-25), at least one other food item in stock | On the menu ("Thực đơn") tap the card with the "Tạm hết" label; then tap + on the first item under "Gợi ý thay thế còn hàng" and tap + again on its stepper | The screen "Món tạm hết" shows the sold-out item without a + button, a bar "Có lại lúc hh:mm" and only items in stock from the same kiosk; the card turns into a stepper showing 2 and the cart button shows 2; report the name of the first replacement and the number on the cart button | Happy path | Not run |
| TC-31 | Home when the kiosk is closed (S21) | Signed in; the kiosk "Nhà văn hóa SV · Tầng 1" is closed (`open: false`, opens at 07:00, as in the seed) | On Home tap the kiosk name, choose "Nhà văn hóa SV · Tầng 1" and confirm; then tap "Chọn kiosk khác" on the card, choose "Kiosk Q9 · Tầng 2" and confirm | Home shows "Đóng · mở lại 07:00" in red, the card "Quán đang đóng cửa" with the kiosk's notice and "Mở lại lúc 07:00", and "Xem trước thực đơn" with cards labelled "Quán đóng" and no + button; after choosing Kiosk Q9 · Tầng 2 the normal Home comes back with search and "Món nhanh"; report the status line and the card title | Error path | Not run |

The instructions above are summaries; the full versions are in `e2e_test/`. Everyone adds cases for the screens they own (if section 7 of the handout is not covered).

## 3. Run results

| Test | Runs | Pass rate | Average time | Notes (flaky, failures, skipped) |
|---|---|---|---|---|
| TC-04 | 3 | 0/3 (0%) | 232 s | Fails every time: the agent does not type BB20 in the field and taps "Áp dụng" on an empty field ("Nhập mã giảm giá trước khi áp dụng."). The app is correct when done by hand (see `manual/`). Agent typing problem, not an app bug. |
| TC-06 | 3 | 3/3 (100%) | 212 s | Stable. |
| TC-07 | 3 | 3/3 (100%) | 87 s | Stable. |
| TC-08 | 3 | 3/3 (100%) | 100 s | Stable. |
| TC-09 | 3 | 3/3 (100%) | 107 s | Stable (run 2 was cancelled by hand and is not counted). |
| TC-10 | 3 | 2/3 (67%) | 70 s | Run 4: agent counted 4 of the 5 "Món nhanh" items because the list is vertical and needs scrolling (agent miscount; the app shows 5). |
| TC-14 | 3 | 1/3 (33%) | 111 s | Flaky. Run 1: agent reported no warning text; run 5: agent reported 1 in the cart after confirming. By hand the dialog "Đổi kiosk sẽ làm trống giỏ hàng" shows and the cart is emptied (`manual/`). Agent misread. |
| TC-15 | 3 | 1/3 (33%) | 184 s | Flaky. Run 1/3: agent did not read the saved value (the snackbar disappears; test changed to reopen the screen and read the field after run 1). Saves and persists SE183398 by hand. |
| TC-16 | 4 | 3/4 (75%) | 73 s | Run 2 failed on the old snackbar check; the test now reads the saved choice after reopening and passes (runs 3, 4). |
| TC-17 | 3 | 2/3 (67%) | 83 s | Run 3: agent tapped the stepper once (reported 1, expected 3). Run 2 was cancelled by hand and is not counted. |

Scope: 10 of the 31 cases were run (TC-04, 06, 07, 08, 09, 10, 14, 15, 16, 17), each at least 3 times, on an Android emulator (Pixel 7) against the real Firebase project, with ARTEMIS flash profile (Gemini 3.5 Flash Lite). Runs 1 to 5 are `evidence/artemis/run-*.xml` (JUnit); run 2 had two cases cancelled by hand, which are not counted. The other 21 cases are **Not run** (free-tier Gemini quota; most need two devices, the staff role, airplane mode or the notification shade). Instructions and assertions of TC-04, 14, 15, 16 were changed between runs after the first failures (agent typing and short-lived snackbars), so early failures are shown as they happened.

Reading the table honestly: a failure here is almost always the agent mis-operating or mis-reading the screen; for each failing case the behaviour was repeated by hand and the app was correct (`evidence/artemis/manual/`). This pinned ARTEMIS version returns no structured output, so `e2e_test/conftest.py` reads the agent's final report from the server trace (`ARTEMIS_TRACES_DIR`).

Command used: `cd e2e_test; uv run pytest -q -k "tc06 or tc07" --junitxml=../evidence/artemis/run-N.xml` (do not use `run_repeat.py -n`, it overwrites run-1…).

## 4. Exploratory session (Pro profile, 15 to 30 minutes)

**Session of 10/11/2026, about 10 minutes, by P2 with Claude Code, on an Android emulator (Pixel 7, API 36) with the fake-data build** (`flutter run -t dev/main_dev.dart --dart-define=DEV_SIGNED_IN=true --dart-define=DEV_SEED=true`, once as `DEV_ROLE=user` and once as `DEV_ROLE=staff`), driven with `adb` taps and screenshots. This is **not** the ARTEMIS Pro-profile session the handout asks for; P5 repeats it with ARTEMIS on a phone and the real Firebase. Charter: text at 200 % (Home, Menu, Orders, Profile, and the seller tabs), many fast taps, odd search input, the receipt export.

| Time (device clock) | Bug or problem found | Severity | Handled |
|---|---|---|---|
| 12:52 | Text at 200 %: the Orders tab "Đang xử lý (2)" fades out at the closing bracket (S08, P1) | Low | Open |
| 12:52 | Text at 200 %: the kiosk status line is cut with "…" on Home ("Sẵn sàng · chờ 5–7 ph…") and on the Menu ("Mở · ch…"), so the wait time cannot be read | Low | Open |
| 12:54 | The search's empty state says "xem các món bán chạy" but offers only three search suggestions | Low | Open |
| 12:54 | Orders: the badge "Đã nhận đơn" (placed) sits above the line "Chờ kiosk nhận đơn" (not accepted yet), and the history says "Đã nhận" for a picked-up order; the three read as contradictory | Low (wording from Figma) | Open, to decide with P1 |
| 12:58 | K10 at 200 %: the labels "Giờ mở cửa" and "Giờ đóng cửa" are cut ("Giờ mở c…") in two half-width fields | Low | Fixed: the two fields stack when the text is 1.5 times larger or more; widget test added |

What was tried and showed no problem: 14 fast taps on "+" give a quantity of 14 and the cart total 546.000đ (14 × 39.000đ); two quick taps on "Xuất biên nhận PDF" produce one receipt in the list; a search for "tacos%20%26%2…" says nothing was found and shows the term; the seller Orders, Menu and Shop tabs at 200 % show no overflow in a debug build. Not tried: airplane mode (the fake build does not use the network), rotation, a real push notification.
