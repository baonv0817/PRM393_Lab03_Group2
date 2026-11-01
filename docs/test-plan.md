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

## 2. Test cases

| ID | Flow | Precondition | Instruction (summary) | Expected result | Type | Result |
|---|---|---|---|---|---|---|
| TC-01 | Sign-in | App installed, signed out | Open the app, tap Google sign-in ("Đăng nhập bằng Google"), pick the test account | The Home screen shows with 4 tabs in the bottom bar; report the selected kiosk name | Native | Not run |
| TC-02 | Sign-out | Signed in | Open Profile ("Cá nhân"), tap Sign out ("Đăng xuất") | The sign-in screen shows; pressing Back does not return to Home | Happy path | Not run |
| TC-03 | F1 quick order | Signed in, empty cart | On Home tap + on the first item, View cart ("Xem giỏ"), Continue to checkout, keep MoMo, Confirm ("Xác nhận"), confirm at the gateway | The Order tracking screen shows; report the pickup code and the total | Happy path | Not run |
| TC-04 | F2 wrong voucher | Cart with 1 item | In the cart tap the voucher field, choose an expired voucher | An expired-voucher error shows right in the cart; report that the total is unchanged | Error path | Not run |
| TC-05 | F3 payment error | Cart with 1 item | Checkout, confirm, at the gateway tap Decline ("Từ chối"), choose Cash at the kiosk ("Tiền mặt tại Kiosk") | The error screen keeps the cart; after choosing cash there is a pay-at-counter order; report the order status | Error path | Not run |
| TC-06 | Search with no results | Signed in | Search for a term that is not on the menu | The empty-state screen shows with a message; report result count = 0 | Error path | Not run |
| TC-07 | Main tabs | Signed in | Tap Menu ("Thực đơn"), Orders ("Đơn hàng"), Profile ("Cá nhân"), Home ("Trang chủ") in turn | Each tab shows the right root screen title | Happy path | Not run |
| TC-08 | Item and order detail screens | At least 1 order | Open the detail of an item, then the detail of an order in the history | Report the item name and price; report the order code and status | Happy path | Not run |
| TC-09 | Export and upload | At least 1 order | Open Profile ("Cá nhân"), Firebase demo area ("Khu demo Firebase"), tap Export and upload ("Xuất và tải lên") | Progress shows, then the download URL; the file appears under My files ("Tệp của tôi"); report the file size | Happy path | Not run |
| TC-10 | Remote Config value | Default values | Open Home, count the items in the "quick under 5 minutes" section | Report an item count equal to the current `quick_items_limit` value | Happy path | Not run |
| TC-11 | Open a push notification | App in background, permission granted | Tap the notification in the system notification shade | The app opens the screen related to the notification | Native | Not run |
| TC-12 | Seller accepts and delivers an order | 1 pending order, signed in with the staff role | Open the order, Accept, mark Ready, Scan the code and confirm delivery | The order status changes to delivered; report the order code | Happy path | Not run |
| TC-13 | Analytics event logged | Analytics debug on | Run TC-03 then check Logcat | A `purchase` event with the right parameters is present | Happy path | Not run |

The instructions above are summaries; the full versions are in `e2e_test/`. Everyone adds cases for the screens they own (if section 7 of the handout is not covered).

## 3. Run results (fill in after running)

| Test | Runs | Pass rate | Average time | Notes (flaky, failures, skipped) |
|---|---|---|---|---|
| | | | | |

Command to run the suite: `[fill in]`. The trace or screenshots of every run are kept in `evidence/artemis/`.

## 4. Exploratory session (Pro profile, 15 to 30 minutes)

| Time | Bug or problem found | Severity | Handled |
|---|---|---|---|
| | | | |
