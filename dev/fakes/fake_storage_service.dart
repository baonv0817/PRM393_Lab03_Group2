import 'package:breakbite/data/services/services.dart';

class FakeStorageService implements StorageService {
  @override
  Future<String> uploadReport({
    required String uid,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return 'https://storage.invalid/reports/$uid/$fileName';
  }
}
