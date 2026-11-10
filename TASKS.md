# Task plan (team of 5)

Assignments per person: [`ASSIGNMENTS.md`](ASSIGNMENTS.md). The order follows the handout workflow: **Plan, Architect, Integrate, Instrument, Test, Review, Report**. The Git history must show these stages in order, and every member's commits must be visible.

Deadline: `[fill in date]`. Minimum number of commits and days: `[fill in when the lecturer announces it]`.

## Assignments

| Person | Role | Main responsibility | Main rubric points |
|---|---|---|---|
| **P1** | Ordering flow | Menu, item detail, cart, pickup slot, voucher picker, checkout, order tracking, orders list, closed kiosk, unavailable item (S03–S08, S21, S22, S25, S29); architecture doc, design traceability, shared theme and widgets | Architecture 0.75, UI/UX 0.75, Functionality (F1, F2, F3) |
| **P2** | After ordering, seller menu management | Edit and cancel order, history, order detail, pickup QR, review, incident report (S09–S12, S20, S23, S24); seller menu, sold out, shop, shift statistics, add and edit item (K08–K11, K14, K15); PDF export | Functionality |
| **P3** | Firebase, accounts, profile | Auth, Firestore services, file storage (Cloudinary), Crashlytics, Remote Config, the SDK-wrapping service layer; S15–S17, S26, S27; Firebase demo area | Firebase 2.0 |
| **P4** | Seller order handling, code review, report | Seller K01–K06, K12, K13; AI code review; compiling the report, slides, video | Functionality (seller), Review 0.5, Slides and video 2.0 |
| **P5** | Testing, notifications, search | S13, S14, S18, S19, S28, S30; FCM; analytics; the ARTEMIS test suite and the test plan | FCM 0.5, Analytics, Testing 1.5 |

General rules:
- Everyone **writes the test cases (steps, expected result) for the screens they build** into `docs/test-plan.md`; P5 collects them, runs them and assesses reliability.
- Everyone **adds `Semantics` labels** to their own screens so ARTEMIS can read them.
- Everyone **writes their part of the report and records their part of the video**; P4 assembles.
- Everyone must be able to explain their own code and one review decision (there may be a 5-minute oral check).

## Git conventions

The full rules are in [`CONTRIBUTING.md`](CONTRIBUTING.md) section 4. In short:

- Branch `<type>/<ID>-<short-name>`, for example `feat/S03-menu`, `fix/CR-01-home-api-call`; never commit straight to `main`.
- Commit `[ID] Summary` in English, for example `[T41] Add cart screen states`; review fixes use the finding ID, `[CR-01] …`.
- Every change goes through a PR that says `Closes #…` or `Refs #…`; no approval is required, the author merges with a merge commit (no squash).
- Never commit service-account keys, API keys or keystores; use environment variables. `google-services.json` may be committed.

## Task list in order

The "Depends on" column shows which task must be finished first.

### Stage 0 · Preparation (week 1, days 1–2)

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T00 | P1 | Create the GitHub repo `PRM393_Lab03_<StudentID>`, invite the 4 other members, require PRs for `main`, push this repo skeleton | All 5 people can clone and push | — |
| T01 | P3 | Create the Firebase project (Spark), register the Android app, enable Auth (Google), Firestore, Cloud Messaging, Analytics, Crashlytics, Remote Config; add every member's SHA-1; invite the 4 other members to the project | The whole team can sign in to the console; `google-services.json` exists | T00 |
| T02 | P5 | Prepare the test machine: Android device or emulator, ADB, ARTEMIS (Python 3.12, uv), the model API key in an environment variable, a dedicated Google account for testing; record the pinned ARTEMIS commit | One sample ARTEMIS command runs | T00 |
| T03 | P1 | `flutter create`, pin versions in `pubspec.yaml`, `flutterfire configure`, update the versions section of `README.md` | An empty app runs on a device and Firebase initializes without errors | T01 |

### Stage 1 · Plan

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T10 | P1 (everyone edits their own rows) | Complete `docs/design-traceability.md`: screen matrix, flows, components and the deviations list | Every screen S01–S30 and K01–K15 has a route, widget, data source and owner | T00 |
| T11 | P4 | Confirm the scope with the lecturer in writing: team of 5, customer app and seller app, deviation D01 (Google Sign-In instead of OTP) | The lecturer's confirmation is saved in `docs/` | — |

