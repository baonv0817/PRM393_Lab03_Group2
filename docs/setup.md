# Cài môi trường (Windows)

Các bước dưới đây đã chạy trên máy dựng khung ngày 28/10/2026. Mỗi thành viên làm lại trên máy mình; mục 1 chỉ cần khi gặp lỗi Java.

## 1. Sửa lỗi Java "Unable to establish loopback connection"

Trên một số máy Windows, Java 21 không tạo được socket nội bộ ở thư mục tạm mặc định. Biểu hiện: Firebase Emulator, `sdkmanager` hoặc Gradle thoát ngay với lỗi `Unable to establish loopback connection`. Sửa:

```powershell
mkdir D:\tmp\java
setx JAVA_TOOL_OPTIONS "-Djava.io.tmpdir=D:/tmp/java -Djdk.net.unixdomain.tmpdir=D:/tmp/java"
```

Mở lại terminal và IDE sau khi đặt.

## 2. Flutter và Android SDK

| Thành phần | Phiên bản đã dùng | Ghi chú |
|---|---|---|
| Flutter | 3.47.5 (stable), Dart 3.13.4 | giải nén vào `D:\src\flutter`, thêm `bin` vào PATH |
| JDK | 21 | `flutter config --jdk-dir "C:\Program Files\Java\jdk-21"` |
| Android command-line tools | `commandlinetools-win-16111833` | giải nén vào `D:\src\android-sdk\cmdline-tools\latest` |
| Platform | android-36, android-35 | |
| Build-tools | 36.0.0, 35.0.0 | |
| platform-tools (adb) | 37.0.1 | |
| NDK | 28.2.13676358 | Gradle cần; cài tay vì `sdkmanager` mới lỗi với dấu `;` |

Đặt biến môi trường người dùng `ANDROID_HOME` và `ANDROID_SDK_ROOT` bằng `D:\src\android-sdk`, thêm `D:\src\android-sdk\platform-tools` vào PATH, rồi:

```powershell
flutter config --android-sdk D:\src\android-sdk
flutter doctor --android-licenses     # trả lời y
flutter doctor -v                     # phải báo "No issues found"
```

Cài gói bằng lệnh `android` (thay `sdkmanager`):

```powershell
$a = "D:\src\android-sdk\cmdline-tools\latest\bin\android.exe"
& $a --sdk=D:\src\android-sdk sdk install "platforms/android-36" "build-tools/36.0.0" "ndk/28.2.13676358"
```

### Lỗi build Kotlin "different roots"

Nếu `flutter build apk` báo `Could not close incremental caches ... this and base files have different roots`, do project (ổ D) và thư viện Pub (ổ C) khác ổ đĩa. Repo đã đặt `kotlin.incremental=false` trong `android/gradle.properties` để tránh lỗi này. Build lần đầu mất khoảng 5 đến 7 phút vì Gradle tải thư viện.

## 3. Điện thoại Android

1. Cài đặt, Giới thiệu điện thoại, bấm 7 lần vào **Số bản dựng** để bật Tuỳ chọn nhà phát triển.
2. Bật **Gỡ lỗi USB**, cắm cáp, chọn "Cho phép gỡ lỗi USB" trên máy.
3. `adb devices` phải liệt kê thiết bị ở trạng thái `device` (không phải `unauthorized`).
4. Cài app: `flutter run --dart-define=USE_DEV_SERVICES=true`.

### Không có điện thoại Android (máy ảo, Chrome, iPhone)

Không thể chạy app lên iPhone từ máy Windows (build iOS cần máy Mac và Xcode). Người dùng Windows chọn một trong hai cách dưới đây. Điện thoại Android thật chỉ cần khi thử Google Sign-in thật và chạy ARTEMIS, máy dùng chung của nhóm.

**Cách 1: Chrome với khung điện thoại (nhẹ nhất).**

1. Trong VS Code cài extension **Flutter** (Dart Code), chọn thiết bị **Chrome (web)** ở góc dưới bên phải rồi bấm **F5**. Cấu hình `.vscode/launch.json` đã chạy với dữ liệu giả (`USE_DEV_SERVICES=true`).
2. Trong cửa sổ trình duyệt bấm `F12`, rồi `Ctrl+Shift+M` và chọn iPhone hoặc Pixel để thấy khung điện thoại.

