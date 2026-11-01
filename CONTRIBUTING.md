# How we work in this repo

Read this once before writing code. Assignments: [`ASSIGNMENTS.md`](ASSIGNMENTS.md). Environment setup: [`docs/setup.md`](docs/setup.md).

## 1. Run the app

Open VS Code, press **F5**, and pick a launch configuration:

| Configuration | Use it when |
|---|---|
| BreakBite customer (fake data, signed in) | Building customer-app screens. The default for everyone |
| BreakBite seller (fake data, signed in) | Building seller-app screens (K01–K15) |
| BreakBite (fake data, from the start: Onboarding then Sign-in) | Trying the app-opening flow |
| BreakBite (real Firebase) | After P3 finishes T22 and T33 (`lib/config/firebase_dependencies.dart`) |

The three fake-data configurations run `dev/main_dev.dart`; from a terminal: `flutter run -t dev/main_dev.dart --dart-define=DEV_SIGNED_IN=true` (add `--dart-define=DEV_ROLE=staff` for the seller app). The real app is `lib/main.dart`.

Edit the code and save: the UI updates by itself. Devices: Android emulator, Chrome, or an Android phone (see `docs/setup.md`). An iPhone cannot run this app from a Windows machine.

## 2. Build a screen: copy S02

Reference screen: `lib/ui/home/widgets/home_screen.dart`, `lib/ui/home/view_models/home_view_model.dart`, `test/ui/home/home_screen_test.dart`, `test/ui/home/home_view_model_test.dart`, and how it is wired in `lib/routing/routes_p1.dart`. Folder layout and which feature folder is yours: `docs/architecture.md` sections 1 and 5.

1. **Read the screen's row** in `docs/design-traceability.md` (route, ViewModel, data source) and the Figma image in the Lab 2 repo `PRM323-Lab2-Group2`, folder `assets/figma/final-ui-v2/` (customer screens S01–S30, `kitchen/` for the seller app K01–K15), or the ` v2` frames on Page 03 of the Figma file. Figma is a reference: you may drop parts that are redundant or cluttered, but **record the deviation** in section 5 of that file (IDs D07, D08…).
2. **Write the ViewModel** `lib/ui/<feature>/view_models/<name>_view_model.dart`: receive repositories and services through the constructor, hold a `ViewState` (loading, empty, error, data), keep all logic here. Never import `package:firebase_*`. Analytics event names come from `AnalyticsEvents`.
3. **Write the screen** `lib/ui/<feature>/widgets/<name>_screen.dart`: only read the ViewModel (`context.watch`) and draw. Use the widgets in `lib/ui/core/widgets/`, colors and text sizes from the theme (`context.appColors`, `Theme.of(context).textTheme`), spacing from `AppSpacing` (same names as the Figma tokens: Figma `spacing-md` is `AppSpacing.md`), paths from `AppRoutes`.
4. **Wire the route** in your own `lib/routing/routes_pX.dart`: replace `placeholderRoute(...)` with a `GoRoute` that creates the ViewModel like `homeRoute` does, reading each dependency with `context.read<MenuRepository>()`.
5. **Write tests** under `test/ui/<feature>/`: one ViewModel test (data, error, empty) and one widget test (shows the right thing, taps do the right thing). Fakes come from `dev/fakes/` (`import '../../../dev/fakes/fakes.dart';`).
6. **Run the checks** before opening a PR (section 5).
7. **Update** the screen's row status in `design-traceability.md` to `Done`.

## 3. Rules for shared files

This is where the team is most likely to step on each other. When you change a shared file, make a **separate, small PR that merges quickly**; do not fold it into a screen PR.

