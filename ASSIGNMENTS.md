# Lab 3 assignments (team of 5)

Updated 31/10/2026. Per-task details, done-when criteria and dependencies: [`TASKS.md`](TASKS.md). How to build a screen and the rules for shared files: [`CONTRIBUTING.md`](CONTRIBUTING.md). Every task has a GitHub issue with the same ID.

**Team (from Lab 2):** Nguyễn Viết Bảo (SE183398), Đỗ Hoàng Gia Bảo (SE193119), Nguyễn Quốc Hoàng Pháp (SE190175), Nguyễn Hoàng An (SE193905), Nguyễn Thành Danh (SE193274).

| Role | Owner | GitHub | Main rubric points (out of 10) |
|---|---|---|---|
| **P1** Ordering: menu, cart, checkout, order tracking | `[name, student ID]` | `[@…]` | UI/UX 0.75 · Architecture 0.75 · Functionality F1, F2, F3 |
| **P2** After ordering, plus seller menu management | `[name, student ID]` | `[@…]` | Functionality (post-order screens, seller menu and stats) |
| **P3** Firebase, accounts, profile | `[name, student ID]` | `[@…]` | Firebase 2.0 · Auth, Firestore, Storage, Crashlytics, Remote Config |
| **P4** Seller order handling, code review, report | `[name, student ID]` | `[@…]` | Functionality (seller orders) · Code review 0.5 · Slides and video 2.0 |
| **P5** Testing, notifications, search | `[name, student ID]` | `[@…]` | FCM 0.5 · Analytics · ARTEMIS tests 1.5 · Functionality (search, favorites, notifications) |

---

## Already in place (nobody has to redo it)

- Workstation: Flutter, Android SDK, emulator, Firebase CLI, Emulator Suite. How to run: `docs/setup.md`.
- The MVVM skeleton: router, DI, `ViewState`, theme from the Lab 2 tokens, shared widgets, the Nunito font, the BreakBite logo, sample item photos.
- The Firebase project `breakbite-1315b`: Google Auth, Firestore (sample data already loaded), Remote Config, rules and indexes (82 rules tests pass).
- **Two finished reference screens to copy from:** S01 Onboarding and S02 Home (ViewModel, screen, tests, faithful to Figma). Building a new screen means copying S02; see `CONTRIBUTING.md`.
- Runs without Firebase: the F5 "signed in" launch configurations (customer or seller) use fake data.

## How the work is split

Each person owns **one coherent cluster of screens**, so they share ViewModels and data and collide less. Placeholder routes in the code already live in each person's own file (`lib/router/routes_p1.dart` to `routes_p5.dart`).

| Cluster | Screens | Owner |
|---|---|---|
| Ordering | S03, S04, S05 (+ empty, wrong voucher), S06 (+ payment variants), S06-GATEWAY, S07 (+ cash, cancel dialog), S08, S25 pickup time, S29 voucher picker, S21 closed kiosk, S22 unavailable-item suggestions | P1 |
| After ordering, and seller menu management | S09 edit order, S10 cancelled order, S11 history, S12 order detail, S20 pickup QR, S23 review, S24 incident report; K08 menu management, K09 mark sold out, K10 shop, K11 shift statistics, K14 add item, K15 edit item | P2 |
| Firebase and account | S15 profile, S16 student profile, S17 payment methods, S26 sign-in, S27 kiosk picker, the Firebase demo area | P3 |
| Seller order handling | K01 sign-in gate, K02 order list, K03 order detail, K04 preparing, K05 scan code, K06 handover, K12 reject order, K13 incidents | P4 |
| Testing, notifications, discovery | S13 favorites, S14 reorder, S18 notification settings, S19 notifications, S28 search, S30 offline | P5 |

S01 and S02 are already done. The full table (screen, route, ViewModel, data source): `docs/design-traceability.md`.

---

## Shared duties for all 5 people

