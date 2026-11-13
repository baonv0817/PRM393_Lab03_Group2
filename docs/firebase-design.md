# Firebase design

Source for the report section "Firebase design" (one subsection per service, with its failure handling). Every claim points to the code, a test, or a screenshot in `evidence/` (capture steps: `evidence/README.md`). Project: `breakbite-1315b` (Spark plan), Firestore in `asia-southeast1`.

Rule that applies to every service: screens never call an SDK. Each service sits behind an interface in `packages/core/lib/data/services/`, shared by the Android app (`mobile/`) and the web admin (`web/`). The Firebase implementations both clients use (Auth, Analytics, Remote Config) are in `packages/core/lib/data/services/firebase/`; the ones that need an Android plugin (Crashlytics, FCM, AI Logic) are in `mobile/lib/data/services/firebase/` (checked by `mobile/test/architecture_test.dart` and `web/test/architecture_test.dart`; layout in [`architecture.md`](architecture.md)). Every failure comes back as a `Result` with an `AppException` whose Vietnamese message the screen shows (`packages/core/lib/data/firebase/firebase_errors.dart`); nothing is thrown into the UI. Unless a path starts with `packages/`, `web/` or `firebase/`, the paths `lib/`, `test/` and `integration_test/` below are under `mobile/`.

## 1. Authentication

