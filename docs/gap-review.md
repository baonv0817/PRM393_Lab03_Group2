# Gap review: Lab 2 and Lab 3 scope

Final assignment, stage 1 (handout section 5) and the rubric row "Lab 2 and Lab 3 scope finished: every Lab 2 flow and Lab 3 requirement works; gap review closed". Issue #97.

Checked on 12/11/2026 against the documents and the `evidence/` folder of this repository. Nothing was rerun for this review: every status points to the document, test run or screenshot that proves it. When no proof was found, the row says so and is marked "To verify".

## 1. How to read this

| Status | Meaning |
|---|---|
| **Works** | A document, a test run or a screenshot in the repository shows it working. The evidence column links it |
| **Fixed** (when, how) | It was broken or missing and a fix is recorded. The row says when, what changed and where the proof is |
| **Still missing** (owner) | Not done, or done but known to fail. Listed again in section 7 with an owner and a plan |
| **To verify** (owner) | It may work, but no evidence was found in the repository. Listed in section 7 |

- Owners are written as the issue and the GitHub handle (for example `#97 baodhg`), so this file notifies nobody. P1 to P5 are the Lab 3 roles in `ASSIGNMENTS.md`.
- ARTEMIS results are copied from `test-plan.md`: "3/3" means 3 passing runs out of 3.

## 2. Lab 2 flows

[design-traceability §3][dt-flows] lists four flows. The tests and deviation D28 name three more (F6, F8, F9), so they are added here. F4, F5 and F7 are not named anywhere in this repository (V04 in section 7).

| Flow | Screens | Status | Evidence |
|---|---|---|---|
| F1 Quick order from Home. Error: payment declined at the gateway → S06-ERR | S02, S02-ADDED, S05, S06, S06-GATEWAY, S07 | Works | TC-03 3/3 (run-12 to 14): each run places a MoMo order and Logcat shows `purchase` ([test-plan §3.1][tp31]). Real phone, real Firebase: [`evidence/p1/`](../evidence/p1/) (`S02` to `S07`). Full-app test at 360 and 412 dp: [`ordering_flows_test.dart`][flow-order] |
| F2 Customize an item and use a voucher. Error: expired code → S05-VOUCHER-ERR | S03, S04, S05, S29 | Works | TC-04 3/3 (run-31 to 33). The earlier failures came from the ARTEMIS typing tool (E-01) and from instructions, not from the app ([§3.1][tp31], [§3.3][tp33]). [`S03`](../evidence/p1/S03.png), [`S04`](../evidence/p1/S04.png), [`S29`](../evidence/p1/S29.png), [`S05-VOUCHER`](../evidence/p1/S05-VOUCHER.png), [`S05-VOUCHER-ERR`](../evidence/p1/S05-VOUCHER-ERR.png) |
| F3 Payment error, keep the cart. Alternative: cash at the kiosk, then cancel | S06-ERR, S07-CASH, S07-DIALOG, S10 | **Fixed** (12/11/2026, P-01): the screen stayed on "Thanh toán chưa thành công" after a cash order was created; `CheckoutScreen._confirm` and `GatewayScreen._pay` now read the router before the `await` | Bug found by TC-05 (run-15 to 17). Fixed build: 3/4 (run-21 failed on host load, explained) ([§3.1][tp31], P-01 in [§3.3][tp33]). [`S06-ERR`](../evidence/p1/S06-ERR.png), [`S06-ERR-CASH`](../evidence/p1/S06-ERR-CASH.png), [`S07-CASH`](../evidence/p1/S07-CASH.png), [`S07-DIALOG`](../evidence/p1/S07-DIALOG.png), [`p2-real/S10`](../evidence/p2-real/S10.png) |
| Seller: from accepting an order to handover. Error: invalid code → K05-ERR; alternative K06-CASH | K01 to K06, K02-EMPTY, K05-ERR, K06-CASH, K12 | Works | TC-12 3/3 (run-37 to 39), three orders handed over ([§3.1][tp31]). Real Firebase: [`evidence/p4-real/`](../evidence/p4-real/) (K02, K04, K05 with a valid code and the cash to collect, K05 with the camera refused). K05-ERR and K12 are proven only by [`seller_orders_flow_test.dart`][flow-seller] (V03) |
| F6 Favorite an item, quick reorder | S04 (heart), S13, S02 → S14 → S05 | To verify | Only the full-app tests "F6 …" and "F6 reorder …" in [`p5_flows_test.dart`][flow-p5]. No device screenshot and no ARTEMIS case found |
| F8 Order ready → inbox → pickup code | S19, S20 | To verify | Full-app test "F8 …" in [`p5_flows_test.dart`][flow-p5]. On the real build the parts work one by one: push saved in S19 ([`fcm/5-inbox`](../evidence/fcm/5-inbox.png)), push tap opens the order ([`fcm/3-background-tap-opens-order`](../evidence/fcm/3-background-tap-opens-order.png)), S20 ([`p2-real/S20`](../evidence/p2-real/S20.png)). The whole path on a device has no evidence |
| F9 Sold-out item → alternatives | S03, S22 | Works | Real phone: [`S03-SOLDOUT`](../evidence/p1/S03-SOLDOUT.png), [`S22`](../evidence/p1/S22.png); D28. ARTEMIS TC-30 is written but was not run |

