import 'package:breakbite/data/services/services.dart';

class FakeStorageService implements StorageService {
  final uploads = <UploadedFile>[];

  @override
  Future<UploadedFile> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.length > StorageService.maxBytes) throw const UploadFailure('Tệp lớn hơn 5 MB.');
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final file = UploadedFile(
      url: 'https://files.invalid/breakbite/${folder.name}/$ownerId/$fileName',
      publicId: 'breakbite/${folder.name}/$ownerId/$fileName',
      sizeBytes: bytes.length,
    );
    uploads.add(file);
    return file;
  }
}
