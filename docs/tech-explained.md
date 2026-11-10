# Giải thích công nghệ (để trả lời khi bảo vệ)

Mỗi dịch vụ trả lời cùng một bộ câu hỏi: **là gì**, **ai cấp hoặc chạy ở đâu**, **dữ liệu lưu ở đâu**, **client làm gì**, **code nằm ở đâu**, **khi lỗi thì sao**. Mọi đường dẫn đều trỏ vào repo này; điều gì chưa có thì ghi là chưa có.

## 1. Firebase Authentication

- **Là gì:** dịch vụ danh tính của Firebase. App không tự giữ mật khẩu; Google xác minh người dùng, Firebase cấp phiên đăng nhập.
- **Luồng:** `GoogleSignIn` mở hộp chọn tài khoản Google, trả về một **Google ID token** → `GoogleAuthProvider.credential(idToken)` → `FirebaseAuth.signInWithCredential` → Firebase Auth cấp **Firebase ID token** (JWT, hết hạn sau khoảng 1 giờ) cùng một refresh token; SDK giữ chúng trên thiết bị và tự làm mới.
- **Ai cấp, ở đâu:** Google (token Google) và máy chủ Firebase Auth (token Firebase). Danh sách người dùng xem ở Console → Authentication → Users.
- **Vì sao cần SHA-1:** Google chỉ trả token cho app có chứng chỉ ký (SHA-1) đã đăng ký trong project; mỗi máy build debug có SHA-1 riêng.
- **Client làm gì:** `authStateChanges()` phát ra người dùng hiện tại (hoặc `null`); router chuyển giữa đăng nhập, Trang chủ và app bếp theo luồng này và theo `role` trong `users/{uid}`. Đăng xuất xoá dữ liệu cục bộ của người đó.
- **Phía server dùng ra sao:** Firestore Rules đọc `request.auth.uid` (từ ID token) để biết ai đang gọi.
- **Code:** `lib/data/services/firebase/firebase_auth_service.dart`, `lib/routing/router.dart` (`authRedirect`), `lib/ui/auth/`.
- **Khi lỗi:** huỷ đăng nhập, mất mạng, Google không trả token: mỗi trường hợp có một thông báo riêng, không chuyển màn.

## 2. Cloud Firestore và Security Rules

- **Là gì:** cơ sở dữ liệu NoSQL theo tài liệu (document) và bộ sưu tập (collection), lưu trên máy chủ Google. Đây là nơi giữ menu, giỏ hàng, đơn, báo cáo sự cố, đánh giá, thông báo.
- **Client đọc ghi thế nào:** SDK nói chuyện trực tiếp với Firestore. Màn hình dùng `snapshots()` nên khi dữ liệu đổi (ví dụ bếp báo hết món) khách thấy ngay, không cần tải lại. SDK có bộ nhớ đệm để đọc khi mất mạng.
- **Ai bảo vệ dữ liệu:** không có server riêng của nhóm; **Security Rules** (`firebase/firestore.rules`) chạy trên máy chủ Firebase và quyết định từng yêu cầu: deny mặc định, khách chỉ đọc ghi dữ liệu của mình, nhân viên chỉ làm việc ở kiosk của mình. Có 88 test rules (`firebase/tests`).
- **Transaction:** đặt, sửa, huỷ đơn và từng bước của bếp chạy trong một transaction để hai người cùng sửa không ghi đè nhau (`lib/data/repositories/firestore/`).
- **Index:** truy vấn lọc nhiều trường cần index tổng hợp (`firebase/firestore.indexes.json`); Emulator không đòi, Firestore thật thì có (K11 thiếu index sẽ lỗi).
- **Điều cần nói thẳng:** giá món trong đơn do client gửi và server chưa kiểm với menu (xem CR-01 trong `docs/code-review.md`).

## 3. Lưu tệp: Cloudinary thay Cloud Storage