| File or folder | Who edits | Rule |
|---|---|---|
| `lib/ui/core/` (theme, widgets, `ViewState`) | P1 | Need a new widget or variant: open an issue, or a small PR that P1 agrees to before it is merged. Do not add hard-coded colors or font sizes in a screen |
| `lib/routing/router.dart` | P1 | Do not edit. Each person only edits their own `routes_p1.dart` to `routes_p5.dart` |
| `lib/routing/routes_pX.dart` | the file's owner | Edit only your own file |
| `lib/routing/routes.dart` | the whole team | Only **add** constants for your own paths; do not rename other people's |
| `lib/ui/<feature>/` | the feature's owner (`docs/architecture.md` section 5) | Other people do not edit it; shared pieces go to `lib/ui/core/` |
| `lib/data/services/`, `lib/data/repositories/` | the whole team | One interface per file. A new one is its own file plus one export line in `services.dart` or `repositories.dart` (`docs/architecture.md` section 6) |
| `lib/config/dependencies.dart`, `dev/fake_dependencies.dart` | the whole team | Add exactly one field and one provider line, and one line in each place that builds them |
| `dev/fakes/` | the whole team | One fake per file, plus one export line in `fakes.dart` |
| `lib/domain/models/` | the whole team | One model per file. Only **add**: a new file, or a new field with a default value at the end. Do not rename or delete, so other people's code still compiles. If you change the data structure, follow section 3.1 |
| `analysis_options.yaml`, `test/architecture_test.dart` | P1 | Changing a lint or a layer rule is a team decision: a separate small PR, announced to everyone |
| `firebase/firestore.rules`, `docs/data-model.md` | P3 reviews | Change together with tests in `firebase/tests/rules.test.mjs` and, when stored data changes, a migration (section 3.1); `npm test` must pass |
| Firebase implementations (`lib/data/services/firebase/`, `lib/data/repositories/firestore/`, `lib/config/firebase_dependencies.dart`) | P3 (shared ones); the feature owner (their own repositories) | The only places allowed to import the Firebase SDK |
| `pubspec.yaml` | the whole team | When adding a package, record it in the versions table in `README.md` and tell the team |

### 3.1 Changing the data structure: everyone ships a migration

Documents already in the real Firestore do not change when the code changes. Whoever changes how data is stored also moves the existing data, in the **same PR**, with a migration script; nobody edits documents by hand in the console.

A migration is needed when a stored field is renamed, removed, changes type or meaning, becomes required, when an enum value or a document id format changes, or when the rules start rejecting documents that exist today. It is not needed for a new optional field that has a default in the model, a new collection, or a change that only adds code (a getter, a method) to a model.

| Step | Who | What |
|---|---|---|
| 1 | The PR author | Update the 4 places in `docs/data-model.md` (that document, `lib/domain/models/`, `firebase/firestore.rules`, `firebase/tests/rules.test.mjs`), plus the seed and indexes when affected |
| 2 | The PR author | Add `firebase/seed/migrations/<yyyy-mm>-<task>-<name>.mjs` with `MIGRATION_ID`, `plan`, `apply`, `verify`, register it at the end of `migrations/index.mjs`, and add a test with old-structure documents to `migrate.test.mjs` (see `firebase/README.md`, "Adding a migration") |
| 3 | The PR author | Run `npm run test:migrate` in `firebase/seed` and `npm test` in `firebase/tests`; both must pass |
| 4 | The PR author | No migration needed? Write `No migration needed: <reason>` in the PR description |
| 5 | The holder of the service-account key (P3) | After the merge, roll it out with the runbook in `firebase/README.md` (backup, dry run, indexes, `--apply`, rules) and post the result in the PR |
| 6 | Everyone | After pulling, run `node migrate.mjs --status` against your Emulator data, or re-seed it, before testing |

The **Firebase checks** workflow enforces this on every PR: it fails when `lib/domain/models/`, `firebase/firestore.rules`, `firebase/firestore.indexes.json` or `docs/data-model.md` change without a file in `firebase/seed/migrations/` or a `No migration needed:` reason, and it runs the rules and migration tests.

## 4. Git conventions

This section is the single source of truth for branches, commits, pull requests and issues. `TASKS.md` and `ASSIGNMENTS.md` only point here.

### 4.1 IDs

Every branch, commit and PR carries the ID of the work it belongs to:

| ID | Meaning | Example |
|---|---|---|
| `T00`–`T83` | Task in `TASKS.md` (GitHub issue with the same ID) | `T22` |
| `S01`–`S30`, `K01`–`K15` | Screen in `docs/design-traceability.md` | `S03`, `K02` |
| `CR-01`, `CR-02`… | Code review finding in `docs/code-review.md` | `CR-01` |

Use the screen ID when the work is one screen, otherwise the task ID.

### 4.2 Branches

Format: `<type>/<ID>-<short-name>`, lower-case kebab-case short name, branched from the latest `main`.

