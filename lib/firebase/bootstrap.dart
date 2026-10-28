import '../services/app_services.dart';

/// Khởi tạo Firebase và trả về các service thật.
///
/// TODO(P3, task T01 và T22): sau khi tạo Firebase project và chạy `flutterfire configure`
/// (sinh `firebase_options.dart`), gọi `Firebase.initializeApp(...)` rồi dựng các lớp
/// cài đặt trong `lib/firebase/` (`FirebaseAuthService`, `FirestoreMenuService`…),
/// bọc SDK sau interface ở `lib/services/services.dart`.
Future<AppServices> bootstrapFirebase() async {
  throw UnimplementedError(
    'Firebase chưa được nối. Chạy với --dart-define=USE_DEV_SERVICES=true '
    'để dùng service giả khi phát triển, hoặc hoàn thành task T01 và T22.',
  );
}
