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
| TC-01 | Sign-in | App installed, signed out | Open the app, tap Google sign-in ("Đăng nhập bằng Google"), pick the test account | The Home screen shows with 4 tabs in the bottom bar; report the selected kiosk name | Native | Run: 3/3 pass (section 3) |
| TC-02 | Sign-out | Signed in | Open Profile ("Cá nhân"), tap Sign out ("Đăng xuất") | The sign-in screen shows; pressing Back does not return to Home | Happy path | Run: 3/3 pass (section 3) |
| TC-03 | F1 quick order + Analytics | Signed in, empty cart, Analytics debug mode on | On Home tap + on the first item once, tap the round cart button at the bottom right, Continue to checkout, keep MoMo, Confirm ("Xác nhận"), confirm at the gateway; then the test reads Logcat | The Order tracking screen shows; report the order code (#…), the 6-digit pickup code under the QR ("Mã số: …") and the total; Logcat has a `purchase` event with a `transaction_id` (this was TC-13) | Happy path, analytics | Run: 3/3 pass (section 3) |
| TC-04 | F2 wrong voucher | Cart with 1 item | In the cart tap the voucher field; type BB20 and tap Áp dụng; then add a second item, choose BBSTUDENT, go back and remove one item | BB20 is listed as "Đã hết hạn", cannot be chosen and the typed code shows "Mã BB20 đã hết hạn."; after removing an item the cart shows "Đơn tối thiểu 40.000đ để dùng mã BBSTUDENT." with "Bỏ mã" and checkout is blocked; report that the total is unchanged | Error path | Run: 3/3 pass (section 3) |
| TC-05 | F3 payment error | Cart with 1 item | Checkout, confirm, at the gateway tap Decline ("Từ chối"), choose Cash at the kiosk ("Tiền mặt tại Kiosk"), then on the order screen tap "Huỷ đơn" and confirm | The error screen keeps the cart; after choosing cash there is a pay-at-counter order; after cancelling, the "Đơn đã huỷ" screen (S10) shows "Bạn đã huỷ đơn này." and that nothing needs refunding; report the order code and the line shown | Error path | Run: found an app bug, fixed; 3/4 pass on the fixed build (section 3) |
| TC-06 | Search with no results | Signed in | Search for a term that is not on the menu | The empty-state screen shows with a message; report result count = 0 | Error path | Run: 3/3 pass (section 3) |
| TC-07 | Main tabs | Signed in | Tap Menu ("Thực đơn"), Orders ("Đơn hàng"), Profile ("Cá nhân"), Home ("Trang chủ") in turn | Each tab shows the right root screen title | Happy path | Run: 3/3 pass (section 3) |
| TC-08 | Item and order detail screens | At least 1 finished order | Open the detail of an item, then in Orders ("Đơn hàng") tap a finished order to open its detail (S12) | Report the item name and price; report the order code, the status and the total shown in the bill | Happy path | Run: 3/3 pass (section 3) |
| TC-09 | Export and upload | At least 1 order | Open Profile ("Cá nhân"), Firebase demo area ("Khu demo Firebase"), tap Export and upload ("Xuất và tải lên") | Progress shows, then the download URL; the file appears under My files ("Tệp của tôi"); report the file size | Happy path | Run: 3/3 pass (section 3) |
| TC-10 | Remote Config value | Default values | Open Home, list and count the items in the "Món nhanh · tối đa 5 phút" section (swipe up to see the last one) | Report an item count equal to the current `quick_items_limit` value | Happy path | Run: 3/3 pass (section 3) |
| TC-11 | Open a push notification | App in background, permission granted | Tap the notification in the system notification shade | The app opens the screen related to the notification | Native | Backlog, not run (see below) |
| TC-12 | Seller accepts and delivers an order | 1 pending order, signed in with the staff role | Open the order, Accept, mark Ready, Scan the code and confirm delivery | The order status changes to delivered; report the order code | Happy path | Run: 3/3 pass (section 3) |
| TC-13 | Analytics event logged | Analytics debug on | Run TC-03 then check Logcat | A `purchase` event with the right parameters is present | Happy path | Merged into TC-03 (same flow, one run instead of two) |
| TC-14 | Choose a kiosk (S27) | Signed in, 1 item in the cart from Kiosk Q9 · Tầng 2 | On Home tap the kiosk name, choose "Kiosk Q9 · Tầng 4", tap Choose this kiosk ("Chọn kiosk này") | A dialog warns that the cart will be emptied; after confirming, Home shows the new kiosk; report the kiosk name and the cart count | Error path | Run: 1/3 pass (section 3) |
| TC-15 | Student profile (S16) | Signed in | Profile, Student profile ("Hồ sơ sinh viên"), type "SE12" as the student ID, tap Save ("Lưu hồ sơ"); then type "SE183398" and save | First an error under the field, then "Đã lưu hồ sơ."; report both messages | Error path | Run: 1/3 pass (section 3) |
| TC-16 | Default payment method (S17) | Signed in | Profile, Payment methods ("Phương thức thanh toán"), choose cash, tap Save ("Lưu mặc định") | "Đã đặt Tiền mặt tại kiosk làm mặc định." shows and cash stays selected after reopening; report the selected method | Happy path | Run: 3/4 pass (section 3) |
| TC-17 | Change the quantity on Home (S02) | Signed in, empty cart | Tap + on the first item, then + twice on its stepper, then − three times | The stepper shows 3, the cart icon shows 3, then the + button comes back and the cart is empty; report the numbers shown | Happy path | Run: 2/3 pass (section 3) |
| TC-18 | Export an order receipt (S12) | At least 1 finished order | Orders ("Đơn hàng"), tap a finished order, tap Export receipt ("Xuất biên nhận PDF") | Progress ("Đang tải lên …%") shows, then "Đã tải lên · N KB" with the file name and link; the file is listed under "Biên nhận đã xuất" after reopening the order; report the file name and size | Happy path | Backlog, not run (see below) |
| TC-19 | Offline receipt export (S12) | Airplane mode on, 1 finished order open in S12 | Tap Export receipt ("Xuất biên nhận PDF") | A message says there is no network; no "Đã tải lên" card appears and the button works again; report the message shown | Error path | Backlog, not run (see below) |
| TC-20 | Order history by week and month (S11) | At least 2 finished or cancelled orders | Orders ("Đơn hàng"), tab History ("Lịch sử"), tap "Xem toàn bộ lịch sử", then "Tháng", then "Tuần"; open the first order | A card "Chi tiêu tuần này" ("Chi tiêu tháng …" on the other tab) shows the total and a bar for each day; orders are grouped under headings such as "Tuần này" and "Tháng này", each with a count and the amount spent; the order opens its detail; report the card's total and the first heading and its summary line | Happy path | Backlog, not run (see below) |
| TC-21 | Edit a pending order (S09) | 1 order just placed with cash, the kitchen has not accepted it | Orders ("Đơn hàng"), open the order, tap Edit ("Sửa đơn"), tap + on the first item, tap Save changes ("Lưu thay đổi") | "Đã cập nhật đơn." shows and the order screen lists the new quantity and total; report the new total; the Edit button is greyed out once the kitchen has accepted the order | Happy path | Backlog, not run (see below) |
| TC-22 | Enlarged pickup QR code (S20) | 1 order just placed, the kitchen has not accepted it | Orders ("Đơn hàng"), open the order, tap "Phóng to mã QR" | The QR code shows large with the 6-digit code in two groups and "Kiosk chưa nhận đơn. Mã dùng được khi món sẵn sàng."; closing returns to the order; report the code shown | Happy path | Backlog, not run (see below) |
| TC-23 | Report a problem (S24) | 1 delivered order | Orders ("Đơn hàng"), open the delivered order, tap "Báo sự cố với đơn này", choose "Thiếu món", type "Thiếu 1 ly trà đào", tap "Gửi báo cáo" | "Đã gửi báo cáo. Kiosk sẽ xem sớm." shows, then the report with "Đã gửi, chờ kiosk xem"; the form does not come back when the order is opened again; report the status shown | Happy path | Backlog, not run (see below) |
| TC-24 | Rate an item (S23) | 1 delivered order | Orders ("Đơn hàng"), open the delivered order, tap "Đánh giá món", tap the circle 4 of the first item, choose "Ngon", type "Vỏ giòn", tap "Gửi đánh giá" | "Đã gửi 1 đánh giá. Cảm ơn bạn!" shows and the order opens again; reopening "Đánh giá món" shows "Đã đánh giá" on that item with circle 4 selected; report the word under the selected circle ("Ngon") | Happy path | Backlog, not run (see below) |
| TC-25 | Mark an item sold out (K08, K09) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | Open the "Món" tab, switch off the first item, choose "Máy hỏng" and the second time offered, tap "Xác nhận hết món"; then, in the customer app, open the menu | The row says "… · Hết · có lại hh:mm" in red; the customer menu shows the item as sold out with "Có lại lúc hh:mm" and it cannot be added; report the row text | Happy path | Backlog, not run (see below) |
| TC-26 | Add and edit an item (K14, K15) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | Open the "Món" tab, tap "+" in the top bar, tap "Lưu món" with the form empty, then type "Bún bò Huế", price 45000, tap + once on the preparation time and save; then tap the new item in the list, change the price to 48000 and save | The empty form shows "Nhập tên món." and "Nhập giá món."; the item then appears in the list, and after the edit the row shows "48.000đ · Còn hàng" and the customer menu shows the new price; report the price shown | Happy path | Backlog, not run (see below) |
| TC-27 | Pause the kiosk and change the wait (K10) | Signed in with the staff role at Kiosk Q9 · Tầng 2; a second device or account signed in as a customer on the kiosk list | Open the "Quán" tab, tap "30 phút" next to "Tạm ngưng lâu hơn", then tap "Nhận đơn lại ngay"; tap + on the wait twice; switch "Đang nhận đơn" off and on | After the pause the status reads "Tạm ngưng · nhận đơn lại lúc hh:mm" and the customer's kiosk list shows it paused and refuses an order; the wait goes up by 2 minutes on both devices; with the switch off the status reads "Đang đóng cửa"; report each status line | Happy path | Backlog, not run (see below) |
| TC-28 | Save the shop information (K10) | Signed in with the staff role at Kiosk Q9 · Tầng 2 | In the "Quán" tab type the notice "Hết sốt", opening time 25:00 and capacity 0, tap "Lưu thông tin"; then correct them to 06:30 and 8 and tap again | The first save shows "Nhập giờ dạng 06:30." and "Nhập số từ 1 đến 999, hoặc để trống." under the fields and nothing is saved; the second shows "Đã lưu thông tin quán." and the button disappears; report the messages | Error case | Backlog, not run (see below) |
| TC-29 | Shift statistics (K11) | Signed in with the staff role at Kiosk Q9 · Tầng 2; 2 orders delivered, 1 rejected and 1 pending today | Open the "Quán" tab, tap "Thống kê ca hôm nay"; then deliver another order in the orders tab, go back to the statistics and tap the refresh button | "Đơn đã làm" and "Doanh thu" match the delivered orders, "Đơn huỷ" and "Đang xử lý: N đơn" match the others, the chart has a bar for the current hour; after the refresh the figures include the new order and the update time changes; report the figures | Happy path | Backlog, not run (see below) |
| TC-30 | Sold-out item and its replacements (S03, S22) | Signed in, Kiosk Q9 · Tầng 2 selected, one food item sold out (TC-25), at least one other food item in stock | On the menu ("Thực đơn") tap the card with the "Tạm hết" label; then tap + on the first item under "Gợi ý thay thế còn hàng" and tap + again on its stepper | The screen "Món tạm hết" shows the sold-out item without a + button, a bar "Có lại lúc hh:mm" and only items in stock from the same kiosk; the card turns into a stepper showing 2 and the cart button shows 2; report the name of the first replacement and the number on the cart button | Happy path | Backlog, not run (see below) |
| TC-31 | Home when the kiosk is closed (S21) | Signed in; the kiosk "Nhà văn hóa SV · Tầng 1" is closed (`open: false`, opens at 07:00, as in the seed) | On Home tap the kiosk name, choose "Nhà văn hóa SV · Tầng 1" and confirm; then tap "Chọn kiosk khác" on the card, choose "Kiosk Q9 · Tầng 2" and confirm | Home shows "Đóng · mở lại 07:00" in red, the card "Quán đang đóng cửa" with the kiosk's notice and "Mở lại lúc 07:00", and "Xem trước thực đơn" with cards labelled "Quán đóng" and no + button; after choosing Kiosk Q9 · Tầng 2 the normal Home comes back with search and "Món nhanh"; report the status line and the card title | Error path | Backlog, not run (see below) |
| TC-40 | Final assignment AI (K14, `docs/ai-feature.md`) | Staff account of Kiosk Q9 · Tầng 2; Remote Config `ai_enabled` = true; `banh-mi.jpg` in the phone's gallery (Pictures/BreakBiteAI) | Món → + → "Thư viện" → the bánh mì photo → "Điền bằng AI"; wait for the "Gợi ý từ AI" notice; close without saving | The name contains "bánh mì", the price is 5 000 – 100 000 đ, "Món ăn" is chosen, "Gợi ý từ AI" is under the name | Happy path, AI | `docs/test-report.md` |
| TC-41 | Final assignment AI, error path | As TC-40, with `breakbite_logo.png` in the gallery | Same steps with the logo; then type "Món thử" in the name; close without saving | The red line under the button says the photo is not food ("không giống món ăn"), the name stays empty, typing still works | Error path, AI | `docs/test-report.md` |

The instructions above are summaries; the full versions are in `e2e_test/`.

**Graded suite.** Eleven cases cover every item of section 7 of the handout, and each was run at least 3 times: sign-in with the native Google account chooser (TC-01), sign-out (TC-02), every Lab 2 flow end to end with its error branch (F1 TC-03, F2 TC-04, F3 TC-05, seller TC-12), search with an error path (TC-06), every tab (TC-07), each kind of detail screen (TC-08), export and upload (TC-09), a Remote Config value on screen (TC-10) and one test that also checks its Analytics event (TC-03). TC-14 to TC-17 were run as extra cases in the first session.

**Backlog (not run).** TC-11 and TC-18 to TC-31 are written and have pytest functions, but are not part of the graded suite and were not run: the items they would add are already covered by the eleven cases above, and several need a second device, airplane mode or a push sent from the console at the right moment. They stay as regression cases for later.

## 3. Run results

### 3.1 Graded suite (12/11/2026, runs 6 to 39)

Setup: Android emulator `BB_Pixel7` (Pixel 7, API 36.1, Google Play image) with the real Firebase project and a debug build (`flutter build apk --debug --dart-define-from-file=env/cloudinary.json`); ARTEMIS at the pinned commit with the local typing patch (`e2e_test/README.md`); Flash profile, model `gemini-3.5-flash-lite` (fallback `gemini-3.1-flash-lite`). Each run is a JUnit file `evidence/artemis/run-N.xml`; the trace of each session is `C:/src/artemis/traces/<trace id>/` (step screenshots in `traces/data_engine.db`). The customer account ran TC-01 to TC-10, the staff account TC-12. `run_repeat.py --restart-app` restarts the app before each run so it starts from its precondition; TC-04 also had its cart emptied before each run.

| Test | Runs (files) | Pass rate | Average time | Trace ids (first 8 characters) | Notes |
|---|---|---|---|---|---|
| TC-01 | 3 (run-6 to 8) | 3/3 (100%) | 94 s | dae0cbd4, d81730f9, 4c05b471 | The agent picks the test account in the system account chooser (native) and reports `{"tab_count": 4, "kiosk": "Kiosk Q9 · Tầng 2"}`. |
| TC-02 | 3 (run-6 to 8) | 3/3 (100%) | 127 s | 93b6b72f, b68ccaca, 776cfafa | Sign-in screen shows; Back does not return to Home. |
| TC-03 | 3 (run-12 to 14) | 3/3 (100%) | 86 s | 1cadacaa, 4d26a7c0, 3b422648 | Each run places a MoMo order (#UWVTN7, #CI51CX, #ERSWIH) and Logcat shows `purchase` with `transaction_id`. First three runs (run-9 to 11, afc66006, cccfcfb7, 5823e40b) were 0/3: **ambiguous instruction**. The tracking screen puts "Mã nhận tại Kiosk Q9 · Tầng 2" right above the order code, so the agent reported the order code (#WBUPGW) as the pickup code; in two runs it also tapped + twice (44.000đ). Fix: the instruction now names the order code (# at the top) and the 6-digit "Mã số" under the QR, and says to tap + exactly once. |
| TC-04 | 3 (run-31 to 33) | 3/3 (100%) | 140 s | 6d2f5d30, b4c12ade, b0e852c7 | History: runs 1 to 5 0/3 (**tool**: ARTEMIS pasted text with KEYCODE_PASTE, which Flutter fields ignore, so BB20 never reached the field; fixed by the local ARTEMIS patch); run-18, 19 failed on an **ambiguous instruction** (the cart shows two red lines and the agent read the other one; the instruction now asks for both) and run-20 on the free-tier Gemini quota (HTTP 429); run-25 to 27 2/3 (run-26, a03d917e: the agent typed BB20 and tapped Áp dụng but did not read the error under the field; the instruction now says to wait 2 s and read that line). |
| TC-05 | 4 (run-21 to 24) | 3/4 (75%) | 181 s (passing runs) | 2afee186, 6fbe98b0, fab47be6, 9ca2b0e3 | **App bug found and fixed** (section 3.3, P-01). Before the fix (run-15 to 17: 2948b743, 008f34db, dffc72b1) the app created the cash order but stayed on "Thanh toán chưa thành công" in 3 of 4 attempts. On the fixed build every passing run opened "Theo dõi đơn" about 3 s after the tap. run-21 failed with ANR dialogs because the whole `flutter test` suite was running on the same host at that moment (**timing / host load**); runs 22 to 24 were made with the host idle. |
| TC-06 | 3 (runs 1 to 5, 11/11) | 3/3 (100%) | 212 s | see 3.2 | Not rerun; the agent needed 4 to 6 typing attempts before the ARTEMIS patch, which explains the long time. |
| TC-07 | 3 (runs 1 to 5, 11/11) | 3/3 (100%) | 87 s | see 3.2 | Not rerun. |
| TC-08 | 3 (runs 1 to 5, 11/11) | 3/3 (100%) | 100 s | see 3.2 | Not rerun. |
| TC-09 | 3 (runs 1 to 5, 11/11) | 3/3 (100%) | 107 s | see 3.2 | Not rerun. |
| TC-10 | 3 (run-34 to 36) | 3/3 (100%) | 31 s | 3e17222d, d2fef168, bbbc010e | The agent lists the five items and the count matches `quick_items_limit` (5). Earlier 2/3 twice (11/11 run 4; run-28, 1f844f5a): "cuộn xuống" made the agent swipe its finger down, which scrolls up, so the fifth item stayed below the edge (**ambiguous instruction**). Fix: "swipe from the bottom up" and list the item names, so a miscount is visible. |
| TC-12 | 3 (run-37 to 39) | 3/3 (100%) | 125 s | b3e53237, 35159963, dbe817e1 | Three different orders (#WVRV3P, #FU2YBY, #HYOPW7) accepted, marked ready, scanned and handed over; final status "Đã giao". |

Command used (from `e2e_test/`, environment variables as in `e2e_test/README.md`): `uv run python run_repeat.py -n 3 -k tc03 --start 12 --restart-app`, and the same with the other `-k` and `--start` values above. The script refuses to overwrite an existing `run-N.xml`.

### 3.2 First session (11/11/2026, runs 1 to 5)

| Test | Runs | Pass rate | Average time | Notes (flaky, failures, skipped) |
|---|---|---|---|---|
| TC-04 | 3 | 0/3 (0%) | 232 s | Fails every time: the agent does not type BB20 in the field and taps "Áp dụng" on an empty field ("Nhập mã giảm giá trước khi áp dụng."). The app is correct when done by hand (see `manual/`). Cause found on 12/11: the ARTEMIS paste-based typing (section 3.1); now 3/3. |
| TC-06 | 3 | 3/3 (100%) | 212 s | Stable. |
| TC-07 | 3 | 3/3 (100%) | 87 s | Stable. |
| TC-08 | 3 | 3/3 (100%) | 100 s | Stable. |
| TC-09 | 3 | 3/3 (100%) | 107 s | Stable (run 2 was cancelled by hand and is not counted). |
| TC-10 | 3 | 2/3 (67%) | 70 s | Run 4: agent counted 4 of the 5 "Món nhanh" items because the list is vertical and needs scrolling (agent miscount; the app shows 5). Instruction fixed on 12/11; now 3/3 (section 3.1). |
| TC-14 | 3 | 1/3 (33%) | 111 s | Flaky. Run 1: agent reported no warning text; run 5: agent reported 1 in the cart after confirming. By hand the dialog "Đổi kiosk sẽ làm trống giỏ hàng" shows and the cart is emptied (`manual/`). Agent misread. |
| TC-15 | 3 | 1/3 (33%) | 184 s | Flaky. Run 1/3: agent did not read the saved value (the snackbar disappears; test changed to reopen the screen and read the field after run 1). Saves and persists SE183398 by hand. |
| TC-16 | 4 | 3/4 (75%) | 73 s | Run 2 failed on the old snackbar check; the test now reads the saved choice after reopening and passes (runs 3, 4). |
| TC-17 | 3 | 2/3 (67%) | 83 s | Run 3: agent tapped the stepper once (reported 1, expected 3). Run 2 was cancelled by hand and is not counted. |

Scope of this first session: 10 cases (TC-04, 06, 07, 08, 09, 10, 14, 15, 16, 17), each at least 3 times, on the same emulator against the real Firebase project, with the ARTEMIS Flash profile (Gemini 3.5 Flash Lite). Runs 1 to 5 are `evidence/artemis/run-1.xml` to `run-5b.xml`; run 2 had two cases cancelled by hand, which are not counted. Instructions and assertions of TC-04, 14, 15, 16 were changed between runs after the first failures (agent typing and short-lived snackbars), so early failures are shown as they happened. Command: `uv run pytest -q -k "tc06 or tc07" --junitxml=../evidence/artemis/run-N.xml`.

This pinned ARTEMIS version returns no structured output, so `e2e_test/conftest.py` reads the agent's final report from the server trace (`ARTEMIS_TRACES_DIR`).

### 3.3 Problems the runs found

| ID | Found by | Kind | Problem | Status |
|---|---|---|---|---|
| P-01 | TC-05 (run-15, run-17) | **App bug** | After MoMo was declined and cash was chosen on S06-ERR, "Đặt đơn, trả tiền mặt tại kiosk" created the order and emptied the cart, but the screen stayed on "Thanh toán chưa thành công" with "Tổng thanh toán: 0đ"; the customer had to find the order in the Orders tab. The trace shows `placeOrder` returned Ok (the screen only shows 0đ when the order id is set), so the navigation after `await` was lost: `CheckoutScreen._confirm` used the screen's `context` after the await (`if (!context.mounted) return; context.go(…)`). Not reproduced by hand (2 tries). | **Fixed**: `_confirm` and `GatewayScreen._pay` read `GoRouter.of(context)` before the await and navigate with it once the order exists (same pattern as `orders_screen.dart` reorder). Verified: 3 of 3 passing runs on the fixed build opened the order; `flutter test` 752/752 pass. |
| P-02 | TC-05 (run-15, run-17) | Usability | On the Orders tab an active order card is not tappable (only its "Xem mã QR nhận món" button opens it), while a finished order card is. The agent tapped the card 7 to 9 times before finding the button. | Open (low) |
| P-03 | TC-03 (run-9 to 11) | Usability / wording | The tracking screen (S07) labels the order code "Mã nhận tại Kiosk Q9 · Tầng 2", while the real pickup code is the 6 digits under the QR ("Mã số"). Two different "codes" read as the same thing. | Open (low), to decide with P1 |
| E-01 | TC-04, TC-06 | ARTEMIS tool | Typing into Flutter fields went through the clipboard and KEYCODE_PASTE, which Flutter ignores; the tool still reported success. | Worked around: local patch `e2e_test/artemis-ascii-input.patch` (ASCII through `adb input text`). |
| E-02 | TC-01 setup | Test device | Google sign-in on the emulator failed with "Account reauth failed / Network error" (shown in the app as "Bạn đã huỷ đăng nhập") because the emulator's automatic Private DNS broke name resolution. | Fixed on the device: `adb shell settings put global private_dns_mode off`. |
| E-03 | TC-04 run-20 | Test infrastructure | The free-tier Gemini quota (500 requests a day for `gemini-3.5-flash-lite`) ran out after about 25 sessions; ARTEMIS also pre-warms `gemini-3.8-flash` (20 a day) at every session start, which only logs a 429. | Runs from 13:00 used a second API key, and the exploratory session (section 4.1) a third after the second ran out. |

## 4. Exploratory session (Pro profile, 15 to 30 minutes)

### 4.1 ARTEMIS Pro session (12/11/2026, 15.8 minutes)

Run with `e2e_test/exploratory.py` (ARTEMIS **Pro** profile, `gemini-3.5-flash-lite`), on the emulator with the real Firebase project, the fixed build and the customer account. No script: two charters back to back, each telling the agent which area to explore and how to try to break it.

| Charter | Session | Start | Length | What the agent did |
|---|---|---|---|---|
| 1. First-time student | 40362d6b | 14:18 | 6.0 min, 20 steps | Menu and categories, item detail with options and a kitchen note full of special characters, quantity 2, cart, BBSTUDENT voucher, system Back, search, switching to Kiosk Q9 · Tầng 4 (warning dialog, cart emptied) and back |
| 2. Returning student | d3cb110d | 14:24 | 9.7 min, 37 steps | Orders tab (active orders, enlarged QR, history, order detail, receipt export), Profile (student profile with phone "abc" then a valid number, default payment method, Firebase demo area: Remote Config fetch, notification centre, export and upload, My files), notification settings |

Evidence: `evidence/artemis/exploratory-2026-11-12.json` (status, every step summary and the agent's notes for both charters) and the screen recordings `C:/src/artemis/traces/web_1794467925_40362d6b_PASS_2026-11-12T14-18-50/recording.mp4` and `web_1794468289_d3cb110d_PASS_2026-11-12T14-24-53/recording.mp4`. An earlier attempt at 14:02 (session ce896752) is not counted: the API key ran out of its daily quota and the agent spent most of the time waiting.

The Pro profile ends through its planner and checker, not with a final report, and the agent's notes kept their "Issues" heading empty. The issues below were read from its step log; each was then repeated by hand.

| Charter, step | Issue | Severity | Handled |
|---|---|---|---|
| 2, steps 13, 14, 33 | Order detail (S12) offers "Xuất biên nhận PDF" for a **cancelled, unpaid** order (#4DZ25H, "Đã huỷ", "Tiền mặt tại kiosk · Chưa thanh toán"); the receipt was generated (9 KB) and listed under "Tệp của tôi". `OrderDetailViewModel._export` does not look at the status, so a "receipt" exists for an order that was never paid. | Medium | Open: hide the button for cancelled orders, or print "ĐÃ HUỶ" on the PDF (to decide with P2) |

Looked like issues but were not: "Cài đặt thông báo" still showed "Đang tải cài đặt..." when the agent left after one step, but by hand it loads in under a second; in charter 1 step 7 the agent aimed at the keyboard area for "Xem giỏ", but by hand the keyboard closes after "Thêm vào giỏ" and the snackbar action is reachable; the phone field kept "abc" because the agent's second entry did not reach the field (the validation message "Số điện thoại gồm 10 chữ số, bắt đầu bằng 0." was right); the toast "Shell pasted from your clipboard" comes from ARTEMIS pasting non-ASCII search text.

Seen working: validation on the student profile, the kiosk switch warning and emptied cart, BBSTUDENT applied to a 44.000đ cart, the enlarged QR with the code in two groups, order history and detail, saving the default payment method, Remote Config "Lấy giá trị mới", the notification centre, export and upload.

### 4.2 Earlier manual session (10/11/2026)

**Session of 10/11/2026, about 10 minutes, by P2 with Claude Code, on an Android emulator (Pixel 7, API 36) with the fake-data build** (`flutter run -t dev/main_dev.dart --dart-define=DEV_SIGNED_IN=true --dart-define=DEV_SEED=true`, once as `DEV_ROLE=user` and once as `DEV_ROLE=staff`), driven with `adb` taps and screenshots. This is **not** the ARTEMIS Pro-profile session the handout asks for (that is 4.1); it is kept for its findings. Charter: text at 200 % (Home, Menu, Orders, Profile, and the seller tabs), many fast taps, odd search input, the receipt export.

| Time (device clock) | Bug or problem found | Severity | Handled |
|---|---|---|---|
| 12:52 | Text at 200 %: the Orders tab "Đang xử lý (2)" fades out at the closing bracket (S08, P1) | Low | Open |
| 12:52 | Text at 200 %: the kiosk status line is cut with "…" on Home ("Sẵn sàng · chờ 5–7 ph…") and on the Menu ("Mở · ch…"), so the wait time cannot be read | Low | Open |
| 12:54 | The search's empty state says "xem các món bán chạy" but offers only three search suggestions | Low | Open |
| 12:54 | Orders: the badge "Đã nhận đơn" (placed) sits above the line "Chờ kiosk nhận đơn" (not accepted yet), and the history says "Đã nhận" for a picked-up order; the three read as contradictory | Low (wording from Figma) | Open, to decide with P1 |
| 12:58 | K10 at 200 %: the labels "Giờ mở cửa" and "Giờ đóng cửa" are cut ("Giờ mở c…") in two half-width fields | Low | Fixed: the two fields stack when the text is 1.5 times larger or more; widget test added |

What was tried and showed no problem: 14 fast taps on "+" give a quantity of 14 and the cart total 546.000đ (14 × 39.000đ); two quick taps on "Xuất biên nhận PDF" produce one receipt in the list; a search for "tacos%20%26%2…" says nothing was found and shows the term; the seller Orders, Menu and Shop tabs at 200 % show no overflow in a debug build. Not tried: airplane mode (the fake build does not use the network), rotation, a real push notification.
