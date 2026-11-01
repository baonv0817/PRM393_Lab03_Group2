# Evidence

Screenshots and tool output that back every claim in the report. A criterion without evidence here or in the report is graded as not met. Name files exactly as below so `docs/firebase-design.md` and the report can link to them.

## Before capturing

1. Real build on an Android phone: `flutter run --dart-define-from-file=env/cloudinary.json` (VS Code: "BreakBite (real Firebase)"). The machine's debug SHA-1 must be registered in the Firebase project (`docs/setup.md` section 4).
2. Use the team test Google account. Never show a personal email, a key or a token in a screenshot; crop or blur them.
3. Phone screenshots at the phone's resolution; console screenshots of the whole page so the project name `breakbite-1315b` is visible.

## Firebase (owner P3 unless noted)

| File | Steps | It must show |
|---|---|---|
| `auth/1-signed-out.png` | Uninstall and reinstall, open the app, skip Onboarding | S26 sign-in screen |
| `auth/2-signed-in.png` | Tap "Đăng nhập bằng Google", pick the account | Home with the kiosk and the quick items |
| `auth/3-cancelled.png` | Sign out, tap sign-in, close the account picker | The red "Bạn đã huỷ đăng nhập…" message |
| `auth/4-console-users.png` | Console, Authentication, Users | The test account with provider Google |
| `storage/1-progress.png` | Profile, "Khu demo Firebase", "Xuất và tải lên", capture while uploading | "Đang tải lên NN%" and the progress bar |
| `storage/2-url.png` | Wait for the upload to finish | "Đã tải lên" card with the `https://res.cloudinary.com/…` link |
| `storage/3-my-files.png` | Scroll to "Tệp của tôi" | The new file with size and time |
| `storage/4-cloudinary-library.png` | Cloudinary console, Media Library, folder `breakbite/reports/<uid>` | The PDF |
| `storage/5-firestore-reports.png` | Firebase console, Firestore, `reports` | The document with `uid`, `url`, `sizeKb` |
| `crashlytics/1-non-fatal.png` | Demo area, "Ghi lỗi thử"; wait a few minutes | Crashlytics, Non-fatals: "Firebase demo: handled test error" |
| `crashlytics/2-crash.png` | Demo area, "Làm sập app thử", confirm, then open the app again | Crashlytics, Crashes: the test crash |
| `crashlytics/3-keys.png` | Open either issue, Keys tab | user id, `role`, `kiosk_id` |
| `remote-config/1-before.png` | Open Home with the default values | 5 quick items and the Golden Hour banner |
| `remote-config/2-console.png` | Console, Remote Config: `quick_items_limit` = 2, `promo_banner_enabled` = false, Publish | The published values |
| `remote-config/3-after.png` | Look at Home without restarting the app | 2 quick items, no banner; the demo area says "từ console" |
| `fcm/1-permission.png` | First sign-in on Android 13+ (P5) | The system notification permission dialog |
| `fcm/2-foreground.png`, `3-background.png`, `4-terminated.png` | Console, Messaging, "Send test message" to the device token, in each app state (P5) | The notification in that state |
| `fcm/5-inbox.png` | Open S19 after the three messages (P5) | The three notifications in the list |
| `analytics/<event>.png` | Analytics, DebugView with debug mode on (`adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite`) (P5) | Each event of `docs/analytics-plan.md` with its parameters |

## Other criteria

| Folder | Owner | Content |
|---|---|---|
| `artemis/` | P5 | Command used, trace or screenshots per run, results table |
| `code-review/` | P4 | AI review tool output |
| `figma/` | P1 | Figma vs app side by side for the slides |