- **Vì sao Cloudinary:** Cloud Storage for Firebase cần gói Blaze (thẻ thanh toán); thầy đã cho phép dùng Cloudinary hoặc AWS S3.
- **Luồng:** app tạo PDF → gửi HTTP multipart tới API upload của Cloudinary kèm **upload preset không ký** (`env/cloudinary.json`) → Cloudinary trả URL → app lưu URL, tên tệp, dung lượng vào Firestore `reports` (chỉ chủ sở hữu đọc được).
- **Preset không ký nghĩa là:** app không giữ khoá bí mật nào (nếu giữ khoá trong app thì ai tải app cũng lấy được). Đổi lại, ai biết preset đều có thể tải lên; việc giới hạn nằm ở cấu hình preset trong Cloudinary.
- **Code:** `lib/data/services/cloudinary/cloudinary_storage_service.dart` (giao diện `StorageService` để đổi sang S3 mà không sửa màn hình), `lib/data/services/pdf/`.
- **Khi lỗi:** chưa cấu hình, lớn hơn 5 MB, mất mạng, quá thời gian: mỗi loại một thông báo và vẫn bấm thử lại được.

## 4. Firebase Cloud Messaging (FCM)

- **Token FCM là gì:** chuỗi định danh **một bản cài app trên một thiết bị**. Nó cho FCM biết gửi tin tới đâu.
- **Ai cấp:** dịch vụ FCM của Google, qua Google Play Services trên thiết bị, khi app gọi `FirebaseMessaging.getToken()`. Token có thể đổi (cài lại app, xoá dữ liệu); app nghe `onTokenRefresh` để cập nhật.
- **Client có lưu không:** có. Sau khi đăng nhập, app ghi token vào `users/{uid}.fcmTokens` trong Firestore (tối đa 5 thiết bị) và gỡ token khi đăng xuất. Việc này để phía gửi biết cần gửi tới token nào.
- **Làm sao gửi được tin:** phải có một bên "server" gọi FCM HTTP v1 (`messages:send`) kèm token và nội dung; bên đó cần quyền (tài khoản dịch vụ). Có hai cách: (a) **Firebase Console → Messaging → Send test message** (Console đóng vai server); (b) script `firebase/seed/send-push.mjs` dùng **Admin SDK** (`messaging().sendEachForMulticast`) đọc token trong Firestore rồi gửi. Script này đã viết nhưng **chưa chạy với FCM thật** vì cần khoá tài khoản dịch vụ.
- **Code gửi nằm ở đâu:** trong repo chỉ có `send-push.mjs` (chạy ở máy dev). **Không có Cloud Functions** (Spark không dùng được); một hệ thống thật sẽ đặt đoạn gửi này ở máy chủ hoặc Cloud Functions, kích hoạt khi bếp đổi trạng thái đơn.
- **Client dùng ra sao khi nhận:** ba trạng thái. Đang mở: `onMessage`; chạy nền: handler `firebaseMessagingBackgroundHandler` (`lib/config/firebase_dependencies.dart`); đã đóng: hệ thống hiện thông báo, chạm vào thì `getInitialMessage` đưa app lên. Cả ba đều lưu vào hộp thông báo (S19) và `PushRouter` mở đúng đơn khi chạm.
- **Quyền:** Android 13+ phải xin quyền thông báo; bị từ chối thì app vẫn chạy, chỉ không có thông báo hệ thống.
- **Code:** `lib/data/services/firebase/firebase_messaging_service.dart`, `notification_inbox.dart`.

## 5. Firebase Analytics

- **Là gì:** đo hành vi người dùng bằng sự kiện (`logEvent(tên, tham số)`). Kế hoạch 11 sự kiện nằm ở `docs/analytics-plan.md`, mỗi sự kiện trả lời một câu hỏi sản phẩm.
- **Dữ liệu đi đâu:** SDK gom sự kiện trên thiết bị và gửi lên Firebase theo lô (thường mất một lúc mới thấy trong báo cáo). **DebugView** hiện ngay khi bật chế độ debug: `adb shell setprop debug.firebase.analytics.app vn.edu.fpt.breakbite`.
- **Người dùng:** `setUserId(uid)` sau khi đăng nhập; không đưa tên hay e-mail vào tham số.
- **Code:** `lib/data/services/firebase/firebase_analytics_service.dart`, tên sự kiện ở `analytics_events.dart`. Lỗi khi ghi sự kiện không bao giờ làm hỏng luồng chính.

## 6. Firebase Crashlytics