### Stage 2 · Architect

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T20 | P1 | `docs/architecture.md`: folder structure, layer diagram, sequence diagram of one full flow, ViewModel and service table; build the `lib/` skeleton (models, services, firebase, viewmodels, screens, widgets, utils), DI with Provider or Riverpod, the shared state class (sealed class loading, empty, error, data), router | The skeleton runs and `architecture.md` matches the code | T03, T10 |
| T21 | P1 | `lib/ui/core/theme/`: tokens into `ColorScheme`, `TextTheme`, spacing and radius constants; the widget library from section 4 of the traceability doc; check 360 dp and 412 dp, tap targets ≥ 48 dp, text ≥ 14 sp | The widget catalog shows every variant without overflow | T20 |
| T22 | P3 | SDK-wrapping service layer (`AuthService`, `StorageService`, `MessagingService`, `AnalyticsService`, `CrashService`, `RemoteConfigService`): interfaces and fakes already exist; **write the Firebase implementations in `lib/data/services/firebase/`** and wire them in `lib/config/firebase_dependencies.dart` and `firebase_dependencies.dart` | No widget calls an SDK directly | T20 |

### Stage 3 · Integrate (Firebase and data)

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T30 | P3 | Google Sign-In, routing by sign-in state, sign-out clears local data, handle cancellation and network loss; save `users/{uid}` with `role` | Screenshots of both states, the Users tab in the console | T22 |
| T31 | P3 | The Firestore data model and `firebase/firestore.rules` (deny by default, role-based); a seed script that loads real sample data into Firestore (menu, kiosks, vouchers) | Rules tested in the Emulator; no hard-coded data in the app | T30 |
| T32 | P3 | Cloudinary account and unsigned upload preset (`docs/setup.md`); wire `CloudinaryStorageService` (already written and tested) into `firebase_dependencies.dart`; save each file URL in Firestore so only its owner can list it | A real upload shows progress and a URL; the file appears in the Cloudinary media library | T30 |
| T33 | P3 | Firestore implementations of `MenuRepository`, `CartRepository`, `OrderRepository` (kiosks, vouchers, slots) in `lib/data/repositories/firestore/`: queries per section 5 of `docs/data-model.md`, place an order with one batch (create the order, delete the cart, increase the slot) | An order placed in the customer app appears at once in the seller app; no hard-coded data in the app | T22, T31 |
| T34 | Each screen owner | Per-feature repositories, each person builds their own (interface in `lib/data/repositories/<name>_repository.dart`, fake in `dev/fakes/fake_<name>_repository.dart`, Firestore version in `lib/data/repositories/firestore/`; steps in `docs/architecture.md` section 6): P1 `SlotRepository`, `VoucherRepository`; P2 `ReviewRepository`, `IncidentRepository` (create); P5 `FavoriteRepository`, `NotificationRepository`; P4 the incident handling part for K13 | Your screens use real data; ViewModel tests use the fake | T33 |

### Stage 4 · Features (in parallel after T21 and T31)

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T40 | P1 | Ordering flow: S01 and S02 are done (reference screens); remaining are S03 menu, S04 item detail, S05 cart, S25 pickup time, S29 voucher picker, S06 and the payment variants, S06-GATEWAY, S07 order tracking, S08 orders, S21 closed-kiosk state on Home, S22 unavailable-item suggestions; the "added to cart" notice | F1 and F3 run end to end on a device | T21, T33 |
| T41 | P2 | S09–S12, S20, S23, S24: edit and cancel order, history, order detail, pickup QR code, review, incident report | F2 runs end to end; every screen has loading, empty, error with retry | T21, T31 |
| T42 | P3 | S15–S17 profile, S26 sign-in, S27 kiosk picker, and the Firebase demo area in Profile (Remote Config values, Crashlytics test buttons, file export and upload) | Every item in the demo area can be operated | T30 |
| T43 | P2 | Generate a PDF (receipt or summary of the order being viewed), upload it through `StorageService`, show progress and URL | The file lands in `reports/{uid}/…` | T32, T41 |
| T44 | P4 | Seller K01–K06, K12, K13: role gate, real-time order queue, detail, preparing, scan code, deliver and collect cash, reject order, incidents | A customer's order appears and can be processed in the seller app | T33, T40 |
| T45 | P2 | Seller menu management K08–K11, K14, K15: menu management, mark item sold out, shop status, shift statistics, add and edit item | A change in the seller app shows immediately in the customer app | T33, T30 |
| T46 | P5 | S13 favorites, S14 reorder, S18 notification settings, S19 notification center, S28 search, S30 offline | Each screen has loading, empty, error with retry; search shows the empty state for no results | T21, T31 |

