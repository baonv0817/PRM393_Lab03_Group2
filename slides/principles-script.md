# Lời nói cho slide "nguyên lý" (khoảng 8 phút)

File slide: `Lab03_SE193905_principles.pdf` (tạo bằng `python scripts/build_principles_slides.py`). Mỗi mục dưới đây là lời nói cho một slide, khoảng 30 đến 45 giây.

**1. Mở đầu.** Em xin trình bày các dịch vụ đám mây trong BreakBite hoạt động ra sao. Với mỗi dịch vụ em trả lời cùng một bộ câu hỏi: nó là gì và chạy ở đâu, dữ liệu lưu ở đâu, app làm gì, code nằm ở đâu và khi lỗi thì sao.

**2. Bức tranh tổng thể.** Nhóm không có server riêng. Màn hình chỉ vẽ, ViewModel giữ trạng thái, còn repository và service mới nói chuyện với Firebase và Cloudinary. Firebase giữ danh tính, dữ liệu, thông báo, đo lường, lỗi và cấu hình. Vì Cloud Storage cần gói trả phí nên tệp PDF đi qua Cloudinary, được thầy cho phép. Quy tắc bảo vệ dữ liệu chạy trên máy chủ Firebase chứ không nằm trong app.

**3. Authentication.** Người dùng chọn tài khoản Google, Google trả một ID token. App đưa token đó cho Firebase, Firebase cấp lại ID token của riêng nó, dạng JWT hết hạn sau khoảng một giờ, kèm refresh token. SDK giữ và tự làm mới nên app không bao giờ giữ mật khẩu. Cần đăng ký SHA-1 vì Google chỉ trả token cho app có chứng chỉ ký đã khai báo trong project. Sau đó `authStateChanges` quyết định router đưa người dùng tới màn nào, và Rules dùng `request.auth.uid` để biết ai đang gọi.

**4. Firestore và Rules.** Màn hình lắng nghe `snapshots()` nên bếp báo hết món thì khách thấy ngay. Mỗi yêu cầu đều đi qua Security Rules trên máy chủ: mặc định từ chối, khách chỉ đọc ghi dữ liệu của mình, nhân viên chỉ làm việc ở kiosk của mình, có 88 test cho rules. Đặt, sửa, huỷ đơn chạy trong transaction để hai người cùng sửa không ghi đè nhau. Truy vấn lọc nhiều trường cần index tổng hợp. Em đã thêm 16 index vì trên Firestore thật thiếu index sẽ báo lỗi, còn Emulator thì không đòi.

**5. Cloudinary.** App tạo PDF rồi gửi lên Cloudinary bằng HTTP multipart với một upload preset không ký. Cloudinary trả URL, app lưu URL, tên tệp và dung lượng vào Firestore, và chỉ chủ sở hữu đọc được. Preset không ký nghĩa là app không giữ khoá bí mật nào, vì khoá nằm trong app thì ai tải app cũng lấy được. Nhờ giao diện `StorageService`, muốn đổi sang S3 thì không phải sửa màn hình.

**6. FCM, token và gửi tin.** Token FCM định danh một bản cài app trên một thiết bị, do FCM cấp qua Google Play Services khi app gọi `getToken`. App lưu token vào `users/{uid}.fcmTokens`, tối đa năm thiết bị, và gỡ khi đăng xuất. Muốn gửi tin thì cần một bên server gọi FCM HTTP v1 kèm token và nội dung. Ở đây em gửi từ Firebase Console, mục Send test message, hoặc dùng script Admin SDK. Hệ thống thật sẽ đặt phần gửi này ở máy chủ hoặc Cloud Functions, kích hoạt khi bếp đổi trạng thái đơn.

**7. Ba trạng thái nhận tin.** Khi app đang mở thì `onMessage` nhận. Khi chạy nền, handler nền của app xử lý. Khi đã đóng, hệ thống tự hiện thông báo và chạm vào thì `getInitialMessage` đưa app lên. Cả ba đều lưu vào hộp thông báo và `PushRouter` mở đúng đơn khi chạm. Android 13 trở lên phải xin quyền, bị từ chối thì app vẫn chạy.

**8. Analytics.** App ghi sự kiện bằng `logEvent`, kế hoạch gồm 11 sự kiện, mỗi sự kiện trả lời một câu hỏi sản phẩm. SDK gom và gửi theo lô nên báo cáo chậm. Muốn thấy ngay thì dùng DebugView sau khi bật lệnh `adb shell setprop debug.firebase.analytics.app`. Hình bên phải là DebugView ghi lại một phiên. Tham số không chứa tên hay e-mail, chỉ có `setUserId` bằng uid.

**9. Crashlytics.** Khi app sập, SDK ghi báo cáo vào bộ nhớ máy và chỉ gửi ở lần mở app kế tiếp, nên Console cập nhật chậm. Lỗi Flutter chưa bắt và crash gốc Android được tự thu. Lỗi đã bắt nhưng đáng ghi như mất mạng được ghi là non-fatal. Mỗi báo cáo kèm `role`, `kiosk_id` và uid. Có nút test trong Khu demo Firebase để trình diễn.

**10. Remote Config.** Giá trị nằm trên server, app có giá trị mặc định. App lấy và activate giá trị mới, còn `onConfigUpdated` là kênh thời gian thực: khi bấm Publish trên Console, app biết và áp dụng ngay. Ba tham số là số món nhanh trên Home, bật tắt banner Giờ Vàng và bật tắt chọn giờ nhận. Mất mạng thì dùng giá trị cuối hoặc mặc định.

**11. MVVM và Provider.** Widget chỉ vẽ, ViewModel giữ trạng thái gồm tải, có dữ liệu, rỗng và lỗi, repository và service mới biết Firebase. Nhờ vậy em thay được Firebase bằng dịch vụ giả để kiểm thử và đổi Storage sang Cloudinary không sửa màn hình. Có một test kiến trúc thất bại nếu màn hình import SDK. Provider cấp ViewModel, `watch` vẽ lại khi trạng thái đổi, `read` chỉ để gọi hành động.

**12. Câu hỏi thường gặp.** Bảng tóm tắt các câu thầy hay hỏi: token FCM, cách gửi tin, vì sao Crashlytics chậm, vì sao Remote Config không cần build lại, Rules biết ai gọi bằng gì, vì sao cần SHA-1 và vì sao dùng Cloudinary.
