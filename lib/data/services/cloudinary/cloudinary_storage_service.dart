import 'dart:async';
import 'dart:convert';

import 'package:breakbite/data/services/storage_service.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/result.dart';
import 'package:http/http.dart' as http;

/// Cloudinary settings. Neither value is a secret: the app uploads through an *unsigned upload
/// preset* and never holds the API secret. Passed with `--dart-define-from-file=env/cloudinary.json`.
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

/// [StorageService] that keeps files on Cloudinary (instead of Cloud Storage for Firebase, which
/// needs the Blaze plan).
class CloudinaryStorageService implements StorageService {
  CloudinaryStorageService(this._config, {http.Client? client, this.timeout = const Duration(seconds: 60)})
    : _client = client ?? http.Client();

  final CloudinaryConfig _config;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<Result<UploadedFile>> upload({
    required UploadFolder folder,
    required String ownerId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (!_config.isComplete) {
      return const Result.error(ServiceException(message: 'Chưa cấu hình nơi lưu tệp.'));
    }
    if (bytes.isEmpty) return const Result.error(ValidationException('Tệp rỗng.'));
    if (bytes.length > StorageService.maxBytes) return const Result.error(ValidationException('Tệp lớn hơn 5 MB.'));

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
    } on TimeoutException catch (e, s) {
      return Result.error(
        NetworkException(message: 'Tải lên quá lâu. Kiểm tra mạng rồi thử lại.', cause: e, stackTrace: s),
      );
    } on http.ClientException catch (e, s) {
      return Result.error(NetworkException(cause: e, stackTrace: s));
    }

    final json = _decode(response.body);
    if (response.statusCode != 200) {
      final reason = (json?['error'] as Map<String, dynamic>?)?['message'] as String?;
      return Result.error(
        ServiceException(
          message: 'Không tải được tệp lên${reason == null ? '' : ': $reason'}.',
          cause: 'HTTP ${response.statusCode}',
        ),
      );
    }
    final url = json?['secure_url'] as String?;
    final publicId = json?['public_id'] as String?;
    if (url == null || publicId == null) {
      return const Result.error(ServiceException(message: 'Nơi lưu tệp trả về dữ liệu không hợp lệ.'));
    }
    return Result.ok(UploadedFile(url: url, publicId: publicId, sizeBytes: (json?['bytes'] as int?) ?? bytes.length));
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