Mandatory, because the lecturer may question each person individually (about 5 minutes: run 1 ARTEMIS test, change 1 Remote Config value live, explain 1 ViewModel and 1 review decision).

1. Commit steadily across many days; start every commit with the task or screen ID, for example `[S03] Menu with category filter`. Do not pile the code onto one person.
2. Work on your own branch, open a PR, have someone else review it, then merge into `main`.
3. For every screen you build: fill in your row in `docs/design-traceability.md`, add `Semantics` labels (T61), write test cases into `docs/test-plan.md`, decide the review findings that touch your files (T71), write your report section and record your part of the video.
4. No SDK calls in widgets, no logic in `build()`, no hard-coded colors or font sizes (use the theme and shared widgets).
5. Every screen that loads data has loading, empty and error states with a retry button; the Back button goes to the right place.
6. Never commit keys, passwords or keystores. Keep the service-account key file outside the repo.
7. Read and run the other people's parts at least once before submission.

---

## P1 · Ordering

**Goal:** finish the whole ordering flow F1, F2, F3 from the menu to order tracking, and keep the UI quality and architecture of the whole team.

| Order | Task | Work | Output |
|---|---|---|---|
| 1 | T40 | S03 Menu, S04 Item detail, S05 Cart (empty, wrong voucher) | Add items, change quantity, see the total |
| 2 | T40 | S25 Pickup time, S29 Voucher picker, S06 Checkout + variants, S06-GATEWAY, S07 Order tracking, S08 Orders | F1, F2, F3 run end to end |
| 3 | T40 | S21 Closed kiosk state on Home, S22 Unavailable-item suggestions | Every ordering screen has all states |
| 4 | T34 | `SlotService` (book a slot) and `VoucherService` (voucher list): interface, fake, Firestore version | S25 and S29 use real data |
| in parallel | T10, T20 | Update `docs/architecture.md` to match the code; lead the filling-in of `design-traceability.md` | Docs match the code |
| last | T72, T83 | Check the MVVM rules across the repo; update Figma for the deviations (D01–D06); run the submission checklist | Checklist fully ticked |

**Can start today:** S03 to S08 with fake data (F5 "customer, signed in"). No waiting on anyone.
**Waiting on:** P3 finishing T33 (Firestore services) to connect real data; P3 finishing T30 for real sign-in.
**Who waits on you:** P2 waits for S07 and S08 (orders and the list) to build S09–S12; P4 waits for real placed orders to build K02–K06.
**Report and slides:** MVVM architecture, layer diagram, the design system in code, Figma vs app.
**Oral check:** explain the data flow of `CartViewModel` or `CheckoutViewModel`, and why state is a sealed class.

---

## P2 · After ordering, plus seller menu management

**Goal:** build the post-order screens and the seller's menu, shop and statistics screens.

| Order | Task | Work | Output |
|---|---|---|---|
| 1 | T41 | S20 Pickup QR, S23 Review, S24 Incident report (doable now with fake data) | Each screen has all states |
| 2 | T45 | K08 Menu management, K09 Mark sold out, K14 Add item, K15 Edit item (F5 "seller" uses fake data) | A seller can add, edit and sell out items |
| 3 | T41 | S09 Edit order, S10 Cancelled order, S11 History, S12 Order detail (after P1 finishes S07, S08) | F3 continues to work |
| 4 | T45 | K10 Shop status, K11 Shift statistics | The shop can open, close and see stats |
| 5 | T34 | `ReviewService`, `IncidentService` (create side): interface, fake, Firestore version | Screens use real data |
| 6 | T43 | Generate a PDF receipt from S12 and upload it through `StorageService` (needs Storage enabled, or the on-device alternative) | A receipt file |

