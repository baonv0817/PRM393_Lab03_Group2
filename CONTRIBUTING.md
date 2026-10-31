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
| `lib/domain/models/` | the whole team | One model per file. Only **add**: a new file, or a new field with a default value at the end. Do not rename or delete, so other people's code still compiles. If you change the data structure, do all 4 places (`docs/data-model.md`) |
| `firebase/firestore.rules`, `storage.rules`, `docs/data-model.md` | P3 reviews | Change together with tests in `firebase/tests/rules.test.mjs`; `npm test` must pass |
| Firebase implementations (`lib/data/services/firebase/`, `lib/data/repositories/firestore/`, `lib/config/firebase_dependencies.dart`) | P3 (shared ones); the feature owner (their own repositories) | The only places allowed to import the Firebase SDK |
| `pubspec.yaml` | the whole team | When adding a package, record it in the versions table in `README.md` and tell the team |

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
- [ ] No hard-coded data (item names, prices, vouchers) in screen or ViewModel code; data comes from a repository.
- [ ] A ViewModel test and a widget test exist; the row in `design-traceability.md` is `Done`.

## 6. Fake data vs real Firebase

Fake data lives in `dev/` at the repo root, **outside `lib/`**; only `dev/main_dev.dart` and the tests use it. `lib/` never imports `dev/`, so the submitted build (`lib/main.dart`) contains no hard-coded or mock data, as the handout requires, and nothing has to be deleted before submission. Do not put business logic in `dev/`; logic belongs in the ViewModel so it behaves identically with real data.

Sample menu, kiosks, vouchers and slots are already loaded into the real Firestore (`firebase/seed/`). To get a seller account for testing: sign in to the app once, then ask P3 to run `set-role.mjs` to assign the role and kiosk.
