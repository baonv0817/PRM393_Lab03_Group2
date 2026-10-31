import 'dependencies.dart';

/// Khởi tạo Firebase và dựng các bản cài đặt thật.
///
/// TODO(P3, task T22 và T33): gọi `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`,
/// rồi dựng service bọc SDK trong `lib/data/services/firebase/` và repository Firestore trong
/// `lib/data/repositories/firestore/`. Lưu tệp: `CloudinaryStorageService(CloudinaryConfig.fromEnvironment())`.
Future<AppDependencies> createFirebaseDependencies() async {
  throw UnimplementedError(
    'Firebase chưa được nối. Chạy bản dữ liệu giả: flutter run -t dev/main_dev.dart, '
    'hoặc hoàn thành task T22 và T33.',
  );
}
