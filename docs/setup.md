# Environment setup (Windows)

The steps below were run on the machine that built the skeleton on 28/10/2026. Each member repeats them on their own machine; section 1 is only needed if you hit the Java error.

## 1. Fix the Java error "Unable to establish loopback connection"

On some Windows machines, Java 21 cannot create a local socket in the default temp folder. Symptom: the Firebase Emulator, `sdkmanager` or Gradle exits immediately with `Unable to establish loopback connection`. Fix:

```powershell
mkdir D:\tmp\java
setx JAVA_TOOL_OPTIONS "-Djava.io.tmpdir=D:/tmp/java -Djdk.net.unixdomain.tmpdir=D:/tmp/java"
```

Reopen your terminal and IDE after setting it.

## 2. Flutter and the Android SDK

| Component | Version used | Notes |
|---|---|---|
| Flutter | 3.47.5 (stable), Dart 3.13.4 | extract to `D:\src\flutter`, add `bin` to PATH |
| JDK | 21 | `flutter config --jdk-dir "C:\Program Files\Java\jdk-21"` |
| Android command-line tools | `commandlinetools-win-16111833` | extract to `D:\src\android-sdk\cmdline-tools\latest` |
| Platform | android-36, android-35 | |
| Build-tools | 36.0.0, 35.0.0 | |
| platform-tools (adb) | 37.0.1 | |
| NDK | 28.2.13676358 | needed by Gradle; install by hand because the new `sdkmanager` fails on the `;` character |

Set the user environment variables `ANDROID_HOME` and `ANDROID_SDK_ROOT` to `D:\src\android-sdk`, add `D:\src\android-sdk\platform-tools` to PATH, then:

```powershell
flutter config --android-sdk D:\src\android-sdk
flutter doctor --android-licenses     # answer y
flutter doctor -v                     # must report "No issues found"
```

Install packages with the `android` command (replaces `sdkmanager`):

```powershell
$a = "D:\src\android-sdk\cmdline-tools\latest\bin\android.exe"
& $a --sdk=D:\src\android-sdk sdk install "platforms/android-36" "build-tools/36.0.0" "ndk/28.2.13676358"
```

### Kotlin build error "different roots"

If `flutter build apk` reports `Could not close incremental caches ... this and base files have different roots`, the project (drive D) and the Pub packages (drive C) are on different drives. The repo already sets `kotlin.incremental=false` in `android/gradle.properties` to avoid this. The first build takes about 5 to 7 minutes because Gradle downloads libraries.

## 3. Android phone

1. Settings, About phone, tap **Build number** 7 times to enable Developer options (on a Vietnamese-language phone: Cài đặt, Giới thiệu điện thoại, Số bản dựng).
2. Turn on **USB debugging**, plug in the cable, and choose "Allow USB debugging" on the phone.
3. `adb devices` must list the device with state `device` (not `unauthorized`).
4. Install the app: `flutter run -t dev/main_dev.dart`.

### No Android phone (emulator, Chrome, iPhone)

You cannot run the app on an iPhone from a Windows machine (iOS builds need a Mac and Xcode). On Windows pick one of the two options below. A real Android phone is only needed to try the real Google sign-in and to run ARTEMIS, and the team shares one for that.

**Option 1: Chrome with a phone frame (lightest).**

1. In VS Code install the **Flutter** extension (Dart Code), choose the **Chrome (web)** device at the bottom right and press **F5**. The `.vscode/launch.json` configurations already run with fake data (entry point `dev/main_dev.dart`).
2. In the browser window press `F12`, then `Ctrl+Shift+M` and choose an iPhone or Pixel to see the phone frame.

The web build is only for looking at the UI: Firebase is configured for Android only, so it runs with fake data.

**Option 2: Android Emulator (closest to a real phone, needs about 3 GB of disk and 8 GB of free RAM).**

```powershell
$a = "D:\src\android-sdk\cmdline-tools\latest\bin\android.exe"
& $a --sdk=D:\src\android-sdk sdk install "emulator" "system-images/android-35/google_apis_playstore/x86_64"
mkdir D:\src\android-avd
setx ANDROID_AVD_HOME D:\src\android-avd
$env:ANDROID_AVD_HOME = "D:\src\android-avd"
D:\src\android-sdk\cmdline-tools\latest\bin\avdmanager.bat create avd -n Pixel8_API35 -k "system-images;android-35;google_apis_playstore;x86_64" -d pixel_8
```

Reopen the terminal and VS Code, start the emulator with `flutter emulators --launch Pixel8_API35`, then run `flutter run -t dev/main_dev.dart`. Start **only one** emulator: starting a second one reports `The Android emulator exited with code 1` or leaves the emulator stuck in the `offline` state. If it gets stuck, end the `emulator` and `qemu-system-x86_64` processes in Task Manager and start again. The first boot takes a few minutes.

Each person's emulator uses the debug key of that machine: send your machine's SHA-1 to whoever holds the Firebase project (see section 4) so Google Sign-in works.

**Skipping sign-in with fake data.** The real app signs in on S26 with Google. With fake data, add `--dart-define=DEV_SIGNED_IN=true` to go straight into the customer app, and `--dart-define=DEV_ROLE=staff` to go into the seller app. In VS Code pick the "BreakBite customer (fake data, signed in)" or "BreakBite seller (fake data, signed in)" configuration and press F5. These two flags only affect the fake services and are removed together with `lib/dev/` before submission (T83).