**Can start today:** S20, S23, S24 and K08–K15 (fake data). S09–S12 need P1 to finish S07, S08.
**Waiting on:** P1 (S07, S08); P3 (T33 real data, T32 Storage if used).
**Who waits on you:** P4 needs `IncidentService` to build K13; P1 and the customer app need the seller's item changes to show up (T45).
**Report and slides:** the post-order flows and the seller menu management.
**Oral check:** explain one Firestore rule that protects your data (for example who may mark an item sold out).

---

## P3 · Firebase, accounts, profile

**Goal:** connect the app to the real Firebase (all 6 services, with error handling and console evidence) and build the account screens. This role carries the most integration work, so everyone else asks for data early through the interfaces and fakes, and does not wait.

| Order | Task | Work | Output |
|---|---|---|---|
| 1 | T01 | Remaining: enable Crashlytics, add everyone's SHA-1, invite the 4 other members to Firebase; Storage once the team decides about Blaze | The whole team is in the console and Google Sign-In works on every machine |
| 2 | T22 | Write `lib/firebase/bootstrap.dart` and the Firebase versions of `AuthService`, `RemoteConfigService`, `AnalyticsService`, `CrashService`, `MessagingService`, `StorageService` | The app runs against real Firebase (drop the fake-data flag) |
| 3 | T33 | Firestore versions of `MenuService`, `CartService`, `OrderService` (kiosks, vouchers, slots): queries per `docs/data-model.md` section 5, place an order with a batch | An order placed in the customer app shows up at once in the seller app |
| 4 | T30 | The S26 Google Sign-In screen, routing by sign-in, sign-out, errors on cancel or network loss, create `users/{uid}` | Screenshots of 2 states, the Users tab |
| 5 | T42 | S15–S17 Profile, S27 Kiosk picker, the Firebase demo area | The demo area works |
| 6 | T51, T52 | Crashlytics (1 non-fatal error, 1 test crash), Remote Config (≥ 2 parameters that change behavior) | Console evidence |
| in parallel | T31, T32 | Keep the rules and sample data (skeleton exists); once members have signed in, assign the staff role with `set-role.mjs` | Rules have allowed and denied cases |

**Can start today:** the rest of T01, T22, T33. S15–S17 and S27 are built with fake data.
**Waiting on:** nobody, but the whole team waits on you.
**Who waits on you:** P1 waits for T33; P4 waits for T30 (seller role) and T33; P5 waits for T22 (`MessagingService`, `AnalyticsService`).
**Report and slides:** one section per Firebase service, how errors are handled, console screenshots, the data model and rules.
**Oral check:** change 1 Remote Config value live and show the app change; explain 1 Firestore or Storage rule.

---

## P4 · Seller order handling, code review, report

**Goal:** finish the seller's order-handling screens, coordinate the AI code review, compile the report, slides and video.

| Order | Task | Work | Output |
|---|---|---|---|
| 1 | T11 | Ask the lecturer and save the confirmation in writing: team of 5, scope of the customer and seller apps, deviations D01–D06, the Storage question | Confirmation saved in `docs/` |
| 2 | T44 | K01 Role gate, K02 Order queue, K03 Order detail, K04 Preparing (F5 "seller" uses fake data) | Orders appear and can be accepted |
| 3 | T44 | K05 Scan code, K06 Handover and cash, K12 Reject order | An order can be processed from accept to delivery |
| 4 | T44, T34 | K13 Incidents, with the handling part of `IncidentService` (view, change status) | K13 uses real data |
| 5 | T70, T71 | Open a PR, run ≥ 1 AI review tool, coordinate the decision on each finding | `docs/code-review.md` complete |
| last | T80, T81, T82 | Compile the PDF report, slides, video (everyone sends their section and clip) | 3 deliverables to submit |

**Can start today:** T11 and K01–K06, K12, K13 with fake data (the F5 "seller, signed in" configuration).
**Waiting on:** P3 (T30 role, T33 real orders); P1 (real placed orders to try K02–K06); P2 (`IncidentService` create side for K13).
**Who waits on you:** the whole team waits for the schedule to compile the report, slides, video.
**Report and slides:** the seller order flow, code review, difficulties and lessons, list of AI tools.
**Oral check:** explain 1 review decision (why accept or reject), the seller's accept-and-deliver flow.

