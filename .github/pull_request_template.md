<!-- Title: [ID] Summary, for example [S03] Menu screen with category filter. Rules: CONTRIBUTING.md section 4. -->

## Task
ID (for example S03 or T41):
Issue: Closes #  <!-- or Refs # when this PR is only part of the task -->

## Changes
-

## Checked
- [ ] In each Flutter package I changed (`mobile/`, `web/`, `packages/core/`): `flutter analyze`, `dart format --set-exit-if-changed .` and `flutter test` are clean
- [ ] Ran on an Android device or emulator
- [ ] Loading, empty and error states are all there (for screens that load data)
- [ ] No SDK calls directly in widgets; logic lives in a ViewModel or service
- [ ] Colors, text sizes and spacing come from the theme
- [ ] `Semantics` labels added to buttons and lists
- [ ] `docs/design-traceability.md` updated (status and deviations)
- [ ] Shared files touched? Owner told before merging (CONTRIBUTING.md section 3)
- [ ] No keys or secrets in the diff
- [ ] Data structure changed? Migration added in `firebase/seed/migrations/` and `npm run test:migrate` passes (CONTRIBUTING.md section 3.1)

## Data structure
No migration needed: <!-- write the reason, or delete this line when the PR adds a migration -->

## Screenshots
