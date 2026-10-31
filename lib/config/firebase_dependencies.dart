import 'package:breakbite/config/dependencies.dart';
import 'package:breakbite/config/firebase_setup.dart';

/// Initializes Firebase (or the local emulators, see [useFirebaseEmulator]) and builds the real
/// implementations.
///
/// TODO(T22): build the SDK-wrapping services in `lib/data/services/firebase/`. TODO(T33): build the
/// Firestore repositories in `lib/data/repositories/firestore/` with the helpers in `lib/data/firebase/`.
/// File storage: `CloudinaryStorageService(CloudinaryConfig.fromEnvironment())`; session:
/// `InMemorySessionRepository()`.
Future<AppDependencies> createFirebaseDependencies() async {
  await initializeFirebase();
  throw UnimplementedError(
    'Firebase đã khởi tạo nhưng chưa có service thật. Chạy bản dữ liệu giả: flutter run -t dev/main_dev.dart, '
    'hoặc hoàn thành task T22 và T33.',
  );
}