| Type | For | Example |
|---|---|---|
| `feat` | New screen, feature or service | `feat/S03-menu`, `feat/T22-firebase-auth` |
| `fix` | Bug fix, review fix | `fix/K02-empty-list-crash`, `fix/CR-01-home-api-call` |
| `docs` | Documentation only | `docs/T10-traceability`, `docs/T00-unify-conventions` |
| `test` | Tests only (unit, widget, ARTEMIS) | `test/T62-artemis-checkout` |
| `refactor` | Restructure without changing behavior | `refactor/T20-split-models` |
| `chore` | Config, dependencies, tooling, CI | `chore/T03-bump-flutterfire` |

One branch holds one screen or one slice of a task. Delete it after merging.

### 4.3 Commits

Format: `[ID] Summary`, for example `[S03] Add category filter to menu`.

- Summary in English, imperative mood (`Add`, `Fix`, `Update`, `Remove`, `Refactor`, `Test`, `Document`), at most 72 characters, no period at the end.
- Several IDs only when one change really serves both: `[S25][T34] Add SlotRepository with fake and Firestore versions`.
- Review fixes use the finding ID: `[CR-01] Move API call out of HomeScreen`.
- Optional body after a blank line: why the change was made, and `Refs #13` for the issue.
- Many small commits over many days, not one dump. Every commit should still pass `flutter analyze`.
- Never commit keys, passwords, keystores, `.env` files or `*adminsdk*.json`. `android/app/google-services.json` is allowed.

### 4.4 Pull requests

- Never push straight to `main`; every change goes through a PR so the history shows each member's work.
- PR title uses the commit format: `[S03] Menu screen with category filter`.
- Fill in the PR template. Write `Closes #13` when the PR finishes the whole task, `Refs #13` when it is only part of it.
- Before merging: `flutter analyze` and `flutter test` are clean and the checklist in section 5 is ticked.
- **No reviewer approval is required.** The author merges their own PR once the checks pass. Anyone may still comment, and changes to shared files (section 3) must be announced to the file's owner before merging.
- Merge with **Create a merge commit**, never Squash: squashing erases the individual commits that show who did what and when.
- Delete the branch after merging. Conflicts in a shared file: whoever merges second resolves them and tells the other person.

### 4.5 Issues