## 4. Firebase

```powershell
npm install -g firebase-tools           # 15.34.1
dart pub global activate flutterfire_cli # 1.4.1; add %LOCALAPPDATA%\Pub\Cache\bin to PATH
firebase login
flutterfire configure --project <firebase-project-id>   # generates lib/firebase_options.dart (tasks T01, T03)
```

The team project is `breakbite-1315b` (Spark plan; files go to Cloudinary, see below). `lib/firebase_options.dart` and `android/app/google-services.json` are already in the repo, so a newcomer **does not need** to run `flutterfire configure` again; they only need to be invited to the project (Project settings, Users and permissions, role Editor).

**SHA-1 for Google Sign-in.** Every machine has its own debug key, so each person gets the SHA-1 of their own machine and sends it to whoever holds the project, to add under Project settings, Your apps, BreakBite, Add fingerprint. Until it is added, Google sign-in fails with `ApiException: 10`.

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"
```

If it says the keystore file is missing, run a Flutter app once so the machine creates it. A SHA-1 is a public fingerprint, so it is fine to send in the team chat; **do not** share the keystore file or the service-account file `*-adminsdk-*.json`.

Run the rules tests: see `firebase/README.md`.

### Cloudinary (file uploads)

Files (PDF receipts, photos) are stored on Cloudinary instead of Cloud Storage for Firebase, which needs the Blaze plan (`docs/data-model.md` section 6). One person sets this up once for the team:

1. Create a free account at cloudinary.com; note the **cloud name** on the dashboard.
2. Settings → Upload → Upload presets → Add: **Signing mode: Unsigned**, allowed formats `pdf,jpg,png,webp`, unique file name on, overwrite off. Note the preset name.
3. Settings → Security → tick **Allow delivery of PDF and ZIP files** and save (new accounts block PDF links otherwise).
4. Put both values in `env/cloudinary.json` and commit it. They are not secrets: an unsigned preset is meant to be used from the app. Never put the API key or API secret in the repo.
5. Run the real app with `flutter run --dart-define-from-file=env/cloudinary.json` (the VS Code configuration "BreakBite (real Firebase)" already passes it).

### Firebase Emulator (local data)

To try flows, rules and ARTEMIS runs without touching the real project:

```powershell
# terminal 1: start Auth and Firestore emulators (data is lost when they stop)
firebase emulators:start --only auth,firestore --project breakbite-1315b

# terminal 2: load the sample menu, kiosks, vouchers and slots into them
cd firebase/seed
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"; $env:GCLOUD_PROJECT = "breakbite-1315b"; node seed.mjs
```

Then press F5 with **"BreakBite (Firebase Emulator)"**, or run `flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define-from-file=env/cloudinary.json`. The app connects to `10.0.2.2` on the Android emulator and `localhost` elsewhere; on a physical phone add `--dart-define=FIREBASE_EMULATOR_HOST=<your PC LAN IP>`. Only debug builds can use the emulator (cleartext traffic to those hosts is allowed in `android/app/src/debug/` only). Google Sign-In in the Auth emulator shows a fake account picker, so no real account is needed.

**Integration test against the real rules.** `integration_test/firebase_emulator_test.dart` runs the real Firebase code (sign-in and `users/{uid}`, menu, cart, placing, editing and cancelling an order, the staff steps, menu editing, the notification inbox, the staff side of customer reports (K13), favorites, notifications and the S18 switches) against the Auth and Firestore emulators with `firebase/firestore.rules`, and checks the rules refuse what they must (a customer accepting an order, staff of another kiosk). On an Android emulator:

```powershell
firebase emulators:exec --only auth,firestore --project breakbite-1315b "flutter test integration_test/firebase_emulator_test.dart --dart-define=USE_FIREBASE_EMULATOR=true"
```

Without an Android emulator it runs in Chrome: start `chromedriver --port=4444` (same major version as Chrome, from Chrome for Testing), then

```powershell
firebase emulators:exec --only auth,firestore --project breakbite-1315b "flutter drive --driver=test_driver/integration_test.dart --target=integration_test/firebase_emulator_test.dart -d web-server --browser-name=chrome --headless"
```

### Sending a test push (T53)

Firebase console → Messaging → New campaign → Notifications → "Send test message", paste the FCM token (the app prints it in the debug log after sign-in; it is also in `users/{uid}.fcmTokens`). Under "Additional options → Custom data" add the key `orderId` with the id of one of your orders.

| App state | What happens |
|---|---|
| Foreground | A banner shows the title and text; "Xem" opens the order (or S19 when there is no `orderId`) |
| Background | The system shows the notification; tapping it opens the order |
| Terminated | Same; the order opens right after the splash screen, once the sign-in state is known |

In every state the message is also saved in S19. Staff accounts are not sent to customer screens.

## 5. ARTEMIS (E2E tests)

See `e2e_test/README.md`. The server lives in `D:\src\artemis`, pinned to commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`. It needs an API key for a multimodal model (Gemini, Claude, GPT-4o or Qwen-VL) in the ARTEMIS server's `.env`; **never commit the key**.

## 6. Quick check

```powershell
cd <repo>
flutter pub get
flutter analyze
flutter test                      # all unit and widget tests, no device needed
flutter build apk --debug         # needs the SDK and NDK from section 2
```
