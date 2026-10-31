abstract interface class StorageService {
  /// Tải tệp lên `reports/{uid}/{fileName}`; trả URL tải xuống.
  Future<String> uploadReport({
    required String uid,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  });
}
