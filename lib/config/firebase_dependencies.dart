import 'package:breakbite/config/dependencies.dart';

/// Initializes Firebase and builds the real implementations.
///
/// TODO(P3, tasks T22 and T33): call `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`,
/// then build the SDK-wrapping services in `lib/data/services/firebase/` and the Firestore repositories in
/// `lib/data/repositories/firestore/`. File storage: `CloudinaryStorageService(CloudinaryConfig.fromEnvironment())`.
Future<AppDependencies> createFirebaseDependencies() async {
  throw UnimplementedError(
    'Firebase chưa được nối. Chạy bản dữ liệu giả: flutter run -t dev/main_dev.dart, '
    'hoặc hoàn thành task T22 và T33.',
  );
}
