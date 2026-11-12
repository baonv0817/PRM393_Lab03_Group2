import 'dart:typed_data';

import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/utils/result.dart';

/// Hands out a tiny picture without opening anything. [next] is what the next [pick] returns: `null` means the
/// person backed out, an exception means the permission was refused.
class FakePhotoPickerService implements PhotoPickerService {
  /// A 1x1 PNG, enough for `Image.memory` and for an upload.
  static final onePixel = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1f,
    0x15,
    0xc4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9c,
    0x63,
    0xf8,
    0xcf,
    0xc0,
    0xf0,
    0x1f,
    0x00,
    0x05,
    0x00,
    0x01,
    0xff,
    0x89,
    0x99,
    0x3d,
    0x1d,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4e,
    0x44,
    0xae,
    0x42,
    0x60,
    0x82,
  ]);

  PickedPhoto? next = PickedPhoto(bytes: onePixel, fileName: 'mon.png');
  AppException? failure;
  final asked = <PhotoSource>[];

  @override
  Future<Result<PickedPhoto?>> pick(PhotoSource source) async {
    asked.add(source);
    final error = failure;
    if (error != null) return Result.error(error);
    return Result.ok(next);
  }
}
