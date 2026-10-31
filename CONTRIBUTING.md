# How we work in this repo

Read this once before writing code. Assignments: [`ASSIGNMENTS.md`](ASSIGNMENTS.md). Environment setup: [`docs/setup.md`](docs/setup.md).

## 1. Run the app

Open VS Code, press **F5**, and pick a launch configuration:

| Configuration | Use it when |
|---|---|
| BreakBite customer (fake data, signed in) | Building customer-app screens. The default for everyone |
| BreakBite seller (fake data, signed in) | Building seller-app screens (K01–K15) |
| BreakBite (fake data, from the start: Onboarding then Sign-in) | Trying the app-opening flow |
| BreakBite (real Firebase) | After P3 finishes `bootstrap.dart` and T33 |

Edit the code and save: the UI updates by itself. Devices: Android emulator, Chrome, or an Android phone (see `docs/setup.md`). An iPhone cannot run this app from a Windows machine.

## 2. Build a screen: copy S02

Reference screen: `lib/screens/home_screen.dart`, `lib/viewmodels/home_view_model.dart`, `test/home_screen_test.dart`, `test/home_view_model_test.dart`, and how it is wired in `lib/router/routes_p1.dart`.

1. **Read the screen's row** in `docs/design-traceability.md` (route, ViewModel, data source) and the Figma image under `assets/figma/` in the Lab 2 repo (`final-ui-v2` for S01–S07, `final-ui-s09-s25` for S09–S25; for the seller app and S26 onward, ask P1 or see Page 03 in Figma). Figma is a reference: you may drop parts that are redundant or cluttered, but **record the deviation** in section 5 of that file (IDs D07, D08…).
2. **Write the ViewModel** `lib/viewmodels/<name>_view_model.dart`: receive services through the constructor, hold a `ViewState` (loading, empty, error, data), keep all logic here. Never import `package:firebase_*`.
3. **Write the screen** `lib/screens/<name>_screen.dart`: only read the ViewModel (`context.watch`) and draw. Use the widgets in `lib/widgets/`, colors and text sizes from the theme (`context.appColors`, `Theme.of(context).textTheme`), spacing from `AppSpacing`.
4. **Wire the route** in your own `lib/router/routes_pX.dart`: replace `placeholderRoute(...)` with a `GoRoute` that creates the ViewModel like `homeRoute` does.
5. **Write tests**: one ViewModel test (data, error, empty) and one widget test (shows the right thing, taps do the right thing). Fake data comes from `lib/dev/`.
6. **Run the checks** before opening a PR (section 5).
7. **Update** the screen's row status in `design-traceability.md` to `Done`.

## 3. Rules for shared files

This is where the team is most likely to step on each other. When you change a shared file, make a **separate, small PR that merges quickly**; do not fold it into a screen PR.

| File or folder | Who edits | Rule |
|---|---|---|
| `lib/theme/`, `lib/widgets/` | P1 | Need a new widget or variant: open an issue or a small PR for P1 to review. Do not add hard-coded colors or font sizes in a screen |
| `lib/router/app_router.dart` | P1 | Do not edit. Each person only edits their own `routes_p1.dart` to `routes_p4.dart` |
| `lib/router/routes_pX.dart` | the file's owner | Edit only your own file |
| `lib/services/services.dart`, `lib/services/app_services.dart` | the whole team | **Do not add more interfaces to `services.dart`.** A new service goes in its own file `lib/services/<feature>_service.dart`; add exactly one field to `AppServices` |
| `lib/dev/dev_services.dart` | the whole team | The fake of a new service goes in its own file `lib/dev/dev_<feature>.dart`; add exactly one line to `createDevServices` |
| `lib/models/models.dart` | the whole team | Only **add**: a new class, or a new field with a default value at the end. Do not rename or delete, so other people's code still compiles. If you change the data structure, do all 4 places (`docs/data-model.md`) |
| `firebase/firestore.rules`, `storage.rules`, `docs/data-model.md` | P3 reviews | Change together with tests in `firebase/tests/rules.test.mjs`; `npm test` must pass |
| `lib/firebase/` | P3 (shared services); the feature owner (their own services) | The only place allowed to import the Firebase SDK |
| `pubspec.yaml` | the whole team | When adding a package, record it in the versions table in `README.md` and tell the team |

## 4. Git

- Branches: `feat/S03-menu`, `fix/K02-crash`, named after the screen or task ID.
- Start commits with the ID: `[S03] Menu with category filter`. Many small commits over many days, not one dump.
- Open a PR into `main` using the PR template, and **ask someone else to review it**. The reviewer runs the app and reads the diff, not just clicks Approve.
- Never push straight to `main`. Never commit keys, passwords, keystores, or `*adminsdk*.json` files.
- Conflicts in a shared file: whoever merges second resolves it, and tells the other person.

## 5. A screen is done when

Run these in the repo root (both must be clean):

```bash
flutter analyze
```

```bash
flutter test
```

And check by eye on an emulator or phone:

- [ ] Matches Figma v2, or the deviation is recorded in `design-traceability.md` section 5.
- [ ] Loading, empty and error states with a retry button; the Back button goes to the right place.
- [ ] Tap targets ≥ 48 dp, body text ≥ 14 sp, contrast passes (use tokens, no hard-coded colors).
- [ ] Every button and tappable cell has `Semantics` or a `tooltip` (ARTEMIS reads the accessibility tree, T61).
- [ ] No SDK in widgets, no logic in `build()`.
- [ ] Runs on fake data; once T33 is in, it also runs on real Firebase.
- [ ] No hard-coded data (item names, prices, vouchers) in screen or ViewModel code; data comes from a service.
- [ ] A ViewModel test and a widget test exist; the row in `design-traceability.md` is `Done`.

## 6. Fake data vs real Firebase

Fake data (`lib/dev/`) exists only to build screens while Firebase is not connected, and **must be deleted before submission** (T83), because the handout forbids hard-coded or mock data in the submitted build. Do not put business logic in `lib/dev/`; logic belongs in the ViewModel so it behaves identically with real data.

Sample menu, kiosks, vouchers and slots are already loaded into the real Firestore (`firebase/seed/`). To get a seller account for testing: sign in to the app once, then ask P3 to run `set-role.mjs` to assign the role and kiosk.
