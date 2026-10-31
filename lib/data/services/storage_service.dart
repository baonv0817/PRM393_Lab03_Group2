import 'package:breakbite/utils/result.dart';

/// Top-level folder of an upload; files land in `<folder>/<ownerId>/…`.
enum UploadFolder {
  /// PDF receipts exported by customers (T43); ownerId is the uid.
  reports,

  /// Incident evidence photos (S24); ownerId is the uid.
  incidents,

  /// Item photos (K14, K15); ownerId is the kioskId.
  menu,
}

class UploadedFile {
  const UploadedFile({required this.url, required this.publicId, required this.sizeBytes});

  /// Public HTTPS link to open or download the file.
  final String url;

  /// Id of the file at the storage provider, saved with its metadata in Firestore.
  final String publicId;
  final int sizeBytes;
}

abstract interface class StorageService {
  static const maxBytes = 5 * 1024 * 1024;

  /// Uploads [bytes] to `<folder>/<ownerId>/`, reporting progress from 0 to 1 through [onProgress].
  /// Fails with `ValidationException` (empty or larger than [maxBytes]), `NetworkException` or
  /// `ServiceException`.
  Future<Result<UploadedFile>> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  });
}