- Every task already has an issue `[T..] …` (#1–#36). Assign yourself when you start it and set the milestone of the week you plan to finish it.
- A new bug gets its own issue titled `[S03] Bug: short description` with the `bug` label.
- An issue is closed by the PR that finishes it (`Closes #…`), or by hand with a comment linking the commits.

### 4.6 Language

Code identifiers, commits, PRs, issues and docs are in English. Text shown in the app is Vietnamese, matching Figma.

## 5. A screen is done when

Run these in the repo root (all three must be clean; details in section 7):

```bash
flutter analyze
dart format --set-exit-if-changed lib dev test
flutter test
```

And check by eye on an emulator or phone:

- [ ] Matches Figma v2, or the deviation is recorded in `design-traceability.md` section 5.
- [ ] Loading, empty and error states with a retry button; the Back button goes to the right place.
- [ ] Tap targets ≥ 48 dp, body text ≥ 14 sp, contrast passes (use tokens, no hard-coded colors).
- [ ] Every button and tappable cell has `Semantics` or a `tooltip` (ARTEMIS reads the accessibility tree, T61).
- [ ] No SDK in widgets, no logic in `build()`.
- [ ] Runs on fake data; once T33 is in, it also runs on real Firebase.
- [ ] No hard-coded data (item names, prices, vouchers) in screen or ViewModel code; data comes from a repository.
- [ ] A ViewModel test and a widget test exist; the row in `design-traceability.md` is `Done`.

## 6. Fake data vs real Firebase

Fake data lives in `dev/` at the repo root, **outside `lib/`**; only `dev/main_dev.dart` and the tests use it. `lib/` never imports `dev/`, so the submitted build (`lib/main.dart`) contains no hard-coded or mock data, as the handout requires, and nothing has to be deleted before submission. Do not put business logic in `dev/`; logic belongs in the ViewModel so it behaves identically with real data.

Sample menu, kiosks, vouchers and slots are already loaded into the real Firestore (`firebase/seed/`). To get a seller account for testing: sign in to the app once, then ask P3 to run `set-role.mjs` to assign the role and kiosk.

## 7. Code standards

Three checks must be clean before merging; the first two also run in VS Code as you type and save:

```bash
flutter analyze                                  # lints and strict typing from analysis_options.yaml
dart format --set-exit-if-changed lib dev test   # 120 columns, set in analysis_options.yaml
flutter test                                     # includes test/architecture_test.dart (layer rules)
```

| Topic | Rule | Checked by |
|---|---|---|
| Formatting | `dart format`, 120 columns. Turn on *Format On Save* in VS Code | `dart format` |
| Imports | Inside `lib/` always `package:breakbite/…`, sorted. Tests import fakes with a relative path: `../../../dev/fakes/fakes.dart` | lints `always_use_package_imports`, `directives_ordering` |
| Language | Identifiers, test names, commits and docs in English. Only text shown to users is Vietnamese | review |
| Comments | **No comments in code** (`//`, `///`, `/* */`), including commented-out code and `TODO`. Names, narrow types and test names carry the meaning; explanations go into `docs/`. Only machine directives stay (`// ignore: …`). A file you edit loses its old comments | review |
| Naming | Files `snake_case`: `<name>_screen.dart`, `<name>_view_model.dart`, `<name>_repository.dart`, `<name>_service.dart`, fakes `fake_<name>_….dart`. A test mirrors the path of what it tests and ends in `_test.dart` | review |
| Types | Strict casts, inference and raw types; declared return types; no `dynamic` calls | analyzer, lints |
| Async | Await every `Future` or wrap it in `unawaited(…)`; cancel every `StreamSubscription` in `dispose()` | lints `unawaited_futures`, `cancel_subscriptions` |
| Layers | UI, routing and models never import an SDK; `lib/` never imports `dev/`; models do not import Flutter; view models import only `package:flutter/foundation.dart` and never a widget; feature screens use no colour or text-style literals | `test/architecture_test.dart` |
| Analytics | Event names come from `AnalyticsEvents`; no personal data (name, e-mail) in parameters | review |
| Tests | Every ViewModel: data, empty and error cases. Every screen: a widget test pumped with `pumpScreen` (`test/helpers/pump.dart`) at 360 dp, plus 412 dp for screens with long text. Test names are sentences that state the behaviour | review |
| View models | `extends ChangeNotifier with SafeChangeNotifier`; every user action that writes data is a `Command` (below) | `test/architecture_test.dart`, review |
| Test ids | Every button, tappable list cell, input and tab is wrapped in `TestId('<screen>.<element>[.<itemId>]')`, for example `s03.add.m1` | review; ARTEMIS relies on them |
| Line endings | LF everywhere (`.gitattributes`); Windows editors keep working as usual | Git |

### Error handling

1. **Repositories and services never throw across layers.** One-shot operations return `Future<Result<T>>` (`lib/utils/result.dart`): `Ok(value)` or `Err(AppException)`. The Firebase and Cloudinary implementations catch SDK exceptions and map them to one `AppException` (`lib/domain/app_exception.dart`), keeping the original as `cause` and `stackTrace`:

   | Situation | Exception |
   |---|---|
   | No connection, timeout | `NetworkException` |
   | User closed the picker or dialog | `CancelledException` |
   | Security rules refused | `PermissionDeniedException` |
   | Document missing (wrong voucher code…) | `NotFoundException` |
   | Input not acceptable (file too large…) | `ValidationException` |
   | Anything else | `ServiceException` |

2. **Realtime data is a `Stream<T>`**; the ViewModel handles its errors in `onError`.
3. **ViewModels handle every failure** with an exhaustive `switch` on the result: show `error.message` (already Vietnamese and user-ready) through `ViewError` or a snackbar, and record it with `crash.recordError(error.cause ?? error, error.stackTrace, reason: '<screen>.<action>')`. `CancelledException` is shown but not recorded. An error is never swallowed silently: even a non-blocking stream (cart badge) records a non-fatal error. This is also the "handled error from a real error path" the handout asks Crashlytics to show.
4. **Telemetry never breaks the user's flow.** `AnalyticsService`, `CrashService` and `RemoteConfigService` return plain `Future`s and catch everything inside their implementations; Remote Config falls back to the in-app defaults.
5. **Screens never use `try/catch`**; they switch on what the ViewModel returns.

Reference implementation: `HomeViewModel.addToCart`, `AuthViewModel.signIn`, `CloudinaryStorageService.upload`, and their tests.

### Lists and pagination

Firestore has no page numbers or offsets (skipped documents are still billed as reads), so long lists are read with a cursor through `Paged<T>` (`lib/utils/paged.dart`).

| List | How it is read |
|---|---|
| Grows without limit: orders (S08, S11, S14), notifications (S19), incidents (K13), reviews of an item | `Future<Result<Paged<T>>> fetchX(…, {int limit = Paged.defaultLimit, PageCursor? after})`. The newest page can also be watched live (`watchX`, same order, `limit`); older pages are fetched when the user scrolls |
| Small and bounded: one kiosk's menu (S03, S28), kiosks (S27), the active order queue (K02) | One `Stream<List<T>>`, filtered in the ViewModel |
| Totals (K11) | Aggregation query (`count()`, `sum()`) returning `Result<int>` |

Rules:
1. Page size: default `Paged.defaultLimit` (20), at most `Paged.maxLimit` (50); anything else fails with `ValidationException`.
2. The order must be fixed and match an index in `firestore.indexes.json` (for example `uid` + `createdAt desc`).
3. `PageCursor` is opaque. The Firestore version wraps the last `DocumentSnapshot` of the page and the query uses `startAfterDocument`; a cursor from another source fails with `ValidationException`. Fakes use `IndexCursor` through `pageOf()` in `dev/fakes/paging.dart`.
4. To know whether more exists without an extra read, query `limit + 1` documents: if `limit + 1` come back, return the first `limit` and set `next` to the cursor of the last returned one; otherwise `next` is `null`.
5. The ViewModel appends each page to its list, keeps `next`, shows a footer loader while fetching, and stops asking when `hasMore` is false. A failed page keeps the items already shown and offers a retry.

Reference: `OrderRepository.fetchMyOrders` (interface and fake) and `test/dev/paging_test.dart`.

### Building blocks

Use these instead of writing your own; each has tests and a reference use.

| Need | Use | Where | Reference |
|---|---|---|---|
| A button that writes data (order, accept, sign in) | `Command0` / `Command1`: ignores a second tap while running, exposes `running` and `result`. Disable the button while `running`; after `await cmd.execute(…)` switch on the result (`null` means the tap was ignored) | `lib/utils/command.dart` | `HomeViewModel.addToCart`, `AuthViewModel.signIn` |
| State several screens share (the selected kiosk) | `SessionRepository` (`watchSelectedKioskId`, `selectKiosk`, `clear`); never a global variable or a view model shared between screens | `lib/data/repositories/session_repository.dart` | `HomeViewModel` |
| Safe `notifyListeners` after the user left | `with SafeChangeNotifier` | `lib/utils/safe_change_notifier.dart` | every view model |
| Dates and money on screen | `formatVnd`, `formatTime` (`10:20`), `formatDayMonth` (`14/10`), `formatDate`, `formatDateTime`, `formatTimeLeft` (`còn 3 phút`), `orderStatusLabel(OrderStatus)` | `lib/utils/format.dart` | `test/utils/format_test.dart` |
| Stable ids for ARTEMIS and widget tests | `TestId('s02.cart', child: …)`; in tests `find.bySemanticsIdentifier('s02.cart')` | `lib/ui/core/widgets/test_id.dart` | Home, Onboarding |
| Widget test setup | `pumpScreen(tester, screen, providers: […], size: TestScreens.narrow)` | `test/helpers/pump.dart` | `test/ui/home/home_screen_test.dart` |
| Firebase implementation of a one-shot method | `guard(() => …)` returns the `Result` with the right `AppException`; streams go through `guardStream(…)` | `lib/data/firebase/firebase_errors.dart` | `test/data/firebase/firebase_errors_test.dart` |
| Firestore writes and reads | `...Stamp.created()` / `...Stamp.updated()` in every write (DB-16); `readDate`, `readDateOr`, `readEnum` when mapping documents to models; mapping code lives in the repository, never in `lib/domain/` | `lib/data/firebase/firestore_helpers.dart` | — |
| A paged Firestore list | `fetchPage(query, fromDoc: …, limit: …, after: …)` | `lib/data/firebase/firestore_helpers.dart` | `OrderRepository.fetchMyOrders` (fake) |
| Trying flows against local data | VS Code "BreakBite (Firebase Emulator)" or `--dart-define=USE_FIREBASE_EMULATOR=true` | `lib/config/firebase_setup.dart`, `docs/setup.md` | — |
