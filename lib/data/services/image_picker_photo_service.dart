import 'package:breakbite/data/services/photo_picker_service.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// [PhotoPickerService] on `image_picker`: the system photo picker (no permission needed) or the camera. The
/// photo is scaled to at most 1280 px on its long side and saved as JPEG, about 200 KB for a dish.
class ImagePickerPhotoService implements PhotoPickerService {
  ImagePickerPhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const maxSide = 1280.0;
  static const quality = 85;

  final ImagePicker _picker;

  @override
  Future<Result<PickedPhoto?>> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
      );
      if (file == null) return const Result.ok(null);
      return Result.ok(PickedPhoto(bytes: await file.readAsBytes(), fileName: _nameOf(file.name)));
    } on PlatformException catch (error, stack) {
      final denied = error.code.contains('denied') || error.code.contains('permission');
      return Result.error(
        denied
            ? PermissionDeniedException(
                message: source == PhotoSource.camera
                    ? 'Chưa cho phép dùng camera. Bật quyền Camera trong cài đặt, hoặc chọn ảnh từ thư viện.'
                    : 'Chưa cho phép truy cập ảnh. Bật quyền trong cài đặt.',
                cause: error,
                stackTrace: stack,
              )
            : ServiceException(message: 'Không mở được ảnh. Thử lại sau.', cause: error, stackTrace: stack),
      );
    } catch (error, stack) {
      return Result.error(
        ServiceException(message: 'Không mở được ảnh. Thử lại sau.', cause: error, stackTrace: stack),
      );
    }
  }

  /// A name the upload can use: the picker's own name, or `photo.jpg` when it has none.
  static String _nameOf(String name) => name.trim().isEmpty ? 'photo.jpg' : name.trim();
}
