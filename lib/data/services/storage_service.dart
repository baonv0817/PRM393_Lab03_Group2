/// Thư mục gốc của tệp tải lên; tệp nằm ở `<folder>/<ownerId>/…`.
enum UploadFolder {
  /// Biên lai PDF khách xuất (T43); ownerId = uid.
  reports,

  /// Ảnh minh chứng sự cố (S24); ownerId = uid.
  incidents,

  /// Ảnh món (K14, K15); ownerId = kioskId.
  menu,
}

class UploadedFile {
  const UploadedFile({required this.url, required this.publicId, required this.sizeBytes});

  /// Đường dẫn HTTPS công khai để mở hoặc tải tệp.
  final String url;

  /// Mã định danh tệp ở nơi lưu (để lưu kèm metadata trong Firestore).
  final String publicId;
  final int sizeBytes;
}

/// Tải tệp thất bại: mất mạng, tệp không hợp lệ hoặc dịch vụ từ chối. [message] hiện được cho người dùng.
class UploadFailure implements Exception {
  const UploadFailure(this.message);

  final String message;

  @override
  String toString() => 'UploadFailure: $message';
}

abstract interface class StorageService {
  /// Kích thước tối đa của một tệp.
  static const maxBytes = 5 * 1024 * 1024;

  /// Tải [bytes] lên `<folder>/<ownerId>/`, gọi [onProgress] với giá trị 0..1, trả về tệp đã lưu.
  /// Ném [UploadFailure] khi không tải được.
  Future<UploadedFile> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  });
}