- **Là gì:** thu thập lỗi sập app. Khi app sập, SDK **ghi báo cáo vào bộ nhớ máy** rồi **gửi lên ở lần mở app kế tiếp**; vì vậy Console cập nhật chậm sau khi crash.
- **Nhóm bắt:** lỗi Flutter chưa bắt (`FlutterError.onError`, `PlatformDispatcher.onError`) và crash gốc Android; lỗi đã bắt nhưng đáng ghi (mất mạng, ghi thất bại) được ghi là **non-fatal** qua `recordNonFatal`.
- **Ngữ cảnh gửi kèm:** khoá `role` và `kiosk_id`, và `uid` để biết ai gặp lỗi.
- **Demo:** nút "Crashlytics test error" và "test crash" trong Khu demo Firebase (Cá nhân → Khu demo Firebase, có hỏi xác nhận trước khi crash).
- **Code:** `lib/data/services/firebase/firebase_crash_service.dart`, `lib/config/firebase_setup.dart` (`reportUncaughtErrors`).

## 7. Firebase Remote Config

- **Là gì:** các tham số do server giữ để đổi hành vi app **không cần build lại**. App có giá trị mặc định (`RemoteKeys.defaults`, khớp `firebase/remote-config-defaults.json`).
- **Luồng:** app lấy (`fetch`) giá trị mới theo khoảng tối thiểu (1 giờ, 0 khi debug), rồi **activate** để dùng. Ngoài ra `onConfigUpdated` là kênh thời gian thực: khi bấm Publish trên Console, server báo cho app, app lấy và áp dụng ngay.
- **Ba tham số:** `quick_items_limit` (số món nhanh trên Home), `promo_banner_enabled` (banner Giờ Vàng), `pickup_slot_enabled` (chọn giờ nhận).
- **Lỗi:** mất mạng thì dùng giá trị cuối cùng, hoặc mặc định trong app ở lần mở đầu.
- **Code:** `lib/data/services/firebase/firebase_remote_config_service.dart`, `lib/ui/home/view_models/home_view_model.dart`.

## 8. MVVM, Provider và vì sao giao diện không gọi SDK

- **Ba lớp:** màn hình (`ui/*/widgets`) chỉ vẽ và chuyển thao tác; ViewModel (`ui/*/view_models`) giữ trạng thái (`ViewState`: đang tải, có dữ liệu, rỗng, lỗi) và gọi repository hay service; repository và service (`data/`) mới biết Firebase.
- **Vì sao:** thay Firebase bằng dịch vụ giả để kiểm thử (`dev/fakes/`), đổi Cloud Storage sang Cloudinary mà không sửa màn hình, và 751 test chạy không cần thiết bị.
- **Ai bảo đảm quy tắc:** `test/architecture_test.dart` thất bại nếu màn hình import SDK, dùng literal màu hoặc kiểu chữ, hoặc ViewModel thiếu `SafeChangeNotifier`.
- **Provider:** cấp ViewModel và service cho cây widget; `context.watch` làm màn hình vẽ lại khi trạng thái đổi, `context.read` chỉ lấy để gọi hành động.

## Câu hỏi thầy có thể hỏi và đáp ngắn

| Câu hỏi | Đáp ngắn |
|---|---|
| Token FCM là gì, ai cấp, client có lưu không? | Định danh bản cài app trên thiết bị; FCM cấp qua Play Services; app lưu vào `users/{uid}.fcmTokens` |
| Muốn gửi tin thì làm sao, code nằm đâu? | Server gọi FCM v1 kèm token; ở đây là Console hoặc `send-push.mjs` (Admin SDK); không có Cloud Functions |
| Vì sao Crashlytics không hiện ngay? | Báo cáo lưu trên máy và gửi ở lần mở app sau |
| Vì sao Remote Config đổi mà không build lại? | Tham số nằm trên server; app fetch rồi activate, `onConfigUpdated` báo thay đổi |
| Rules chạy ở đâu, dựa vào đâu để biết ai gọi? | Trên máy chủ Firebase, dựa vào `request.auth.uid` lấy từ ID token |
| Vì sao cần SHA-1? | Google xác minh chứng chỉ ký của app trước khi trả token đăng nhập |
| Điểm yếu của app? | Giá đơn do client gửi, server chưa đối chiếu menu (CR-01); chưa có server gửi FCM tự động |
