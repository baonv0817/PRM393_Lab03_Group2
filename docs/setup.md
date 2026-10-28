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

## 3. Điện thoại Android

1. Cài đặt, Giới thiệu điện thoại, bấm 7 lần vào **Số bản dựng** để bật Tuỳ chọn nhà phát triển.
2. Bật **Gỡ lỗi USB**, cắm cáp, chọn "Cho phép gỡ lỗi USB" trên máy.
3. `adb devices` phải liệt kê thiết bị ở trạng thái `device` (không phải `unauthorized`).
4. Cài app: `flutter run --dart-define=USE_DEV_SERVICES=true`.

## 4. Firebase

```powershell
npm install -g firebase-tools           # 15.34.1
dart pub global activate flutterfire_cli # 1.4.1; thêm %LOCALAPPDATA%\Pub\Cache\bin vào PATH
firebase login
flutterfire configure --project <id-project-firebase>   # sinh lib/firebase_options.dart (task T01, T03)
```

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