| | |
|---|---|
| Behaviour | Google Sign-In, or e-mail and password ("Tạo tài khoản"), on both clients (S26 on the phone, W01 on the web). On the first sign-in `users/{uid}` is created with role `user`; later sign-ins update `lastLoginAt`. The router waits on a splash screen until the sign-in state is known, then opens Onboarding or sign-in (signed out), Home (customer) or the seller app (staff). Each client turns away the wrong role with a message and signs it out: the phone refuses an admin and points to the web admin (`mobileAccessProblem`), the web refuses a customer (`webAdminAccessProblem`). A role changed by an admin applies live, without signing in again. Signing out asks for confirmation, removes the device's FCM token and clears the session (selected kiosk). Signing in selects the default kiosk saved in the profile (S16) |
| Code | `packages/core/lib/data/services/firebase/firebase_auth_service.dart` (`FirebaseAuthService.web` for the browser), `packages/core/lib/domain/mobile_access.dart` and `web_access.dart`, `lib/ui/auth/`, `lib/routing/router.dart` (`authRedirect`), `web/lib/ui/shell/view_models/admin_session.dart` |
| Failure handling | Cancelled sign-in: "Bạn đã huỷ đăng nhập. Chọn tài khoản Google để tiếp tục."; no network: "Không có kết nối mạng. Thử lại khi có mạng."; Google returns no token: "Google không trả về thông tin đăng nhập. Thử lại sau."; the profile cannot be written: the app signs out again so it never runs half signed in; the auth stream fails: "Không kiểm tra được trạng thái đăng nhập…" |
| Security | `firestore.rules`: a user creates only their own profile with role `user` and no kiosk; never changes `role`, `kioskId` or `email` (only an admin changes another account's role, tests R-02, R-05); profile fields are validated when they change (student ID, phone, existing kiosk, payment method) |
| Proof | `test/ui/auth/`, `test/routing/router_test.dart`, `test/app_smoke_test.dart` (opening signed in, signing out), `integration_test/firebase_emulator_test.dart` (sign-in creates `users/{uid}`, live role change), `web/test/view_models_test.dart` (a customer is turned away), rules tests "users" |
| Evidence | `evidence/auth/1-signed-out.png`, `2-signed-in.png`, `3-cancelled.png`, `4-console-users.png`; web: `evidence/web/W01-sign-in.png`, `W01-error.png`, `W01-role-rejection.png` |

## 2. File storage (Cloudinary instead of Cloud Storage)

| | |
|---|---|
| Behaviour | The Firebase demo area makes a PDF summary of the customer's orders (Vietnamese text, Nunito font), uploads it to `breakbite/reports/{uid}/` with a progress bar, shows the download URL with a copy button, and saves its metadata in Firestore `reports`; "Tệp của tôi" lists only the owner's files, newest first |
| Why Cloudinary | Cloud Storage for Firebase needs the Blaze plan; the team stays on Spark. Upload uses an unsigned preset (`env/cloudinary.json`), so the app holds no API secret. The lecturer confirmed in writing that Cloudinary or S3 is acceptable (README, "Deviations from the handout"). `storage.rules` with per-user folders stays in the repo, tested, in case the project moves to Blaze |
| Code | `packages/core/lib/data/services/cloudinary/cloudinary_storage_service.dart`, `lib/data/services/pdf/pdf_report_file_service.dart`, `packages/core/lib/data/repositories/firestore/firestore_report_repository.dart`, `lib/ui/profile/widgets/firebase_demo_screen.dart` |
| Failure handling | Not configured: "Chưa cấu hình nơi lưu tệp."; larger than 5 MB: "Tệp lớn hơn 5 MB."; no network: "Không có kết nối mạng…"; timeout: "Tải lên quá lâu. Kiểm tra mạng rồi thử lại."; PDF cannot be made: "Không tạo được tệp PDF."; each failure is also recorded as a non-fatal error |
| Security | Firestore `reports`: only the owner creates and reads; the URL must be `https://`, the size 1–5120 KB; nobody edits or deletes. Limitation: a Cloudinary URL is public to anyone who has it; what is protected is the list of files |
| Proof | `test/data/services/pdf_report_file_service_test.dart`, `test/ui/profile/firebase_demo_test.dart`, rules tests "reports", integration test "exported files pass the rules"; a test upload with the preset returned HTTP 200 `application/pdf` (01/11/2026) |
| Evidence | `evidence/storage/1-progress.png`, `2-url.png`, `3-my-files.png`, `4-cloudinary-library.png`, `5-firestore-reports.png` |

## 3. Cloud Messaging (FCM)

| | |
|---|---|
| Behaviour | After sign-in the app asks for the notification permission (Android 13+), stores this device's token in `users/{uid}.fcmTokens` (at most 5) and removes it on sign-out. Every message received in the foreground, in the background or opened from a terminated app is saved once to `users/{uid}/notifications` (one id per message, so the same message never appears twice). S19 lists them together with the announcements an admin publishes on the web (W05), live (`AnnouncementInboxRepository`, [`cross-role-flow.md`](cross-role-flow.md) flow 2) |
| Code | `lib/data/services/firebase/firebase_messaging_service.dart`, `notification_inbox.dart`, background handler in `lib/config/firebase_setup.dart` (it activates App Check in its own isolate, CR-F03), `packages/core/lib/data/repositories/announcement_inbox_repository.dart` |
| Failure handling | Permission refused or the request fails: the app keeps working, only without system notifications; a missing token, a failed token write or removal is caught and never blocks sign-in or sign-out |
| Proof | `test/data/services/firebase/firebase_service_mapping_test.dart` (ids, titles, data-only messages), integration test "inbox" |
| Evidence | `evidence/fcm/1-permission.png`, `2-foreground.png`, `3-background.png`, `4-terminated.png`, `5-inbox.png` (S19, P5) |

## 4. Analytics

| | |
|---|---|
| Behaviour | Event plan in `docs/analytics-plan.md`: on the phone `login`, `logout`, `search`, `view_menu_item`, `add_to_cart`, `reorder`, `begin_checkout`, `purchase`, `payment_failed`, `export_report`, `order_accepted`, `order_delivered` and the AI feature's `ai_request`, `ai_result_accepted`, `ai_error`; on the web `admin_sign_in`, `order_reviewed`, `menu_item_saved`, `menu_item_archived`, `announcement_saved`. `setUserId(uid)` after sign-in, cleared on sign-out. Parameters are numbers and short strings only, never a name or an email |
| Code | `packages/core/lib/data/services/firebase/firebase_analytics_service.dart` (both clients), names in `packages/core/lib/data/services/analytics_events.dart` |
| Failure handling | Logging never throws; a failed log is ignored so it cannot break a flow |
| Proof | `test/data/services/firebase/firebase_service_mapping_test.dart` (parameter cleaning), view model tests that assert each event (`web/test/view_models_test.dart` for the web events) |
| Evidence | `evidence/analytics/` (DebugView; the "Evidence" table of `docs/analytics-plan.md` maps each event to its screenshot) |

## 5. Crashlytics

| | |
|---|---|
| Behaviour | Uncaught Flutter and platform errors are reported (`reportUncaughtErrors`). Handled errors from real error paths (network, permission, a failed write) are recorded through `crash.recordNonFatal`, which sends the real cause and skips actions the user cancelled. User id and the custom keys `role` and `kiosk_id` (the staff member's kiosk, otherwise the kiosk the customer picked) are set after sign-in and follow a kiosk change. A listener the rules refuse right after sign-out ends quietly instead of being reported. The demo area has "Ghi lỗi thử" (non-fatal) and "Làm sập app thử" (test crash, behind a confirmation). Turned on in the console on 01/11/2026 |
| Code | `lib/data/services/firebase/firebase_crash_service.dart`, `packages/core/lib/data/services/crash_service.dart`, `lib/config/firebase_setup.dart` |
| Failure handling | Reporting itself never throws |
| Proof | `test/data/services/crash_service_test.dart`, view model tests that assert `crash.errors` on failures |
| Evidence | `evidence/crashlytics/1-non-fatal.png`, `2-crash.png`, `3-keys.png` (issue page showing user id, `role`, `kiosk_id`) |

## 6. Remote Config

| | |
|---|---|
| Behaviour | Seven parameters with in-app defaults (`RemoteKeys.defaults`, matched against `firebase/remote-config-defaults.json` and the console template by a test): `quick_items_limit` (number of quick items on Home), `promo_banner_enabled` (Golden Hour banner on Home), `pickup_slot_enabled` (pickup time, S25); for the AI feature `ai_enabled`, `ai_model`, `ai_prompt` (K14, [`ai-feature.md`](ai-feature.md)); and for the web `reject_reasons`, the reasons W03 offers when it rejects an order. The app listens for real-time updates, so publishing in the console changes Home without a rebuild or restart. The demo area shows each value, whether it came from the console or the in-app default, and the last fetch time |
| Code | `packages/core/lib/data/services/firebase/firebase_remote_config_service.dart` (both clients), `lib/ui/home/view_models/home_view_model.dart`, `web/lib/ui/review_queue/view_models/review_queue_view_model.dart` |
| Failure handling | No network or a failed fetch: the app keeps the last values, or the in-app defaults on a first launch |
| Proof | `test/ui/home/` (a published value updates Home), `test/ui/profile/firebase_demo_test.dart`, defaults test in `firebase_service_mapping_test.dart` |
| Evidence | `evidence/remote-config/1-before.png`, `2-console.png`, `3-after.png` |

## 7. Firestore (data behind every service)

Collections, rules and queries: `docs/data-model.md`. Deny by default, access by role, and staff only act on their own kiosk. Every write that depends on current data (placing, editing, cancelling an order, each staff step) runs in a transaction, so the customer sees a clear reason instead of a rules rejection. The web admin writes through the same repositories and the same rules (staff approve and reject only their own kiosk's orders; only admins write announcements and roles). Rules are tested on the Emulator (172 tests, including the Appendix B matrix of 80 cases, `firebase/tests/rules.test.mjs`, [`test-report.md`](test-report.md) section 1) and by the integration test against the real rules (11 tests). Structure changes ship with a migration (`CONTRIBUTING.md` section 3.1); the T31 migration ran on the real project on 01/11/2026.

## 8. App Check

| | |
|---|---|
| Behaviour | Both clients send an App Check token with their Firestore and AI Logic calls. Android: Play Integrity in a release build, the debug provider only in a debug build (CR-F05), with a debug token registered in the console. Web: reCAPTCHA Enterprise (site key in `web/lib/config/firebase_setup.dart`; reCAPTCHA v3 is no longer offered for App Check) |
| Code | `lib/config/firebase_setup.dart` (`activateAppCheck`, also called by the background push handler), `web/lib/config/firebase_setup.dart` |
| Secrets | The debug token lives only in `mobile/env/app_check.json` (gitignored); the reCAPTCHA secret stays with Google and is never in the repository |
| Status | **Enforced** for Cloud Firestore and Firebase AI Logic (Firestore on 13/11/2026; [`evidence/app-check/enforced-firestore-ai-logic-2026-11-13.png`](../evidence/app-check/enforced-firestore-ai-logic-2026-11-13.png)). Requests without a valid token are refused. Before enforcing, the 7-day metrics were 80 % verified, 15 % from outdated clients (builds made before App Check) and 5 % invalid; the current clients were checked first (the phone's debug token is the registered one; the web's reCAPTCHA Enterprise exchange answers 200) and again 15 minutes after enforcement, when it applies (13:55: the phone loads Home and writes the cart; 13:56: the web admin's review queue loads, 9 of 9 Firestore responses 200, [`web-review-after-enforcement`](../evidence/app-check/web-review-after-enforcement-2026-11-13.png)) |
| Limitation | The Android app has no Play Integrity registration (it needs the app on Google Play), so only a debug build whose debug token is registered in the console reaches Firestore; a sideloaded release APK is refused. The demo and the tests use the debug build |

## 9. Firebase AI Logic (Gemini)

| | |
|---|---|
| Behaviour | K14: staff choose a dish photo and "Điền bằng AI" fills name, kind, price, time and description; every field is labelled and stays editable. Model `gemini-3.5-flash-lite` through the Gemini Developer API with structured output. Details: [`ai-feature.md`](ai-feature.md) |
| Code | `lib/data/services/firebase/firebase_menu_ai_service.dart`, `lib/ui/seller_menu/view_models/menu_item_form_view_model.dart`, `packages/core/lib/domain/models/menu_item_suggestion.dart` |
| Failure handling | Turned off by Remote Config, quota, no network, a photo that is not food, an answer that does not parse: a Vietnamese message, `ai_error` with the reason, and the form still works by hand |
| Proof | `test/ui/seller_menu/menu_item_form_ai_test.dart`, ARTEMIS TC-40 and TC-41 ([`test-plan.md`](test-plan.md)) |
| Evidence | `evidence/ai/` |

## 10. Hosting (web admin)

| | |
|---|---|
| Behaviour | The web admin is a Flutter Web build served at https://breakbite-1315b.web.app, with every path rewritten to `index.html`. Code (`js`, `json`, `wasm`, `html`) is served `no-cache`, so a new deploy is picked up on the next load; images and fonts are cached for one hour |
| Code | `firebase/firebase.json` (`hosting`); the build is copied to `firebase/web-build/` (gitignored) before `firebase deploy --only hosting` (README, "Web admin") |
| Evidence | `evidence/web/` (every screen was taken on the deployed site) |