---

## P5 · Testing, notifications, search

**Goal:** carry the whole test effort (ARTEMIS, test plan, analytics evidence), push notifications, and the discovery screens.

| Order | Task | Work | Output |
|---|---|---|---|
| 1 | T02 | Prepare the test machine: Android device or emulator, ADB, ARTEMIS, API key in an environment variable, a dedicated Google account for testing | One sample ARTEMIS command runs |
| 2 | T46 | S13 Favorites, S28 Search, S30 Offline, S18 Notification settings (doable now with fake data) | Each screen has all states |
| 3 | T34 | `FavoriteService`, `NotificationService`: interface, fake, Firestore version | Screens use real data |
| 4 | T46, T53 | S19 Notifications and FCM: receive in 3 app states, Android 13+ permission, tapping opens the right screen; S14 Reorder | A test message from the console arrives in all 3 states |
| 5 | T50 | `docs/analytics-plan.md` and the logging code (≥ 7 events, `setUserId` after sign-in), with DebugView screenshots | Console evidence for every event |
| in parallel | T60 | The `docs/test-plan.md` skeleton, collecting cases from the others | ≥ 10 test cases |
| last | T62, T63 | ARTEMIS tests ≥ 3 runs each, pass-rate table, exploratory session | Results table, traces |

**Can start today:** S13, S28, S30, S18 and T02.
**Waiting on:** P3 (T22 `MessagingService`, `AnalyticsService`); P1 (S07, S08 to build the E2E flows); everyone else (finished screens to test).
**Who waits on you:** P4 needs the test results table for slides and video; everyone adds `Semantics` labels (T61) so your tests can read the screens.
**Report and slides:** test plan, ARTEMIS results, exploratory session, FCM, analytics.
**Oral check:** run 1 ARTEMIS test live, explain why you assert on the value reported back and not just `SUCCESS`.

---

## Bottlenecks and how to avoid them

| Likely bottleneck | How to avoid it |
|---|---|
| Everyone editing `services.dart`, `app_services.dart`, `dev_services.dart`, `models.dart` | Each new service lives in its own file `lib/services/<feature>_service.dart`, its fake in `lib/dev/dev_<feature>.dart`; add only one line to the shared files. PRs that touch shared files must be small and merged fast. Details: `CONTRIBUTING.md` |
| Waiting for P3 to connect real Firebase | Build with fake data; when P3 is done only the run flag changes, not the screens |
| P2 waiting for P1's S07, S08 to build S09–S12 | P2 does S20, S23, S24 and the seller menu screens first; P1 builds S07, S08 early in week 2 |
| P4 waiting for real orders to try the seller app | Use the dev services first (fake orders); try with real orders after T33 |
| P5 waiting for finished screens to test | Write the test plan and the first tests against S02 (finished) and the flows as they land; keep ARTEMIS set up early (T02) |
| Editing the theme and shared widgets | Only P1 edits `lib/theme/` and `lib/widgets/`; anyone who needs a change opens an issue or a small PR for P1 to review |

## End-of-week checkpoints

| End of week | Must have |
|---|---|
| 1 | Everyone has cloned, built and run the app with F5; Firebase has everyone invited and all machines' SHA-1; each person has finished at least 2 screens faithful to Figma with fake data; `bootstrap.dart` runs |
| 2 | Google sign-in and real Firestore data work; each person has at least 4 screens; F1 ordering runs end to end |
| 3 | Every screen S01–S30 and K01–K15 runs with all states; the 6 Firebase services have evidence; the test plan is done |
| 4 | ARTEMIS tests run ≥ 3 times each; code review done; report, slides, video; submission checklist |

Anyone who is late for a checkpoint should say so in the group right away so the work can be redistributed.
