#!/usr/bin/env bash
# Create a GitHub issue for every task in TASKS.md. Run once after the repo exists and you have run `gh auth login`.
# Set the ASSIGNEE_* variables to each person's GitHub username (leave empty to skip assigning).
# Already-created issues are not duplicated by hand: to rename or update them, edit with `gh issue edit`.
set -euo pipefail
ASSIGNEE_P1=""; ASSIGNEE_P2=""; ASSIGNEE_P3=""; ASSIGNEE_P4=""

mk() { # id title owner label
  local assignee=""
  case "$3" in P1) assignee=$ASSIGNEE_P1;; P2) assignee=$ASSIGNEE_P2;; P3) assignee=$ASSIGNEE_P3;; P4) assignee=$ASSIGNEE_P4;; esac
  gh label create "$4" --force >/dev/null 2>&1 || true
  if [ -n "$assignee" ]; then
    gh issue create --title "[$1] $2" --body "Details and done-when criteria: see TASKS.md. Owner: $3" --label "$4" --assignee "$assignee"
  else
    gh issue create --title "[$1] $2" --body "Details and done-when criteria: see TASKS.md. Owner: $3" --label "$4"
  fi
}

mk "T00" "Preparation: create the repo, invite members, require PRs for main" "P1" "stage-0"
mk "T01" "Preparation: create the Firebase project and enable the 6 services" "P3" "stage-0"
mk "T02" "Preparation: test machine, ADB, ARTEMIS, test account" "P5" "stage-0"
mk "T03" "Preparation: flutter create, pin versions, flutterfire configure" "P1" "stage-0"
mk "T10" "Plan: complete design-traceability.md" "P1" "stage-1-plan"
mk "T11" "Plan: confirm the scope with the lecturer" "P4" "stage-1-plan"
mk "T20" "Architect: architecture.md and the MVVM skeleton" "P1" "stage-2-architect"
mk "T21" "Architect: theme and the Lab 2 widget library" "P1" "stage-2-architect"
mk "T22" "Architect: SDK-wrapping service layer (Firebase implementations)" "P3" "stage-2-architect"
mk "T30" "Integrate: Google Sign-In and auth-based routing" "P3" "stage-3-integrate"
mk "T31" "Integrate: Firestore model, rules, sample data" "P3" "stage-3-integrate"
mk "T32" "Integrate: storage.rules and StorageService" "P3" "stage-3-integrate"
mk "T33" "Integrate: Firestore services (Menu, Cart, Order) and ordering batch" "P3" "stage-3-integrate"
mk "T34" "Integrate: per-feature services (Slot, Voucher, Review, Favorite, Notification, Incident)" "All" "stage-3-integrate"
mk "T40" "Feature: ordering flow S03-S08, S21, S22, S25, S29 (S01, S02 done)" "P1" "stage-4-feature"
mk "T41" "Feature: after-ordering screens S09-S12, S20, S23, S24" "P2" "stage-4-feature"
mk "T42" "Feature: S15-S17, S26, S27 and the Firebase demo area" "P3" "stage-4-feature"
mk "T43" "Feature: generate a PDF and upload it" "P2" "stage-4-feature"
mk "T44" "Feature: seller app K01-K06, K12, K13" "P4" "stage-4-feature"
mk "T45" "Feature: seller menu management K08-K11, K14, K15" "P2" "stage-4-feature"
mk "T46" "Feature: S13, S14, S18, S19, S28, S30 (favorites, reorder, notifications, search, offline)" "P5" "stage-4-feature"
mk "T50" "Instrument: analytics plan and code" "P5" "stage-5-instrument"
mk "T51" "Instrument: Crashlytics" "P3" "stage-5-instrument"
mk "T52" "Instrument: Remote Config" "P3" "stage-5-instrument"
mk "T53" "Instrument: FCM in 3 states and the inbox" "P5" "stage-5-instrument"
mk "T60" "Test: test-plan.md with >= 10 cases" "P5" "stage-6-test"
mk "T61" "Test: Semantics labels for your own screens" "All" "stage-6-test"
mk "T62" "Test: write and run ARTEMIS tests, >= 3 runs each" "P5" "stage-6-test"
mk "T63" "Test: exploratory session with the Pro profile" "P5" "stage-6-test"
mk "T70" "Review: open a PR and run the AI review" "P4" "stage-7-review"
mk "T71" "Review: decide each finding, >= 3 fix commits" "All" "stage-7-review"
mk "T72" "Review: check the MVVM rules across the repo" "P1" "stage-7-review"
mk "T80" "Report: PDF report of 8-12 pages" "P4" "stage-8-report"
mk "T81" "Report: slides of 12-15 pages" "P4" "stage-8-report"
mk "T82" "Report: demo video of 5-10 minutes" "P4" "stage-8-report"
mk "T83" "Report: update Figma and the submission checklist" "P1" "stage-8-report"
