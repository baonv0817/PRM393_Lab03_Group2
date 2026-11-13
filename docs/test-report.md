# Test report (final assignment)

Handout section 9 and the rubric row "Tests: ARTEMIS, rules and web checklist run with evidence", plus "≥ 3 review
findings with decisions". Everything below ran against the **deployed system** (web admin at
https://breakbite-1315b.web.app, the real Firebase project `breakbite-1315b`) unless a line says Emulator.

| Test | Minimum (handout) | Result | Section |
|---|---|---|---|
| Security Rules (Emulator) | An allowed and a denied case per role per collection; all pass | **172/172 pass**, Appendix B matrix of 80 cases (R-01 … R-80) over 12 collections and 3 roles | [1](#1-security-rules-emulator) |
| Web admin checklist | Main action of each screen, role rejection, empty and error states; a screenshot each | W01–W05 done on the deployed site; [list below](#2-web-admin-checklist) | [2](#2-web-admin-checklist) |
| Mobile E2E (ARTEMIS) | Every Lab 2 flow, the mobile steps of the cross-role flow, the AI feature; 3 runs each with pass rate | **3/3 for every case**: Lab 2 flows F1, F2, F3, F6, F8, F9 and the seller flow; AI 3/3 and 3/3; cross-role mobile steps 3/3 and 3/3 | [3](#3-mobile-e2e-artemis) |
| Cross-role flow | End to end on the deployed system, 3 times | **3 of 3** worked: 1.22 s, 1.09 s, 1.14 s from the web click to the phone; announcement flow 1.13 s | [4](#4-cross-role-flow-3-times-on-the-deployed-system) |
| AI code review | At least 3 findings with decisions | **10 findings**, 9 fixed in 3 pull requests, 1 not fixed with a reason | [5](#5-ai-code-review-of-the-new-code) |

## 1. Security Rules (Emulator)

`firebase/tests/rules.test.mjs`, run with `npm test` in `firebase/tests` (Firestore and Storage Emulator, Java 21,
`@firebase/rules-unit-testing`). Every case signs in as a customer (`user`), a staff member of kiosk `k1` (`staff`) or an
admin, and expects the write or read to be allowed or denied.

| Run | Tests | Pass | Fail | Evidence |
|---|---|---|---|---|
| 12/11/2026 23:00, `main` after the web admin and the inbox (#105, #106) | 168 | 168 | 0 | [`rules-run-2026-11-12.log`](../evidence/rules/rules-run-2026-11-12.log) |
| 13/11/2026, `main` after the system pages (#113, adds `audit_logs` and the admin rule for `users`) | 172 | 172 | 0 | [`rules-run-2026-11-13.log`](../evidence/rules/rules-run-2026-11-13.log), [`rules-run-2026-11-13.png`](../evidence/rules/rules-run-2026-11-13.png) |

The rules deny by default (a final `match /{document=**} { allow read, write: if false; }`, tested under "unknown
collections"), have no
`if true`, check data shape (`validNewOrder`, `validMenuItem`, `validAnnouncement`, …) and status transitions
(`validTransition`, `stepTimeOk`). The deployed rules are the tested ones (released 13/11/2026 with
`firebase deploy --only firestore:rules,firestore:indexes`).

### Appendix B matrix

The 80 cases of the `MATRIX` array (the test "Appendix B matrix (final assignment)"), each with an allowed and a denied
case for every role on every collection. All passed in both runs.

| ID | Collection | Role | Operation | Expected | Result |
|---|---|---|---|---|---|
| R-01 | users | user | read own profile | Allowed | Pass |
| R-02 | users | user | update own role to admin | Denied | Pass |
| R-03 | users | staff | update own display name | Allowed | Pass |
| R-04 | users | staff | read a customer profile | Denied | Pass |
| R-05 | users | admin | change a user role to staff | Allowed | Pass |
| R-06 | users | admin | delete a user | Denied | Pass |
| R-07 | notifications | user | read own inbox item | Allowed | Pass |
| R-08 | notifications | user | read another user inbox | Denied | Pass |
| R-09 | notifications | staff | create own inbox item | Allowed | Pass |
| R-10 | notifications | staff | write into a customer inbox | Denied | Pass |
| R-11 | notifications | admin | create own inbox item | Allowed | Pass |
| R-12 | notifications | admin | read a customer inbox | Denied | Pass |
| R-13 | kiosks | user | read a kiosk | Allowed | Pass |
| R-14 | kiosks | user | close a kiosk | Denied | Pass |
| R-15 | kiosks | staff | close own kiosk | Allowed | Pass |
| R-16 | kiosks | staff | close another kiosk | Denied | Pass |
| R-17 | kiosks | admin | create a kiosk | Allowed | Pass |
| R-18 | kiosks | admin | delete a kiosk | Denied | Pass |
| R-19 | slots | user | book a slot (+1) | Allowed | Pass |
| R-20 | slots | user | create a slot | Denied | Pass |
| R-21 | slots | staff | create a slot at own kiosk | Allowed | Pass |
| R-22 | slots | staff | create a slot at another kiosk | Denied | Pass |
| R-23 | slots | admin | change a slot capacity | Allowed | Pass |
| R-24 | slots | admin | delete a slot | Denied | Pass |
| R-25 | menu_items | user | read the menu | Allowed | Pass |
| R-26 | menu_items | user | change a price | Denied | Pass |
| R-27 | menu_items | staff | archive an item of own kiosk | Allowed | Pass |
| R-28 | menu_items | staff | archive an item of another kiosk | Denied | Pass |
| R-29 | menu_items | staff | archive with a non-boolean value | Denied | Pass |
| R-30 | menu_items | admin | create an item | Allowed | Pass |
| R-31 | menu_items | admin | delete an item | Denied | Pass |
| R-32 | vouchers | user | read a voucher | Allowed | Pass |
| R-33 | vouchers | user | create a voucher | Denied | Pass |
| R-34 | vouchers | staff | read a voucher | Allowed | Pass |
| R-35 | vouchers | staff | switch a voucher off | Denied | Pass |
| R-36 | vouchers | admin | create a voucher | Allowed | Pass |
| R-37 | vouchers | admin | delete a voucher | Denied | Pass |
| R-38 | carts | user | read own cart | Allowed | Pass |
| R-39 | carts | user | read another cart | Denied | Pass |
| R-40 | carts | staff | write own cart | Allowed | Pass |
| R-41 | carts | staff | read a customer cart | Denied | Pass |
| R-42 | carts | admin | write own cart | Allowed | Pass |
| R-43 | carts | admin | read a customer cart | Denied | Pass |
| R-44 | orders | user | place a pending order | Allowed | Pass |
| R-45 | orders | user | place an order already preparing | Denied | Pass |
| R-46 | orders | user | approve own order | Denied | Pass |
| R-47 | orders | staff | approve pending → preparing | Allowed | Pass |
| R-48 | orders | staff | reject pending → cancelled with a reason | Allowed | Pass |
| R-49 | orders | staff | reject without a reason | Denied | Pass |
| R-50 | orders | staff | approve an order of another kiosk | Denied | Pass |
| R-51 | orders | admin | read an order of any kiosk | Allowed | Pass |
| R-52 | orders | admin | delete an order | Denied | Pass |
| R-53 | reviews | user | review own delivered order | Allowed | Pass |
| R-54 | reviews | user | review a pending order | Denied | Pass |
| R-55 | reviews | staff | read the reviews (dashboard average) | Allowed | Pass |
| R-56 | reviews | staff | write a review for a customer | Denied | Pass |
| R-57 | reviews | admin | read the reviews | Allowed | Pass |
| R-58 | reviews | admin | delete a review | Denied | Pass |
| R-59 | incidents | user | read own incident | Allowed | Pass |
| R-60 | incidents | user | resolve own incident | Denied | Pass |
| R-61 | incidents | staff | take an incident of own kiosk | Allowed | Pass |
| R-62 | incidents | staff | take it from another kiosk | Denied | Pass |
| R-63 | incidents | admin | reject an incident with a note | Allowed | Pass |
| R-64 | incidents | admin | delete an incident | Denied | Pass |
| R-65 | reports | user | read own receipt metadata | Allowed | Pass |
| R-66 | reports | user | save metadata as someone else | Denied | Pass |
| R-67 | reports | staff | save own receipt metadata | Allowed | Pass |
| R-68 | reports | staff | read a customer receipt | Denied | Pass |
| R-69 | reports | admin | save own receipt metadata | Allowed | Pass |
| R-70 | reports | admin | edit a receipt | Denied | Pass |
| R-71 | announcements | user | list published announcements | Allowed | Pass |
| R-72 | announcements | user | read a draft | Denied | Pass |
| R-73 | announcements | staff | read a published announcement | Allowed | Pass |
| R-74 | announcements | staff | publish an announcement | Denied | Pass |
| R-75 | announcements | admin | publish an announcement | Allowed | Pass |
| R-76 | announcements | admin | archive an announcement | Allowed | Pass |
| R-77 | announcements | admin | publish a 121-character title | Denied | Pass |
| R-78 | announcements | admin | publish with an unknown field | Denied | Pass |
| R-79 | announcements | admin | change the author | Denied | Pass |
| R-80 | announcements | admin | delete an announcement | Denied | Pass |

## 2. Web admin checklist

Taken on 12–13/11/2026 at https://breakbite-1315b.web.app (1440 × 900, Chromium), signed in as an admin of the real
project; files in [`evidence/web/`](../evidence/web/). "Offline" is the browser set offline after the page loaded.

| Screen | Main action | Role rejection | Empty state | Error state |
|---|---|---|---|---|
| **W01** Sign-in | Google or e-mail sign-in, then the rail of the signed-in role ([`W01-sign-in.png`](../evidence/web/W01-sign-in.png), signed in: [`W03-review-queue.png`](../evidence/web/W03-review-queue.png)) | A customer account is signed out with "Tài khoản … là tài khoản khách hàng. Trang quản trị chỉ dành cho nhân viên kiosk và quản trị viên; khách hàng đặt món trên ứng dụng BreakBite." ([`W01-role-rejection.png`](../evidence/web/W01-role-rejection.png)) | Not applicable (no data); while the session is checked: "Đang kiểm tra đăng nhập…" | A wrong password says so under the form ([`W01-error.png`](../evidence/web/W01-error.png)) |
| **W02** Thực đơn (management of `menu_items`) | List with filters and counts ([`W02-menu.png`](../evidence/web/W02-menu.png)), "Thêm món" form ([`W02-add-dialog.png`](../evidence/web/W02-add-dialog.png)), edit, archive and restore | Staff change only their own kiosk's items (R-27 allowed, R-28 denied); a customer cannot change a price (R-26) and never reaches the page (W01) | Search with no match: "Không có món nào khớp "pizza hai san"." ([`W02-empty-search.png`](../evidence/web/W02-empty-search.png)) | Offline: "Mất kết nối mạng. …" with "Thử lại" ([`W02-error-offline.png`](../evidence/web/W02-error-offline.png)) |
| **W03** Duyệt đơn (review queue) | A new order from the phone appears; approve with a time or reject with a reason ([`W03-selected-QLOTIR.png`](../evidence/web/W03-selected-QLOTIR.png), [`W03-approved-QLOTIR.png`](../evidence/web/W03-approved-QLOTIR.png), [`W03-reject-dialog.png`](../evidence/web/W03-reject-dialog.png)) | Staff of another kiosk cannot approve (R-50); customers cannot approve their own order (R-46) | A kiosk with no pending order: "Không có đơn nào chờ duyệt." ([`W03-empty.png`](../evidence/web/W03-empty.png)) | Offline ([`W03-error-offline.png`](../evidence/web/W03-error-offline.png)) |
| **W04** Thống kê (dashboard) | Five figures from aggregation queries (`count()`, `sum('totalVnd')`, `average('prepSeconds')`) and the orders-per-hour chart, today and 7 days ([`W04-dashboard.png`](../evidence/web/W04-dashboard.png), [`W04-dashboard-7days.png`](../evidence/web/W04-dashboard-7days.png)) | Staff read only their own kiosk's orders (tests "orders: read"); an admin reads any kiosk (R-51) | A kiosk with no order today: "Hôm nay kiosk chưa có đơn nào." ([`W04-empty.png`](../evidence/web/W04-empty.png)) | Offline ([`W04-error-offline.png`](../evidence/web/W04-error-offline.png)) |
| **W05** Thông báo (announcement form) | Write and publish; the list shows it "Đã đăng"; archive ([`W05-form-filled.png`](../evidence/web/W05-form-filled.png), [`W05-published.png`](../evidence/web/W05-published.png), [`announcement-archived-web.png`](../evidence/cross-role/announcement-archived-web.png)); the phone's inbox shows it in 1.13 s (section 4) | Only admins write (R-75 allowed, R-74 staff denied); staff see the published list only | "Chưa có thông báo nào." ([`W05-empty.png`](../evidence/web/W05-empty.png)) | Offline ([`W05-error-offline.png`](../evidence/web/W05-error-offline.png)) |

The system pages added on 13/11 for admins (users, kiosks, slots, vouchers, every order, incidents, system statistics,
audit log, [#113](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/113)) go beyond the four required screens and
are not part of this checklist; their view models have their own tests in `web/test/system/`.

**Problems the checklist found and fixed** (each retested on the deployed site):

| Found | Problem | Fix |
|---|---|---|
| W02 offline | Firestore answered from an empty cache, so "Thực đơn" said "Kiosk chưa có món nào" while the kiosk has 10 items | The shell shows the offline error state on every screen ([#110](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/110)) |
| W03 kiosk picker | An admin who picked another kiosk while "Duyệt đơn" was open kept the previous kiosk's queue | Each screen's view model is keyed by the kiosk ([#111](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/111)) |
| Deploy | Hosting refused a folder outside `firebase/`; then a one-hour cache kept the previous build | `firebase/web-build` and `no-cache` for code ([#109](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/109), [#112](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/112)) |

## 3. Mobile E2E (ARTEMIS)

Every case is a pytest function in [`e2e_test/`](../e2e_test/) that sends one instruction to Google ARTEMIS (Flash
profile, `gemini-3.5-flash-lite`) on the Android emulator `BB_Pixel7` with the real project, and checks the values the
agent reports. Runs, pass rates, trace ids and the cause of every failure are in
[`test-plan.md` section 3](test-plan.md#3-run-results); JUnit files are `evidence/artemis/run-N.xml`.

| Flow (handout) | Cases | Runs | Pass rate |
|---|---|---|---|
| Lab 2 F1, quick order from Home (MoMo, `purchase` event in Logcat) | TC-03 | run-12 to 14 | 3/3 |
| Lab 2 F2, voucher and its error path | TC-04 | run-31 to 33 | 3/3 |
| Lab 2 F3, payment error then cash | TC-05 | run-22 to 24 | 3/3 (an app bug was found and fixed before, P-01) |
| Lab 2 seller flow, accept to handover | TC-12 | run-37 to 39 | 3/3 |
| Sign-in, sign-out, search, tabs, details, export, Remote Config | TC-01, 02, 06, 07, 08, 09, 10 | runs 1 to 8, 34 to 36 | 3/3 each |
| AI feature, a dish photo fills K14 | TC-40 | run-43, 44, 46 | 3/3 |
| AI feature, a photo that is not food | TC-41 | run-43 to 45 | 3/3 |
| Cross-role, mobile steps: the web approves | TC-42 | run-47 to 49 | 3/3 |
| Cross-role, mobile steps: the web rejects with a reason | TC-43 | run-47 to 49 | 3/3 |
| Lab 2 F6, favorite an item from its page and add it from S13 | TC-32 | run-61 to 63 | 3/3 |
| Lab 2 F6, quick reorder from Home (S14) | TC-33 | run-50 to 52 | 3/3 |
| Lab 2 F8, order ready → inbox → pickup code (S19, S20) | TC-34 | run-50 to 52 | 3/3 |
| Lab 2 F9, sold-out item → replacements (S22) | TC-30 | run-53 to 55 | 3/3 |

Runs not counted: a run stopped by the test setup and not by the app (the emulator not responding under load, the ARTEMIS model answering 503 or out of quota, an older build after an emulator restart) was run again; the causes are in [`test-plan.md` sections 3.3 to 3.6](test-plan.md#3-run-results) and every run file is in `evidence/artemis/`.

TC-42 and TC-43 ([`test_cross_role.py`](../e2e_test/test_cross_role.py)): the agent orders a coffee with cash and waits
on "Theo dõi đơn"; meanwhile the test plays the kiosk, writing to the order exactly what W03 writes when it approves or
rejects; the agent reports the status line and the highlighted step, and the test checks that they changed without
reopening the screen ("Dự kiến sẵn sàng …" and "Đang làm", or "Đơn đã huỷ: Hết nguyên liệu").

## 4. Cross-role flow, 3 times on the deployed system

Details, sequence diagrams, rules and evidence: [`cross-role-flow.md`](cross-role-flow.md). Phone recorded with
`screenrecord --bugreport` (device time on every frame), web click time from the browser, clock offset measured.

| Run | Customer (phone) | Staff / admin (web) | Phone shows | Time |
|---|---|---|---|---|
| 1 | Order #QLOTIR, cash | Approve, 10 min | "Đang làm · Dự kiến sẵn sàng 00:01" | 1.22 s |
| 2 | Order #25RPEH, cash | Reject, "Quầy sắp đóng cửa" | "Đã huỷ · Đơn đã huỷ: Quầy sắp đóng cửa" | 1.09 s |
| 3 | Order #S7SWIR, cash | Approve, 15 min | "Đang làm · Dự kiến sẵn sàng 00:12" | 1.14 s |
| Flow 2 | — | Admin publishes an announcement | Top of the inbox (S19), "Thông báo từ BreakBite" | 1.13 s |
| Flow 2 | — | Admin archives it | Gone from the inbox | 0.81 s |

The inbox got a message for each run ([`inbox-after-3-runs.png`](../evidence/cross-role/inbox-after-3-runs.png)). Run 2
found that a rejected cash order was promised a refund; fixed in
[#114](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/114).

## 5. AI code review of the new code

Claude Code `/code-review` (level medium) on 13/11/2026 over the code written for the final assignment: the web admin,
the inbox and access rules in `packages/core`, and the AI feature. Output, unedited:
[`evidence/code-review/final/review-2026-11-13.md`](../evidence/code-review/final/review-2026-11-13.md). Every finding was
checked against the code by hand; all ten were real.

| ID | Kind | Finding | Decision | Why / fix |
|---|---|---|---|---|
| CR-F01 | bug | The AI answer overwrote fields staff typed while it was running; Save stayed enabled | **Fixed** | Typed fields are kept; Save waits ([#116](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/116), commit `0bffba2`) |
| CR-F02 | bug | W05 "Đăng" / "Lưu trữ" failures were silent; double clicks possible | **Fixed** | Snackbar with the result; buttons disabled while writing ([#117](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/117), `88a5d3d`) |
| CR-F03 | bug (security) | The background push handler wrote to Firestore without App Check | **Fixed** | App Check activated in that isolate ([#118](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/118), `42db438`) |
| CR-F04 | bug (UX) | An admin read "Chưa có kiosk nào" while kiosks loaded; a query error was swallowed | **Fixed** | Loading and error (with retry) states ([#117](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/117), `8755a83`) |
| CR-F05 | security | A release build given a debug token used the App Check debug provider and shipped the token | **Fixed** | Debug provider only in debug builds ([#118](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/118), `55b0d7d`) |
| CR-F06 | bug | The photo was uploaded before the duplicate-name check, leaving an orphan image | **Fixed** | Name checked first ([#116](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/116), `2c997f9`) |
| CR-F07 | performance | "Đọc hết" stored unread announcements one after another | **Fixed** | `Future.wait` ([#118](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/118), `45b4df0`) |
| CR-F08 | correctness (edge case) | `watchPublished` limits to 50 before filtering by kiosk | **Won't fix** | A campus kiosk publishes a few announcements a week, far from 50; a correct fix needs two queries (every kiosk, and this kiosk) merged on the client. Recorded as a known limit |
| CR-F09 | maintainability | The K14 limits were declared twice and clipped twice | **Fixed** | One source in `MenuItemSuggestion` ([#116](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/116), `dd2626d`) |
| CR-F10 | maintainability | The account label was written twice (web and mobile messages) | **Fixed** | `AppUser.label` ([#117](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/117), `320bab3`) |

Kinds: 5 bugs, 2 security, 1 performance, 2 maintainability. After the fixes: `mobile` 814/814, `web` 32/32 tests
(both on the fix branches), and 818/818 and 84/84 on `main` after #113.
