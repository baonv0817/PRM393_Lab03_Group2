import 'dart:typed_data';

import 'package:breakbite/utils/result.dart';

/// Where a photo comes from.
enum PhotoSource { gallery, camera }

/// A photo the person chose, already scaled down so it is well under [StorageService.maxBytes].
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Lets a person pick or take one photo (K14, K15: the photo of an item).
abstract interface class PhotoPickerService {
  /// The chosen photo, or `Ok(null)` when the person backed out. Fails with `PermissionDeniedException` when
  /// the camera or the photos are not allowed, or `ServiceException` when the device cannot do it.
  Future<Result<PickedPhoto?>> pick(PhotoSource source);
}