Bản web chỉ để xem giao diện: Firebase mới cấu hình cho Android, nên chạy với dữ liệu giả.

**Cách 2: Android Emulator (giống máy thật, cần khoảng 3 GB và 8 GB RAM trống).**

```powershell
$a = "D:\src\android-sdk\cmdline-tools\latest\bin\android.exe"
& $a --sdk=D:\src\android-sdk sdk install "emulator" "system-images/android-35/google_apis_playstore/x86_64"
mkdir D:\src\android-avd
setx ANDROID_AVD_HOME D:\src\android-avd
$env:ANDROID_AVD_HOME = "D:\src\android-avd"
D:\src\android-sdk\cmdline-tools\latest\bin\avdmanager.bat create avd -n Pixel8_API35 -k "system-images;android-35;google_apis_playstore;x86_64" -d pixel_8
```

Mở lại terminal và VS Code, bật máy ảo bằng `flutter emulators --launch Pixel8_API35`, rồi chạy `flutter run --dart-define=USE_DEV_SERVICES=true`. Bật **một** emulator thôi: mở thêm một cái nữa sẽ báo `The Android emulator exited with code 1` hoặc làm máy ảo kẹt ở trạng thái `offline`. Nếu kẹt, tắt tiến trình `emulator` và `qemu-system-x86_64` trong Task Manager rồi bật lại. Lần đầu boot mất vài phút.

Máy ảo của mỗi người dùng khoá debug của máy đó: gửi SHA-1 của máy bạn cho người giữ Firebase project (xem mục 4) để Google Sign-in chạy.

**Vào app khi màn đăng nhập (S26) chưa làm.** Với dữ liệu giả, thêm `--dart-define=DEV_SIGNED_IN=true` để vào thẳng app khách, và `--dart-define=DEV_ROLE=staff` để vào app người bán. Trong VS Code chọn cấu hình "BreakBite khách (dữ liệu giả, đã đăng nhập)" hoặc "BreakBite người bán (…)" rồi bấm F5. Hai cờ này chỉ có tác dụng với service giả và bị gỡ cùng `lib/dev/` trước khi nộp (T83).

## 4. Firebase

```powershell
npm install -g firebase-tools           # 15.34.1
dart pub global activate flutterfire_cli # 1.4.1; thêm %LOCALAPPDATA%\Pub\Cache\bin vào PATH
firebase login
flutterfire configure --project <id-project-firebase>   # sinh lib/firebase_options.dart (task T01, T03)
```

Project của nhóm là `breakbite-1315b` (gói Spark). `lib/firebase_options.dart` và `android/app/google-services.json` đã nằm trong repo, nên người mới **không cần** chạy lại `flutterfire configure`; chỉ cần được mời vào project (Project settings, Users and permissions, vai trò Editor).

**SHA-1 cho Google Sign-in.** Mỗi máy có khoá debug riêng, nên mỗi người lấy SHA-1 của máy mình và gửi cho người giữ project để thêm vào Project settings, Your apps, BreakBite, Add fingerprint. Chưa thêm thì đăng nhập Google báo `ApiException: 10`.

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"
```

Nếu báo không thấy file keystore, chạy app Flutter một lần để máy tự tạo. SHA-1 là dấu vân tay công khai nên gửi qua nhóm chat được; **không** chia sẻ file keystore hay file service account `*-adminsdk-*.json`.

Chạy test rules: xem `firebase/README.md`.

## 5. ARTEMIS (test E2E)

Xem `e2e_test/README.md`. Máy chủ đặt ở `D:\src\artemis`, ghim commit `351ca8422f7b5b54e80a9c1ce03a222e02415b6b`. Cần khoá API của một mô hình đa phương thức (Gemini, Claude, GPT-4o hoặc Qwen-VL) trong `.env` của máy chủ ARTEMIS; **không commit khoá**.

## 6. Kiểm tra nhanh

```powershell
cd <repo>
flutter pub get
flutter analyze
flutter test                      # 36 test
flutter build apk --debug         # cần SDK, NDK ở mục 2
```