Count: 4 works, 1 fixed, 0 still missing, 2 to verify.

## 3. Lab 2 screens not covered by a flow above

| Screens | What | Status | Evidence |
|---|---|---|---|
| S01, S26 (S26-OTP dropped, D01) | Onboarding, Google sign-in, cancelled sign-in | Works | TC-01 3/3 with the native account chooser ([§3.1][tp31]); [`auth/1-signed-out`](../evidence/auth/1-signed-out.png), [`2-signed-in`](../evidence/auth/2-signed-in.png), [`3-cancelled`](../evidence/auth/3-cancelled.png), [`4-console-users`](../evidence/auth/4-console-users.png) |
| S15 | Profile and sign-out | Works; the order count: **Fixed** (G01, 13/11/2026) | TC-02 3/3. "Không tải được số đơn" was seen on 12/11 while the project still ran the rules of 01/11; after the current rules were deployed (13/11) the count shows ("34 đơn đã đặt", [`gap/S15-order-count-2026-11-13.png`](../evidence/gap/S15-order-count-2026-11-13.png)) |
| S02, S03, S08, S15 | The four tabs | Works | TC-07 3/3 ([§3.2][tp32]) |
| S04, S12 | Item detail, order detail | Works | TC-08 3/3 ([§3.2][tp32]) |
| S28, S28-EMPTY | Search, no result | Works | TC-06 3/3 ([§3.2][tp32]). The S28-EMPTY row of [design-traceability §1][dt-s] now says "Done" (G10) |
| Firebase demo area (D08) | Export and upload, Remote Config values, Crashlytics tests | Works | TC-09 3/3, TC-10 3/3; [`evidence/storage/`](../evidence/storage/), [`evidence/remote-config/`](../evidence/remote-config/), [`evidence/crashlytics/`](../evidence/crashlytics/) |
| S12 receipt (T43) | PDF receipt of one order | Works; the receipt of a cancelled, unpaid order: **Fixed** (G02, 13/11/2026) | [`p2-real/S12-receipt`](../evidence/p2-real/S12-receipt.png). The Pro session found it ([test-plan §4.1][tp41]); the button is now hidden for a cancelled unpaid order and the export refuses it; a paid order that was cancelled keeps its receipt ([PR #119](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/119)) |
| S09, S10, S11, S20, S23, S24 | Edit, cancelled order, history, pickup QR, review, incident | Works | Real Firebase run on 10/11/2026: [`evidence/p2-real/`](../evidence/p2-real/) (`S09` to `S24-sent`); full-app tests in [`ordering_flows_test.dart`][flow-order]. ARTEMIS TC-20 to TC-24 are written, not run |
| S16, S17 | Student profile, default payment method | Works | Pro session "Seen working" ([§4.1][tp41]); TC-16 3/4 and TC-15 1/3 were extra cases where the agent misread a snackbar ([§3.2][tp32]) |
| S18, S19 | Notification settings, notification center | Works | [`fcm/5-inbox`](../evidence/fcm/5-inbox.png); S18 opened in the Pro session and loads by hand ([§4.1][tp41]) |
| S13, S14 | Favorites, quick reorder | To verify | See F6 |
| S21, S27 | Closed kiosk on Home, kiosk picker | Works; opening hours follow the phone's clock: **Still missing** (G03) | [`p1/S21`](../evidence/p1/S21.png); [`tc14-warning-dialog`](../evidence/artemis/manual/tc14-warning-dialog.png), [`tc14-cart-emptied`](../evidence/artemis/manual/tc14-cart-emptied.png) (TC-14 1/3, the agent misread, [§3.2][tp32]). D35: "Ngoài giờ mở cửa" uses the phone's clock |
| S25, S29 | Pickup time, voucher picker | Works | [`p1/S25`](../evidence/p1/S25.png), [`p1/S29`](../evidence/p1/S29.png) |
| S30 | Offline cover | To verify | Only the full-app test "S30: offline covers the app …" in [`p5_flows_test.dart`][flow-p5]. No airplane-mode evidence on a device |
| K08, K09, K14, K15 | Menu management | Works | Real Firebase: [`p2-real/K08`](../evidence/p2-real/K08.png) to [`K15-saved`](../evidence/p2-real/K15-saved.png). TC-25, TC-26 written, not run |
| K10, K11 | Shop, shift statistics | Works; the "Âm báo đơn mới" switch is not built (D21): **Still missing** (G07) | [`p2-real/K10`](../evidence/p2-real/K10.png), [`K10-closed`](../evidence/p2-real/K10-closed.png), [`K11`](../evidence/p2-real/K11.png) |
| K13 | Customer incidents | Works | [`K13-incident`](../evidence/p4-real/K13-incident.png), [`K13-taken`](../evidence/p4-real/K13-taken.png), [`K13-rejected`](../evidence/p4-real/K13-rejected.png) |

## 4. Lab 3 requirements

One row per requirement of the Lab 3 handout (section numbers in brackets).

| # | Requirement | Status | Evidence |
|---|---|---|---|
| L01 | Every Lab 2 Final UI screen (≥ 8) and every Lab 2 flow, with its alternative and error path (§3) | Works for the screens (44 of 44 built); flows: section 2 | [design-traceability §1–2][dt-s]: every row "Done" except S26-OTP (dropped, D01) and S28-EMPTY (out of date, works by TC-06) |
| L02 | Design system in code: tokens in `ThemeData`, each Lab 2 component one widget with its states (§3, §5) | Works | design-traceability §4; tokens in `packages/core/lib/ui/core/theme/`, widgets in `packages/core/lib/ui/core/widgets/`; [`theme_test.dart`](../mobile/test/ui/core/theme_test.dart) (contrast), [`widget_catalog_test.dart`](../mobile/test/ui/core/widget_catalog_test.dart) |
| L03 | Keep the Lab 2 navigation; add sign-in and profile (§3) | Works | TC-07 (four tabs), TC-02 (Back does not return after sign-out); D03, D07 |
| L04 | Loading, empty and error states on every data screen (§3) | Works | [architecture.md §3][arch-rules] rule 3 (`ViewState`), checked by [`architecture_test.dart`][arch-test]; for example [`p1/S05-EMPTY`](../evidence/p1/S05-EMPTY.png) |
| L05 | Real data from the source named in the design; no mock data in the build (§3) | Works | Data-source column of [design-traceability][dt-s]; rule 7 (`lib/` never imports `dev/`), checked by [`architecture_test.dart`][arch-test] |
| L06 | Generate at least 1 file and upload it (§3) | Works (Cloudinary instead of Cloud Storage, approved by the lecturer) | TC-09 3/3; [`storage/1-progress`](../evidence/storage/1-progress.png) to [`5-firestore-reports`](../evidence/storage/5-firestore-reports.png); [README "Deviations"][readme-dev] |
| L07 | Firebase demo area on Profile (§3) | Works | D08; TC-09, TC-10; [`remote-config/3-after`](../evidence/remote-config/3-after.png) |
| L08 | Every design change recorded with a reason, and Figma updated (§3) | Recorded: Works (D01 to D36). Figma: **Still missing** (G08) | [design-traceability §5][dt-dev]: every row except D02 and D30 says "Figma updated: Not yet" |
| L09 | Versions pinned in `pubspec.yaml` and README (§3) | Works | README "Pinned versions" (Flutter 3.47.5, FlutterFire packages, ARTEMIS commit `351ca84…`) |
| L10 | MVVM with Provider; no SDK in widgets; no logic in `build()`; a state model per screen; injected services (§5) | Works | [architecture.md §3][arch-rules] and the MVVM check M1 to M5; [`architecture_test.dart`][arch-test] |
| L11 | `architecture.md`: folders, layer diagram, sequence diagram, ViewModel table, matching the code (§5) | Works; the monorepo layout: **Fixed** (G09, 13/11/2026) | [architecture.md §1][arch-folders] now shows `packages/core/`, `mobile/` and `web/`, the layer diagram covers both clients, §5 lists the web screens and §3 which rules each architecture test checks |
| L12 | Lab 2 accessibility checklist: contrast, 48 dp, 14 sp, 360 and 412 dp (§5) | Works; four low issues at 200 % text are open (G06) | `widget_catalog_test.dart` (T21 in `TASKS.md`); open items in [test-plan §4.2][tp42] |
| L13 | Authentication: Google, routing by auth state, sign-out clears data, cancel message (§6) | Works | [firebase-design §1][fd-auth]; [`evidence/auth/`](../evidence/auth/); TC-01, TC-02 |
| L14 | File storage: per-user path, progress, URL, rules (§6) | Works (Cloudinary, see L06) | [firebase-design §2][fd-storage]; `firebase/storage.rules` kept as the fallback; rules tests: [`firebase/README.md`](../firebase/README.md) (81/81 on 31/10/2026) and [PR #95][pr95] (168/168) |
| L15 | FCM: three app states, permission, list in the app, tap opens a screen (§6) | **Fixed** (10/11/2026): a tap on a closed app ended on Home; `PushRouter` now waits until the router leaves the splash | [`evidence/fcm/`](../evidence/fcm/) (`1-permission` to `5-inbox`, `4-terminated-tap-before-fix`, `4-terminated-tap-after-fix`); [`push_flow_test.dart`](../mobile/test/flows/push_flow_test.dart) |
| L16 | Analytics: ≥ 7 events with questions and parameters, every event in DebugView, user ID (§6) | Works for the 11 Lab 3 events (plus `reorder`) | [analytics-plan.md](analytics-plan.md); [`debugview-top-events`](../evidence/analytics/debugview-top-events.png), [`debugview-timeline`](../evidence/analytics/debugview-timeline.png) |
| L17 | Crashlytics: a non-fatal from a real path, a test crash, user ID and a custom key (§6) | Works | [`1-non-fatal`](../evidence/crashlytics/1-non-fatal.png), [`2-crash`](../evidence/crashlytics/2-crash.png), [`3-keys`](../evidence/crashlytics/3-keys.png) |
| L18 | Remote Config: ≥ 2 parameters change the app without a rebuild (§6) | Works | [`1-before`](../evidence/remote-config/1-before.png), [`2-console`](../evidence/remote-config/2-console.png), [`3-after`](../evidence/remote-config/3-after.png); TC-10 3/3 |
| L19 | Every service shows a message on its failure case (§6) | Works | "Failure handling" rows of [firebase-design.md](firebase-design.md); [`auth/3-cancelled`](../evidence/auth/3-cancelled.png). Offline on a device: To verify (S30, V03) |
| L20 | `test-plan.md`: flows mapped to screens, ≥ 10 cases with every field (§7) | Works | [test-plan §1–2][tp2]: 11 graded cases |
| L21 | Coverage: every Lab 2 flow with its error path, sign-in, main action, each tab, each detail, export, Remote Config, sign-out (§7) | Works for F1, F2, F3 and the seller flow; F6, F8, F9 have no ARTEMIS run (V01, V02) | "Graded suite" paragraph of [test-plan §2][tp2] |
| L22 | ≥ 1 error-path test and ≥ 1 native interaction (§7) | Works | Error path: TC-04, TC-05, TC-06. Native: TC-01 (system account chooser) |
| L23 | Exploratory session, Pro profile, 15 to 30 minutes, issues listed (§7) | Works | [test-plan §4.1][tp41]: 15.8 minutes; [`exploratory-2026-11-12.json`](../evidence/artemis/exploratory-2026-11-12.json) |
| L24 | pytest through the ARTEMIS SDK; assert on reported values; ≥ 3 runs each with pass rate; flaky tests explained (§7) | Works | [§3.1][tp31] (every graded case ≥ 3 runs), causes in [§3.3][tp33]; [`evidence/artemis/`](../evidence/artemis/) `run-1.xml` to `run-46.xml` |
| L25 | Semantics labels on key widgets (§7) | Works | `TASKS.md` T61: `TestId` on every screen S01 to S30 and K01 to K15 |
| L26 | Independent tests, a dedicated test account, keys in environment variables (§7) | Works | Test-plan introduction; `run_repeat.py --restart-app` ([§3.1][tp31]); [`e2e_test/README.md`](../e2e_test/README.md) |
| L27 | ≥ 1 test also checks its Analytics event (§7) | Works | TC-03: Logcat has `purchase` with `transaction_id` ([§3.1][tp31]) |
| L28 | `e2e_test/` with `conftest.py`, grouped by feature; run command and traces (§7) | Works | [`e2e_test/`](../e2e_test/) (`conftest.py`, `test_auth.py`, `test_order.py`, …); command and trace ids in [§3.1][tp31] |
| L29 | Run an AI review tool, preferably on a pull request; save its output (§8) | Works (scope: four folders on `main` at `2dc91ab`, not one pull request) | [`claude-code-review.md`](../evidence/code-review/claude-code-review.md) |
| L30 | ≥ 5 findings tied to lines, ≥ 2 kinds, a decision with a reason for each (§8) | Works | [code-review.md][cr]: 10 findings, 5 kinds (section 5 below) |
| L31 | ≥ 3 fixes, each in its own commit linked to its finding (§8) | Works | CR-02 to CR-06, five commits (section 5) |
| L32 | Every AI tool disclosed (§8, §9) | **Still missing** (partly, G11) | [README "AI tools used"][readme-ai] and code-review §1 still say "[the other members add theirs]" |
| L33 | README: topic, how to run the app and the tests, versions, AI tools, video link, deliverables map (§9) | **Still missing** (partly, G11) | README has the versions, the ARTEMIS commit, the video link and the map; "Team" and "How to run" are placeholders, and the commands predate the `mobile/` move |
| L34 | Repository layout, `firebase/storage.rules`, `remote-config-defaults.json`, `google-services.json` (§9) | Works (layout changed by the final assignment) | [`firebase/`](../firebase/); `mobile/android/app/google-services.json` (project `breakbite-1315b`) |
| L35 | No secrets committed (§9) | To verify (V08) | [README "Security"][readme-sec]; `.gitignore` covers `.env*` and `mobile/env/app_check.json`; no secret scan is recorded |
| L36 | Report (8 to 12 pages), slides (12 to 15), video (5 to 10 minutes) (§9) | Works | [`report/Lab03_SE193905.pdf`](../report/Lab03_SE193905.pdf), [`slides/Lab03_SE193905_slides.pdf`](../slides/Lab03_SE193905_slides.pdf), video link in [README](../README.md) (8 min 47 s) |
| L37 | Git history over time; console evidence from our own project (§11) | Project ID: Works. History: To verify (V09) | [`evidence/README.md`](../evidence/README.md) (project name in console screenshots). `TASKS.md` T00 noted on 01/11/2026 that only 3 of 5 members had commits |

Count: 37 requirements. 28 works, 1 fixed (L15), 4 still missing (L08 Figma part, L11, L32, L33), 2 to verify (L35, L37 history), and 2 that work with an open item listed in section 7 (L12, L21).

## 5. Lab 3 review findings

All ten findings of [code-review.md §2][cr] are closed: five fixed, four rejected with a reason, one accepted as a known limitation.

| ID | Kind | Finding (short) | Decision | Status | Evidence |
|---|---|---|---|---|---|
| CR-01 | security | The order total comes from cart prices, never from `menu_items` | Accepted, not fixed | Closed by decision: known limitation | [data-model §7][dm7] ("the rules cannot loop over `items[]`"); Lab 3 report §11 |
| CR-02 | bug | `upsertItem` of a new item overwrote an existing item | Accepted | Fixed | [`d6d8113`](https://github.com/baonv0817/PRM393_Lab03_Group2/commit/d6d8113) |
| CR-03 | bug | Incident `take()` and `resolve()` updated without a transaction | Accepted | Fixed | [`d1291a6`](https://github.com/baonv0817/PRM393_Lab03_Group2/commit/d1291a6) |
| CR-04 | performance | `markAllRead` put more than 500 writes in one batch | Accepted | Fixed | [`9243bf3`](https://github.com/baonv0817/PRM393_Lab03_Group2/commit/9243bf3) |
| CR-05 | bug | "Xem đơn cũ hơn" stopped on a page without finished orders | Accepted | Fixed | [`2980559`](https://github.com/baonv0817/PRM393_Lab03_Group2/commit/2980559) |
| CR-06 | bug | The first "Có lại lúc" option fell under 15 minutes | Accepted | Fixed | [`ba8dc33`](https://github.com/baonv0817/PRM393_Lab03_Group2/commit/ba8dc33) |
| CR-07 | bug | Slot release updates without reading the slot | Rejected: the rules make a missing slot impossible | Closed | [code-review.md][cr] |
| CR-08 | maintainability | `_apply` returns ok while another write runs | Rejected: unreachable, every control is disabled meanwhile | Closed | [code-review.md][cr] |
| CR-09 | performance | K11 reads all kiosks to get one opening time | Rejected: 2 reads per tap | Closed | [code-review.md][cr] |
| CR-10 | test gap | `_submit` checks neither status nor an earlier report | Rejected: partly wrong, the repository and the rules already check | Closed | [code-review.md][cr] |

CR-01 is the only accepted finding without a fix. A real fix needs pricing on a server, and the final handout puts Cloud Functions out of scope (section 4), so it stays a known limitation and must be named in the final report.

## 6. Final-assignment additions to the mobile app

| Item | Final handout | Status | Evidence |
|---|---|---|---|
| Announcements in the S19 inbox, live | §3 "inbox for announcements", §7 W05 | **Fixed** (F20, 12/11/2026): `AnnouncementInboxRepository` (packages/core) adds the published announcements for the customer's kiosk to S19, labelled "Thông báo từ BreakBite" | [PR #106](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/106). [`announcement_inbox_repository.dart`](../packages/core/lib/data/repositories/announcement_inbox_repository.dart), [`announcement_inbox_repository_test.dart`](../mobile/test/data/repositories/announcement_inbox_repository_test.dart); [data-model §3.10](data-model.md). Device screenshot: To verify (V05) |
| An `admin` account is turned away by the mobile app | §6 "Each client rejects accounts of the wrong role with a clear message" | **Fixed** (F20, 12/11/2026): `mobileAccessProblem` shows a Vietnamese message that points to the web admin (https://breakbite-1315b.web.app); customers and staff go on as before | [PR #106](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/106). [`mobile_access.dart`](../packages/core/lib/domain/mobile_access.dart), used in `mobile/lib/ui/auth/view_models/auth_view_model.dart`. D04 updated on 13/11/2026 |
| Cross-role flow, phone side: S07 and S10 show the web decision and reason live, the inbox gets a message | §3, `docs/cross-role-flow.md` | **Works** (13/11/2026) | Three runs on the deployed system: 1.22 s, 1.09 s, 1.14 s; announcement 1.13 s, archive 0.81 s ([cross-role-flow.md](cross-role-flow.md), [`evidence/cross-role/`](../evidence/cross-role/)); ARTEMIS TC-42 3/3 and TC-43 3/3 ([test-plan §3.5](test-plan.md)) |
| AI feature: Gemini fills K14 from a dish photo (level 2) | §8 | Works | [ai-feature.md §4][ai4] (three real inputs and outputs, the not-food failure), [`evidence/ai/`](../evidence/ai/), D36, [PR #103](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/103). ARTEMIS ([§3.4][tp34]): first runs TC-40 1/3 and TC-41 1/3, failures from host load and quota (E-04, E-05); rerun after the emulator reboot TC-40 3/4 (run-43 to 46, run-45 lost to the ARTEMIS model, E-06) and TC-41 3/3 (run-43 to 45) |
| AI events `ai_request`, `ai_result_accepted`, `ai_error` | §8 | Works in code; DebugView evidence: **Still missing** (G12) | Plan rows in [analytics-plan.md](analytics-plan.md); unit tests `mobile/test/ui/seller_menu/menu_item_form_ai_test.dart`. The plan's ["Evidence" table][ap-ev] has no AI row |
| App Check on mobile (AI Logic, Firestore) | §6, §8 | Works on the debug build; enforcement: To verify (V06) | [ai-feature.md §2](ai-feature.md) (debug provider and Play Integrity, debug token registered). Firestore enforcement waits for the web admin to send tokens (ai-feature §7) |
| Remote Config `ai_enabled` switches the AI off live | §8 | Works | [`k14-ai-off`](../evidence/ai/k14-ai-off.png), [`k14-ai-on`](../evidence/ai/k14-ai-on.png) |
| Remote Config, Analytics, Crashlytics on mobile; all data on Firestore | §6, rubric "Real data and inbox" | Works | L16 to L18 above; data-source column of [design-traceability][dt-s] |
| The Lab 3 PDF "is saved and shared on the device, with its metadata in Firestore" | §4 | To verify (V07) | The app uploads the PDF to Cloudinary and keeps its metadata in `reports` (L06). The final handout lists only Firebase services |
| Web admin (context): Analytics, Remote Config `reject_reasons`, App Check (reCAPTCHA Enterprise; App Check no longer takes new reCAPTCHA v3 setups), deployed to Hosting, offline state, kiosk switch, the system pages of #113 | §6, §7 | **Fixed** (#98, 12–13/11/2026) | [PR #105](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/105), [#110](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/110), [#111](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/111), [#113](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/113); https://breakbite-1315b.web.app; checklist in [test-report §2](test-report.md) |

## 7. Still missing, with owner and plan

### 7.1 Still missing

| ID | Gap | Severity | Owner | Plan |
|---|---|---|---|---|
| G01 | S15 order count shows "Không tải được số đơn" | — | — | **Closed 13/11/2026**: not reproduced once the current rules were deployed (see S15 above) |
| G02 | A receipt can be exported for a cancelled, unpaid order | — | — | **Closed 13/11/2026**: [PR #119](https://github.com/baonv0817/PRM393_Lab03_Group2/pull/119) |
| G03 | "Ngoài giờ mở cửa" follows the phone's clock (D35) | Medium for the demo | Team | Kiosk Q9 · Tầng 2 is set to 00:00–23:59 in K10 since 13/11 for the tests; before recording, check the hours of the kiosk used in the video. The limitation is named in the report |
| G04 | P-02: an active order card on Orders is not tappable | Low | `#97 baodhg` | Make the whole card open S07, as finished orders do |
| G05 | P-03: "Mã nhận tại …" sits above the order code, not the pickup code | Low | `#97 baodhg` | Rename it or move it next to the 6-digit code; record the change as a deviation |
| G06 | 200 % text: Orders tab label fades, kiosk status cut, search empty text, badge wording ([§4.2][tp42]) | Low | `#97 baodhg` | Fix each, or record it as a deviation with its reason |
| G07 | K10 "Âm báo đơn mới" switch not built (D21) | Low | `#97 baodhg` | Build the switch over `OrderAlertService`, or rewrite D21's reason (K02 already rings) |
| G08 | Figma not updated for D01 to D36 | Medium (Lab 3 §3) | `#97 baodhg` | Update the Figma frames, then set "Figma updated" to Done in [design-traceability §5][dt-dev] |
| G09 | `architecture.md` describes the Lab 3 `lib/` layout, not `mobile/`, `packages/core/`, `web/`; design-traceability has no web rows W01 to W05 | Medium (rubric: "architecture.md matches the code") | `#95 danhnguyenthanh260` | **Closed 13/11/2026**: `architecture.md` rewritten for `packages/core/`, `mobile/` and `web/` (§0 to §6); design-traceability §2b lists W01 to W05 and the system pages |
| G10 | Out-of-date rows: S28-EMPTY "Not started"; D04 (admins now turned away); D28 and D29 reasons ("S19 and FCM not built yet"); the components path in design-traceability §4; firebase-design §1 (admin opens the seller app) and §4 (five events); `firebase/README.md` rules count (81); `reorder` missing from the analytics plan table | Low (documents only) | `#97 baodhg` | **Closed 13/11/2026**: every row edited; `firebase-design.md` also gained App Check, AI Logic and Hosting sections. The deploy lines of `firebase/README.md` held a form feed instead of `\f` in `..\firebase`, so the copy command failed; fixed in the same change |
| G11 | README: team names and IDs, "How to run" for `mobile/`, `web/` and the emulators; the other members' AI tools (also code-review §1) | Medium | `#98 baonv0817` | Fill in as #98 lists |
| G12 | AI events not shown in DebugView | Low | `#96 Mikan382` | DebugView screenshot after one AI fill and one failure; add the rows to the plan's "Evidence" table |

### 7.2 To verify

| ID | What | Owner | Plan |
|---|---|---|---|
| V01 | F6 (S13, S14) on a device | `#99 user2665` | Screenshots, and an ARTEMIS case with 3 runs (the final handout §9 asks for every Lab 2 flow) |
| V02 | F8 (bell → S19 → "Xem mã nhận món" → S20) on a device; F9 in ARTEMIS (TC-30) | `#99 user2665` | Same as V01 |
| V03 | S30 offline and K05-ERR on a device | `#99 user2665` | Airplane-mode screenshot (TC-19); a wrong code typed in K05 |
| V04 | Lab 2 flows F4, F5, F7 are not named in this repository | `#97 baodhg` | Check the Lab 2 repository (`PRM323-Lab2-Group2`); add each missing flow to [design-traceability §3][dt-flows] with a test case |
| V05 | Announcement and admin rejection on a phone; the phone side of the cross-role flow; `docs/cross-role-flow.md` | — | **Done 13/11/2026**: see "Cross-role flow, phone side" in section 6 and [test-report §4](test-report.md) |
| V06 | App Check enforcement on Firestore and AI Logic once the web admin sends tokens | Mikan382 | The web URL works (checklist on the deployed site); the web sends App Check tokens since #105. Enforcement is turned on last, after a final check of both clients |
| V07 | Cloudinary for the PDF against final handout §4 | `#98 baonv0817` | Ask the lecturer; record the answer in [README "Deviations"][readme-dev] |
| V08 | No secrets in the Git history | `#98 baonv0817` | Run one secret scan (for example gitleaks) and record the result |
| V09 | Every member's commits are visible | `#98 baonv0817` | Check the contributors page before the deadline |

[dt-s]: design-traceability.md#1-customer-app-s01s30
[dt-flows]: design-traceability.md#3-flows
[dt-dev]: design-traceability.md#5-deviations-from-the-design
[tp2]: test-plan.md#2-test-cases
[tp31]: test-plan.md#31-graded-suite-12112026-runs-6-to-39
[tp32]: test-plan.md#32-first-session-11112026-runs-1-to-5
[tp33]: test-plan.md#33-problems-the-runs-found
[tp34]: test-plan.md#34-final-assignment-ai-12112026-runs-40-to-46
[tp41]: test-plan.md#41-artemis-pro-session-12112026-158-minutes
[tp42]: test-plan.md#42-earlier-manual-session-10112026
[arch-folders]: architecture.md#1-folder-structure
[arch-rules]: architecture.md#3-rules-graded
[arch-test]: ../mobile/test/architecture_test.dart
[fd-auth]: firebase-design.md#1-authentication
[fd-storage]: firebase-design.md#2-file-storage-cloudinary-instead-of-cloud-storage
[cr]: code-review.md#2-findings-and-decisions
[dm7]: data-model.md#7-what-the-rules-can-and-cannot-do
[ai4]: ai-feature.md#4-three-real-inputs-and-outputs
[ap-ev]: analytics-plan.md#evidence
[flow-order]: ../mobile/test/flows/ordering_flows_test.dart
[flow-seller]: ../mobile/test/flows/seller_orders_flow_test.dart
[flow-p5]: ../mobile/test/flows/p5_flows_test.dart
[readme-dev]: ../README.md#deviations-from-the-handout
[readme-ai]: ../README.md#ai-tools-used
[readme-sec]: ../README.md#security
[pr95]: https://github.com/baonv0817/PRM393_Lab03_Group2/pull/95
