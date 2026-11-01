# Firebase design

Source for the report section "Firebase design" (one subsection per service, with its failure handling). Every claim points to the code, a test, or a screenshot in `evidence/` (capture steps: `evidence/README.md`). Project: `breakbite-1315b` (Spark plan), Firestore in `asia-southeast1`.

Rule that applies to every service: screens never call an SDK. Each service sits behind an interface in `lib/data/services/` with a Firebase implementation in `lib/data/services/firebase/` (checked by `test/architecture_test.dart`). Every failure comes back as a `Result` with an `AppException` whose Vietnamese message the screen shows (`lib/data/firebase/firebase_errors.dart`); nothing is thrown into the UI.

## 1. Authentication

| | |
|---|---|
| Behaviour | Google Sign-In (S26). On the first sign-in `users/{uid}` is created with role `user`; later sign-ins update `lastLoginAt`. The router waits on a splash screen until the sign-in state is known, then opens Onboarding or sign-in (signed out), Home (customer) or the seller app (staff, admin). A role changed by an admin applies live, without signing in again. Signing out asks for confirmation, removes the device's FCM token and clears the session (selected kiosk). Signing in selects the default kiosk saved in the profile (S16) |
| Code | `lib/data/services/firebase/firebase_auth_service.dart`, `lib/ui/auth/`, `lib/routing/router.dart` (`authRedirect`) |
| Failure handling | Cancelled sign-in: "Bạn đã huỷ đăng nhập. Chọn tài khoản Google để tiếp tục."; no network: "Không có kết nối mạng. Thử lại khi có mạng."; Google returns no token: "Google không trả về thông tin đăng nhập. Thử lại sau."; the profile cannot be written: the app signs out again so it never runs half signed in; the auth stream fails: "Không kiểm tra được trạng thái đăng nhập…" |
| Security | `firestore.rules`: a user creates only their own profile with role `user` and no kiosk; never changes `role`, `kioskId` or `email`; profile fields are validated when they change (student ID, phone, existing kiosk, payment method) |
| Proof | `test/ui/auth/`, `test/routing/router_test.dart`, `test/app_smoke_test.dart` (opening signed in, signing out), `integration_test/firebase_emulator_test.dart` (sign-in creates `users/{uid}`, live role change), rules tests "users" |
| Evidence | `evidence/auth/1-signed-out.png`, `2-signed-in.png`, `3-cancelled.png`, `4-console-users.png` |

## 2. File storage (Cloudinary instead of Cloud Storage)

| | |
|---|---|
| Behaviour | The Firebase demo area makes a PDF summary of the customer's orders (Vietnamese text, Nunito font), uploads it to `breakbite/reports/{uid}/` with a progress bar, shows the download URL with a copy button, and saves its metadata in Firestore `reports`; "Tệp của tôi" lists only the owner's files, newest first |
| Why Cloudinary | Cloud Storage for Firebase needs the Blaze plan; the team stays on Spark. Upload uses an unsigned preset (`env/cloudinary.json`), so the app holds no API secret. To be approved by the lecturer (T11). `storage.rules` with per-user folders is kept in the repo as the fallback if Cloudinary is not approved |
| Code | `lib/data/services/cloudinary/cloudinary_storage_service.dart`, `lib/data/services/pdf/pdf_report_file_service.dart`, `lib/data/repositories/firestore/firestore_report_repository.dart`, `lib/ui/profile/widgets/firebase_demo_screen.dart` |
| Failure handling | Not configured: "Chưa cấu hình nơi lưu tệp."; larger than 5 MB: "Tệp lớn hơn 5 MB."; no network: "Không có kết nối mạng…"; timeout: "Tải lên quá lâu. Kiểm tra mạng rồi thử lại."; PDF cannot be made: "Không tạo được tệp PDF."; each failure is also recorded as a non-fatal error |
| Security | Firestore `reports`: only the owner creates and reads; the URL must be `https://`, the size 1–5120 KB; nobody edits or deletes. Limitation: a Cloudinary URL is public to anyone who has it; what is protected is the list of files |
| Proof | `test/data/services/pdf_report_file_service_test.dart`, `test/ui/profile/firebase_demo_test.dart`, rules tests "reports", integration test "exported files pass the rules"; a test upload with the preset returned HTTP 200 `application/pdf` (01/11/2026) |
| Evidence | `evidence/storage/1-progress.png`, `2-url.png`, `3-my-files.png`, `4-cloudinary-library.png`, `5-firestore-reports.png` |

