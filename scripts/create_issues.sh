#!/usr/bin/env bash
# Tạo GitHub issue cho từng task trong TASKS.md. Chạy một lần sau khi đã tạo repo và đăng nhập `gh auth login`.
# Sửa biến ASSIGNEE_* thành tên GitHub của từng người (để trống nếu chưa gán).
set -euo pipefail
ASSIGNEE_P1=""; ASSIGNEE_P2=""; ASSIGNEE_P3=""; ASSIGNEE_P4=""

mk() { # id title owner label
  local assignee=""
  case "$3" in P1) assignee=$ASSIGNEE_P1;; P2) assignee=$ASSIGNEE_P2;; P3) assignee=$ASSIGNEE_P3;; P4) assignee=$ASSIGNEE_P4;; esac
  gh label create "$4" --force >/dev/null 2>&1 || true
  if [ -n "$assignee" ]; then
    gh issue create --title "[$1] $2" --body "Chi tiết và điều kiện xong: xem TASKS.md. Người phụ trách: $3" --label "$4" --assignee "$assignee"
  else
    gh issue create --title "[$1] $2" --body "Chi tiết và điều kiện xong: xem TASKS.md. Người phụ trách: $3" --label "$4"
  fi
}

mk "T00" "Chuẩn bị: tạo repo, mời thành viên, bật PR cho main" "P1" "stage-0"
mk "T01" "Chuẩn bị: tạo Firebase project và bật 6 dịch vụ" "P3" "stage-0"
mk "T02" "Chuẩn bị: máy test, ADB, ARTEMIS, tài khoản test" "P4" "stage-0"
mk "T03" "Chuẩn bị: flutter create, ghim phiên bản, flutterfire configure" "P1" "stage-0"
mk "T10" "Plan: hoàn thiện design-traceability.md" "P1" "stage-1-plan"
mk "T11" "Plan: chốt phạm vi với thầy" "P4" "stage-1-plan"
mk "T20" "Architect: architecture.md và khung MVVM" "P1" "stage-2-architect"
mk "T21" "Architect: theme và thư viện widget Lab 2" "P1" "stage-2-architect"
mk "T22" "Architect: tầng service bọc SDK" "P3" "stage-2-architect"
mk "T30" "Integrate: Google Sign-In và định tuyến theo auth" "P3" "stage-3-integrate"
mk "T31" "Integrate: mô hình Firestore, rules, dữ liệu mẫu" "P3" "stage-3-integrate"
mk "T32" "Integrate: storage.rules và StorageService" "P3" "stage-3-integrate"
mk "T40" "Feature: luồng đặt món S01-S08" "P1" "stage-4-feature"
mk "T41" "Feature: app khách S09-S14, S19-S25, S27-S30" "P2" "stage-4-feature"
mk "T42" "Feature: S15-S18, S26 và khu demo Firebase" "P3" "stage-4-feature"
mk "T43" "Feature: sinh PDF và tải lên" "P2" "stage-4-feature"
mk "T44" "Feature: app người bán K01-K06" "P3" "stage-4-feature"
mk "T45" "Feature: app người bán K08-K15" "P4" "stage-4-feature"
mk "T50" "Instrument: analytics plan và code" "P3" "stage-5-instrument"
mk "T51" "Instrument: Crashlytics" "P3" "stage-5-instrument"
mk "T52" "Instrument: Remote Config" "P3" "stage-5-instrument"
mk "T53" "Instrument: FCM 3 trạng thái và inbox" "P3" "stage-5-instrument"
mk "T60" "Test: test-plan.md >= 10 case" "P4" "stage-6-test"
mk "T61" "Test: Semantics label cho màn của mình" "All" "stage-6-test"
mk "T62" "Test: viết và chạy ARTEMIS, >= 3 lần mỗi test" "P4" "stage-6-test"
mk "T63" "Test: phiên khám phá hồ sơ Pro" "P4" "stage-6-test"
mk "T70" "Review: mở PR và chạy AI review" "P4" "stage-7-review"
mk "T71" "Review: quyết định từng phát hiện, >= 3 commit sửa" "All" "stage-7-review"
mk "T72" "Review: kiểm quy tắc MVVM toàn repo" "P1" "stage-7-review"
mk "T80" "Report: báo cáo PDF 8-12 trang" "P4" "stage-8-report"
mk "T81" "Report: slide 12-15 trang" "P4" "stage-8-report"
mk "T82" "Report: video demo 5-10 phút" "P4" "stage-8-report"
mk "T83" "Report: cập nhật Figma và checklist nộp bài" "P1" "stage-8-report"
