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

## Foundation progress (skeleton already built)

The foundation that lets 5 people work in parallel is already in the repo. It needs review; it is not considered finished.

| Task | Status | Notes |
|---|---|---|
| T03 | Done | `flutter create`, pinned versions and `flutterfire configure` done (project `breakbite-1315b`) |
| T20 | Skeleton done | MVVM skeleton, router, DI, `ViewState`; P1 must update `docs/architecture.md` to match the code |
| T21 | Skeleton done | Theme from the Lab 2 tokens and shared widgets; the Nunito font is in `assets/fonts/`; S02 is a reference screen built to Figma v2 |
| T22 | Partial | Interfaces, fakes and models exist; **P3 must write the Firebase implementations** and wire them in `lib/config/firebase_dependencies.dart` |
| T31 | Partial | The data model skeleton is settled (`docs/data-model.md`), rules and indexes are deployed, **82/82 rules tests pass**. The seed and role-assignment scripts are written and verified on the Emulator (`firebase/seed/`). Loaded into the real Firestore on 29/10/2026 (3 kiosks, 25 items, 3 vouchers, 40 slots). **Remaining:** assign the staff and admin roles to members with `set-role.mjs` after they sign in to the app once |
| T01 | Partial | Project `breakbite-1315b` (Spark): Android app, P1's machine SHA-1, Google Auth, Firestore (`asia-southeast1`), rules and Remote Config deployed. **Remaining:** Crashlytics, the other 4 machines' SHA-1, invite the 4 other members to the project |
| T02 | Not started | Owner P5. Needs an Android device and the ARTEMIS API key |
| T40 | Partial | S01 Onboarding and S02 Home are done, built to Figma v2 (reference screens for the team). Remaining: S03–S08, S21, S22, S25, S29 |
| T33, T34 | Not started | Nobody has written the Firestore versions of `MenuRepository`, `CartRepository`, `OrderRepository` and the per-feature services yet |

How to work in parallel: everyone edits their own route file (`lib/routing/routes_pX.dart`) to replace the placeholder screen with the real one; run `dev/main_dev.dart` (F5 "fake data") while Firebase is not connected. Fake data lives in `dev/`, outside `lib/`, so it is never part of the submitted build.