### Stage 5 · Instrument

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T50 | P5 | `docs/analytics-plan.md` and the event-logging code (≥ 7 events, set `userId` after sign-in, no personal data) | Every event has a DebugView screenshot | T30 |
| T51 | P3 | Crashlytics: 1 non-fatal error from a real error path, 1 test crash, with user ID and custom key | The dashboard shows both, with the key | T30 |
| T52 | P3 | Remote Config ≥ 2 parameters that change visible behavior (for example the number of "quick under 5 minutes" items, toggling the Golden Hour Combo banner); `firebase/remote-config-defaults.json` | Before and after screenshots, values in the console | T40 |
| T53 | P5 (uses P3's `MessagingService`) | FCM: receive in 3 states, ask for Android 13+ permission, in-app notification list, tapping opens the related screen | A test message from the console arrives in every state | T46 |

### Stage 6 · Test

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T60 | P5 (everyone submits their own cases) | `docs/test-plan.md`: ≥ 10 test cases covering section 7 of the handout (including error paths, native interactions, the exploratory session) | Every Lab 2 flow and error path has a test | T10 |
| T61 | Everyone | Add `Semantics` labels to the buttons, list cells and charts of your screens | ARTEMIS can read the accessibility tree of the screen | T40–T45 |
| T62 | P5 | Write the ARTEMIS tests in pytest under `e2e_test/`, assert on the value the agent reports back, ≥ 3 runs per test, a pass-rate table, analysis of flaky tests; 1 test that checks a logged analytics event | Results table, trace or screenshot for every run | T61, T50 |
| T63 | P5 | A 15 to 30 minute exploratory session with the Pro profile, list of bugs found | Exploratory session report | T62 |

### Stage 7 · Review

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T70 | P4 | Open a PR, run at least 1 AI review tool, save the output | The tool output is in `evidence/` | T40–T45 |
| T71 | Everyone | Each person decides (accept, modify, reject) the findings that belong to their files, with a concrete reason; ≥ 5 findings in total, ≥ 3 fix commits that mention the ID | `docs/code-review.md` has the full table and commit links | T70 |
| T72 | P1 | Check the MVVM rules across the repo (no SDK in widgets, no logic in `build()`), compare with `architecture.md` | The violation list is empty or each one is explained | T71 |

### Stage 8 · Report

| ID | Owner | Work | Done when | Depends on |
|---|---|---|---|---|
| T80 | P4 (everyone writes their own section) | PDF report of 8 to 12 pages following the handout table of contents, every claim backed by a screenshot or link | `report/Lab03_<StudentID>.pdf` | T72 |
| T81 | P4 | PDF slides of 12 to 15 pages, every "it works" slide has evidence, Figma and the app side by side | `slides/Lab03_<StudentID>_slides.pdf` | T80 |
| T82 | P4 (everyone records their part) | A 5 to 10 minute video recorded live on a device: sign-in, each flow including the error path, export and upload, push notification, a Remote Config change without rebuilding, Crashlytics, one ARTEMIS test run, one review finding and its fix | A public video link in the README | T80 |
| T83 | P1 | Update Figma per section 5 of `design-traceability.md`; run the submission checklist; open the repo, report, slides and video in a private window | Every checklist item is ticked | T82 |

## Reference milestones (adjust to the real deadline)

| Week | Goal |
|---|---|
| 1 | T00–T03, T10, T11, T20, T21, T22 |
| 2 | T30–T32, start T40, T41, T42, T44 |
| 3 | Finish T40–T45, T50–T53 |
| 4 | T60–T63, T70–T72, T80–T83 |

Have a short meeting at the start and the middle of each week; anyone who falls behind a milestone should say so right away so the work can be redistributed.

## Progress (checked against the code on 2026-11-01)

Status is what the code and the evidence show, not what was planned. "Done in code" means the code and its tests are finished but the evidence the handout asks for (screenshots, console, device run) is still missing. Main screens built: **44 of 44** (S01–S30, K01–K15 except K07, which is not in Figma; no placeholder route is left in `lib/routing/`).

| Task | Owner | Status | Done | What exists | Still missing |
|---|---|---|---|---|---|
| T00 | P1 | Done | 100% | Repo, PR rules, templates, conventions | Only 3 of 5 members have commits so far |
| T01 | P3 | Partial | 85% | Project `breakbite-1315b`, Android app, Google Auth, Firestore `asia-southeast1`, rules, Remote Config; Crashlytics turned on (01/11/2026, the console waits for the first crash); P3's debug SHA-1 added and `google-services.json` refreshed | Add the SHA-1 of the other members' machines (P1's and P3's are registered), invite the other members to the project |
| T02 | P5 | Partial | 30% | ARTEMIS client pinned, environment guide in `e2e_test/README.md` | Android device, model API key, one sample ARTEMIS run |
| T03 | P1 | Done | 100% | `flutter create`, pinned versions, `flutterfire configure` | — |
| T10 | P1 | Done | 100% | Every S and K screen has a route, widget, data source and owner | Owners keep their rows up to date |
| T11 | P4 | Not started | 0% | — | Written confirmation from the lecturer (team of 5, both apps, D01, Cloudinary instead of Storage, deadline) |
| T20 | P1 | Done | 100% | MVVM layers, router per owner, DI, `ViewState`, `Result`, `Command`, `Paged`; layer rules checked by `test/architecture_test.dart` | — |
| T21 | P1 | Done | 100% | Theme from the Figma v2 frames, shared widgets with tests, WCAG contrast tests; widget catalog `dev/widget_catalog.dart` (every shared widget and variant, `flutter run -t dev/widget_catalog.dart`), checked at 360 and 412 dp with text at 1.0 and 1.3: no overflow, tap targets ≥ 48 dp, every tap target labelled, text contrast (`test/ui/core/widget_catalog_test.dart`) | — |
| T22 | P3 | Done | 100% | Firebase Auth, Analytics, Crashlytics, Messaging, Remote Config in `lib/data/services/firebase/` | — |
| T30 | P3 | Done in code | 90% | S26 Google Sign-In, `users/{uid}` with role `user`, routing by auth state and role (a splash screen waits for the sign-in state, so no screen starts with an unknown user; the default kiosk is selected at sign-in), cancel and offline messages, S15 sign-out with confirmation | Screenshots on a device and of the Users tab in the console |
| T31 | P3 | Partial | 95% | Data model, rules (85 rules tests), indexes, seed, backup, restore and migration scripts; migration rolled out to the real Firestore on 01/11/2026 (111 documents, verify 0 problems), catalog re-seeded, the 14 indexes and the new rules deployed | Give staff and admin roles with `set-role.mjs` after each member signs in once; smoke test on a phone (step 7 in `firebase/README.md`) |
| T32 | P3 | Partial | 75% | `CloudinaryStorageService` written, tested and wired; unsigned preset in `env/cloudinary.json`; the Firebase demo area uploads a generated PDF to `reports/{uid}/` with progress and URL and saves its metadata in `reports` (owner-only rules, tested) | A real upload on a device, a screenshot of the Cloudinary media library, the lecturer's approval to use Cloudinary |
| T33 | P3 | Done | 100% | Firestore Menu, Cart and Order repositories; ordering in one transaction; checked against the real rules on the Emulator (`integration_test/`, 10 tests) | — |
| T34 | Each owner | Done | 100% | Every per-feature repository has an interface, a fake in `dev/fakes/` and a Firestore version in `lib/data/repositories/firestore/`: P1 `SlotRepository`, `VoucherRepository`; P2 `ReviewRepository`, `IncidentRepository` (create side); P3 `UserRepository`, `ReportRepository`; P4 the `IncidentRepository` staff side for K13; P5 `FavoriteRepository`, `NotificationRepository`; checked on the Emulator against the real rules (`integration_test/firebase_emulator_test.dart`) | — |
| T40 | P1 | Done | 100% | S01, S02 (with the S02-LOADING skeleton, S02-ADDED), S03 menu (with S03-ADDED), S04 item detail, S05 cart (with S05-EMPTY, S05-VOUCHER-ERR), S25 pickup time, S29 voucher picker, S06 checkout with every payment variant, S06-GATEWAY, S06-ERR, S07 order tracking (with S07-CASH, S07-DIALOG), S08 orders (with S08-EMPTY and reorder), S22 sold-out alternatives (opened from a sold-out card on S03, D28), S21 closed or paused kiosk on Home (D29); F1, F2 and F3 run end to end in full-app tests at 360 and 412 dp (`test/flows/`) and on an Android phone with the real Firebase (04/11/2026, screenshots in `evidence/p1/`, Figma vs app in `evidence/figma/p1-*.png`) | — |
| T41 | P2 | Done in code | 95% | S23 review (stars, quick tags and a comment for each item of a received order, a review already sent can be changed; opened from S12), S24 incident report (kind and description, one report per order, the kiosk's answer shown live; opened from S12), S20 pickup QR (large QR and code, the status of the code, spent once delivered or cancelled; opened from a new "Phóng to mã QR" button in S07), S09 edit order (quantities, notes, voucher; the bill is recalculated and the screen locks when the kitchen takes the order), S10 cancelled order, S11 history (grouped by week or month, a page at a time) and S12 order detail (steps, lines, bill, payment, pickup, note, reorder, receipt export); all states; ViewModel, widget and flow tests at 360 and 412 dp; the S09 pickup time is not editable; S24 has no photo | S07, S09, S10, S11, S12, S20, S23 and S24 were run against the real Firebase on 10/11/2026 (`evidence/p2-real/`, emulator, test account); a run on a physical phone; Figma updated for D25–D27 (T83) |
| T42 | P3 | Done in code | 90% | S15, S16, S17, S26, S27 and the Firebase demo area (notification center link, Remote Config values with their source, Crashlytics test error and test crash, PDF export and upload with progress, URL and the list of my files); every screen has loading, empty and error states, `TestId`s and ViewModel and widget tests | Screenshots on a device |
| T43 | P2 | Done in code | 80% | S12 makes a PDF receipt of the order being viewed (`ReportFileService.orderReceipt`), uploads it with progress, shows the file name and link (copyable), saves its metadata with the order id in `reports` and lists the earlier receipts of that order; offline, PDF and save failures show a message; `export_report` is logged with `source: order_detail`; PDF, ViewModel, widget and full-app flow tests | The receipt of S12 was exported and uploaded to the real Cloudinary on 10/11/2026 (`evidence/p2-real/S12-receipt.png`); a screenshot of the file in the Cloudinary media library of the team |
| T44 | P4 | Done in code | 90% | K01 (Google sign-in, D31), K02 and K02-EMPTY (three tabs, accept from the list, bell), K03, K04 (countdown, check list), K05 and K05-ERR (live QR camera on a phone with `mobile_scanner`, or a typed code, D30), K06 and K06-CASH, K12 (reasons, refund notice), K13 (take on, refund, reject with a reason; `IncidentRepository` staff side with a fake and a Firestore version); ViewModel tests, a full-app flow test (K02 → K03 → K04 → K06, K05 → K06-CASH, K12, K13) | Device screenshots and a check against Figma; a run against the real Firebase with a staff account (P3 assigns the role with `set-role.mjs`); try the camera scan on a phone |
| T45 | P2 | Done in code | 95% | K14 add an item and K15 edit one (one form, field errors, a name already on the menu refused, the save button in the bottom bar so messages do not cover it), K08 menu management and K09 mark sold out (by category, filter, a switch per item, reason and expected time; customers see the change at once; widget, ViewModel and full-app flow tests; `setSoldOut` now takes a reason and an expected time); `MenuRepository.upsertItem` is ready; K10 shop (switch, pause, wait stepper apply at once; notice, hours and capacity saved with a button; `MenuRepository.updateKiosk`) and K11 shift statistics (server-side count, sum and average, hourly chart, refresh; `OrderRepository.kioskStats`) with widget, ViewModel, fake and full-app flow tests | K08, K09, K10, K11, K14 and K15 were run against the real Firebase on 10/11/2026 (`evidence/p2-real/`, emulator, test account with the staff role); K11 needed two composite indexes that are now in `firestore.indexes.json`; a run on a physical phone |
| T46 | P5 | Done in code | 90% | S13 (heart on S04, rows with price and stock, "Đã đặt N lần"), S14 (sheet from S02), S18 (four switches saved as flipped; "Nhắc trước giờ nghỉ" schedules a phone notification 10 minutes before each break of the selected kiosk, D33), S19 (today / earlier, unread dot, "Xem mã nhận món"; the app writes a notification when an order changes, `OrderStatusNotifier`), S28 and S28-EMPTY (no accents, debounce, `search` event), S30 (offline cover with retry and cart); repositories with fakes and Firestore versions (`FavoriteRepository`, `NotificationRepository`), ViewModel tests and full-app flow tests | Device screenshots and a check against Figma; a run against the real Firebase (favorites and notifications rules are tested with `npm test` before, nothing new was added); check the break reminder on a phone |
| T50 | P5 | Done in code | 85% | Plan with 11 events, all 11 logged in code (`login`, `logout`, `search`, `view_menu_item`, `add_to_cart`, `reorder`, `export_report`, `begin_checkout`, `purchase`, `payment_failed`, `order_accepted`, `order_delivered`); `view_menu_item` once per opening of S04, `order_accepted` from K02 and K03 with the queue wait, `order_delivered` from K06 with `paid_cash`; `setUserId` after sign-in; ViewModel tests check each event | DebugView screenshots in `evidence/analytics/` |
| T51 | P3 | Done in code | 75% | Handled errors recorded from real error paths, uncaught errors reported, user ID and the `role` and `kiosk_id` keys | Dashboard screenshots of the non-fatal error and the crash with the key (Crashlytics is on; the demo area has both test buttons) |
| T52 | P3 | Done in code | 75% | 2 parameters change Home (quick item count, Golden Hour banner), values update live without a rebuild; defaults file matches the code (tested); the demo area shows each value and whether it came from the console | Before and after screenshots, values in the console |
| T53 | P5 | Done in code | 80% | `MessagingService`: Android 13+ permission, token per user, messages saved to the inbox in all 3 states; S19 notification center; `PushRouter`: tapping a notification in the tray opens its order (or S19), also when the tap started the app, and a message received in the foreground shows a banner with "Xem"; unit and full-app tests | The three states and the tap were run from the Firebase console on the real build on 10/11/2026 (`evidence/fcm/`, emulator); the tap on a closed app opened Home instead of the order and was fixed (`app.dart`); a run on a physical phone |
| T60 | P5 | Partial | 50% | 13 test cases written in `docs/test-plan.md` | Run them, record results |
| T61 | Everyone | Done in code | 90% | `TestId` (Semantics identifier) on the buttons, list cells, fields and states of every screen S01–S30 and K01–K15, also through the `testId` of the shared widgets; checked on 07/11/2026: every widget file under `lib/ui/*/widgets/` has ids except the splash screen (one labelled spinner) and `ProfileSection` (a frame); the shared widgets pass the tap-target and label guidelines (T21 catalog test) | Confirm on a phone that ARTEMIS reads them (T62) |
| T62 | P5 | Partial | 50% | 31 ARTEMIS tests in `e2e_test/`, one per case TC-01 to TC-31, each asserting on the value the agent reports back (TC-13 also reads the `purchase` event from Logcat); `run_repeat.py` runs the suite N times and writes the pass-rate table | Run on a phone with the ARTEMIS server (T02), 3 runs each, fill in section 3 of `docs/test-plan.md`, analyse flaky tests |
| T63 | P5 | Done (by P2, on the emulator) | 80% | `docs/test-plan.md` section 4: a time-boxed exploratory session on an Android emulator with fake data, the bugs found and what was fixed | Repeat it on a phone with the Pro profile and the real Firebase |
| T70 | P4 | Done | 100% | Claude Code `/code-review` run on the repositories and the P2 screens; its unchanged output is in `evidence/code-review/claude-code-review.md` | Another tool on a pull request (for example Copilot or CodeRabbit) is optional |
| T71 | Everyone | Done | 90% | `docs/code-review.md`: 10 findings, each decided with a reason; 5 fixes, each in its own commit (`CR-02` to `CR-06`) with a test; one accepted finding (`CR-01`) kept as a known limitation | The other members' own review decisions (each must explain one in the oral check) |
| T72 | P1 | Done | 100% | Every widget file read against the rules of `docs/architecture.md` section 3; 3 pieces of logic moved from `build()` into ViewModels (S11, S12, K11), 2 cases kept with a reason; the list is in section 3 | — |
| T80–T83 | P4, P1 | Partial | 40% | `report/Lab03_SE193905.pdf` (8 pages) and `slides/Lab03_SE193905_slides.pdf` (15 pages), built from the repo's own documents by `scripts/build_report.py`; the gaps are listed in report section 11 | The demo video (T82), the Figma update and the submission checklist (T83), the ARTEMIS results and the other members' evidence in the report |

How to work in parallel: everyone edits their own route file (`lib/routing/routes_pX.dart`) to replace the placeholder screen with the real one; run `dev/main_dev.dart` (F5 "fake data") while Firebase is not connected. Fake data lives in `dev/`, outside `lib/`, so it is never part of the submitted build.
