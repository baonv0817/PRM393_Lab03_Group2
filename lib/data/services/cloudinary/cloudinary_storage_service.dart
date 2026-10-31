import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage_service.dart';

/// Cấu hình Cloudinary. Cả hai giá trị đều không phải bí mật: app tải lên bằng *unsigned upload
/// preset*, nên không bao giờ chứa API secret. Truyền bằng `--dart-define-from-file=env/cloudinary.json`.
class CloudinaryConfig {
  const CloudinaryConfig({required this.cloudName, required this.uploadPreset, this.rootFolder = 'breakbite'});

  factory CloudinaryConfig.fromEnvironment() => const CloudinaryConfig(
        cloudName: String.fromEnvironment('CLOUDINARY_CLOUD_NAME'),
        uploadPreset: String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET'),
      );

  final String cloudName;
  final String uploadPreset;
  final String rootFolder;

  bool get isComplete => cloudName.isNotEmpty && uploadPreset.isNotEmpty;
}

/// [StorageService] lưu tệp trên Cloudinary (thay Cloud Storage for Firebase, vốn cần gói Blaze).
class CloudinaryStorageService implements StorageService {
  CloudinaryStorageService(this._config, {http.Client? client, this.timeout = const Duration(seconds: 60)})
      : _client = client ?? http.Client();

  final CloudinaryConfig _config;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<UploadedFile> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (!_config.isComplete) throw const UploadFailure('Chưa cấu hình nơi lưu tệp.');
    if (bytes.isEmpty) throw const UploadFailure('Tệp rỗng.');
    if (bytes.length > StorageService.maxBytes) throw const UploadFailure('Tệp lớn hơn 5 MB.');

    final uri = Uri.https('api.cloudinary.com', '/v1_1/${_config.cloudName}/auto/upload');
    final form = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _config.uploadPreset
      ..fields['folder'] = '${_config.rootFolder}/${folder.name}/$ownerId'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final total = form.contentLength;
    final body = form.finalize();
    final request = http.StreamedRequest('POST', uri)
      ..headers.addAll(form.headers)
      ..contentLength = total;
    var sent = 0;
    onProgress?.call(0);
    body.listen(
      (chunk) {
        request.sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(total == 0 ? 1 : sent / total);
      },
      onError: request.sink.addError,
      onDone: request.sink.close,
      cancelOnError: true,
    );

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw const UploadFailure('Tải lên quá lâu. Kiểm tra mạng rồi thử lại.');
    } on http.ClientException {
      throw const UploadFailure('Không có kết nối mạng. Thử lại khi có mạng.');
    }

    final json = _decode(response.body);
    if (response.statusCode != 200) {
      final reason = (json?['error'] as Map<String, dynamic>?)?['message'] as String?;
      throw UploadFailure('Không tải được tệp lên${reason == null ? '' : ': $reason'}.');
    }
    final url = json?['secure_url'] as String?;
    final publicId = json?['public_id'] as String?;
    if (url == null || publicId == null) throw const UploadFailure('Nơi lưu tệp trả về dữ liệu không hợp lệ.');
    return UploadedFile(url: url, publicId: publicId, sizeBytes: (json?['bytes'] as int?) ?? bytes.length);
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