## 3. Cloud Messaging (FCM)

| | |
|---|---|
| Behaviour | After sign-in the app asks for the notification permission (Android 13+), stores this device's token in `users/{uid}.fcmTokens` (at most 5) and removes it on sign-out. Every message received in the foreground, in the background or opened from a terminated app is saved once to `users/{uid}/notifications` (one id per message, so the same message never appears twice). The list (S19) and opening the related screen are P5's (T53) |
| Code | `lib/data/services/firebase/firebase_messaging_service.dart`, `notification_inbox.dart`, background handler in `lib/config/firebase_setup.dart` |
| Failure handling | Permission refused or the request fails: the app keeps working, only without system notifications; a missing token, a failed token write or removal is caught and never blocks sign-in or sign-out |
| Proof | `test/data/services/firebase/firebase_service_mapping_test.dart` (ids, titles, data-only messages), integration test "inbox" |
| Evidence | `evidence/fcm/1-permission.png`, `2-foreground.png`, `3-background.png`, `4-terminated.png`, `5-inbox.png` (S19, P5) |

## 4. Analytics

| | |
|---|---|
| Behaviour | Event plan in `docs/analytics-plan.md`. Logged today: `login`, `logout`, `add_to_cart`, `reorder`, `export_report`; `setUserId(uid)` after sign-in, cleared on sign-out. Parameters are numbers and short strings only, never a name or an email |
| Code | `lib/data/services/firebase/firebase_analytics_service.dart`, names in `lib/data/services/analytics_events.dart` |
| Failure handling | Logging never throws; a failed log is ignored so it cannot break a flow |
| Proof | `test/data/services/firebase/firebase_service_mapping_test.dart` (parameter cleaning), view model tests that assert each event |
| Evidence | `evidence/analytics/<event>.png` (DebugView, one per event; owner P5) |

## 5. Crashlytics

| | |
|---|---|
| Behaviour | Uncaught Flutter and platform errors are reported (`reportUncaughtErrors`). Handled errors from real error paths (network, permission, a failed write) are recorded through `crash.recordNonFatal`, which sends the real cause and skips actions the user cancelled. User id and the custom keys `role` and `kiosk_id` are set after sign-in. The demo area has "Ghi lỗi thử" (non-fatal) and "Làm sập app thử" (test crash, behind a confirmation). Turned on in the console on 01/11/2026 |
| Code | `lib/data/services/firebase/firebase_crash_service.dart`, `lib/data/services/crash_service.dart`, `lib/config/firebase_setup.dart` |
| Failure handling | Reporting itself never throws |
| Proof | `test/data/services/crash_service_test.dart`, view model tests that assert `crash.errors` on failures |
| Evidence | `evidence/crashlytics/1-non-fatal.png`, `2-crash.png`, `3-keys.png` (issue page showing user id, `role`, `kiosk_id`) |

## 6. Remote Config

| | |
|---|---|
| Behaviour | Three parameters with in-app defaults (`RemoteKeys.defaults`, matched against `firebase/remote-config-defaults.json` and the console template by a test): `quick_items_limit` (number of quick items on Home), `promo_banner_enabled` (Golden Hour banner on Home), `pickup_slot_enabled` (pickup time, S25). The app listens for real-time updates, so publishing in the console changes Home without a rebuild or restart. The demo area shows each value, whether it came from the console or the in-app default, and the last fetch time |
| Code | `lib/data/services/firebase/firebase_remote_config_service.dart`, `lib/ui/home/view_models/home_view_model.dart` |
| Failure handling | No network or a failed fetch: the app keeps the last values, or the in-app defaults on a first launch |
| Proof | `test/ui/home/` (a published value updates Home), `test/ui/profile/firebase_demo_test.dart`, defaults test in `firebase_service_mapping_test.dart` |
| Evidence | `evidence/remote-config/1-before.png`, `2-console.png`, `3-after.png` |

## 7. Firestore (data behind every service)

Collections, rules and queries: `docs/data-model.md`. Deny by default, access by role, and staff only act on their own kiosk. Every write that depends on current data (placing, editing, cancelling an order, each staff step) runs in a transaction, so the customer sees a clear reason instead of a rules rejection. Rules are tested on the Emulator (85 tests, `firebase/tests/rules.test.mjs`) and by the integration test against the real rules (11 tests). Structure changes ship with a migration (`CONTRIBUTING.md` section 3.1); the T31 migration ran on the real project on 01/11/2026.
