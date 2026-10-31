import 'dart:convert';

import 'package:breakbite/data/services/cloudinary/cloudinary_storage_service.dart';
import 'package:breakbite/data/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = CloudinaryConfig(cloudName: 'demo', uploadPreset: 'bb_unsigned');

http.StreamedResponse _json(int status, Map<String, Object?> body) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status);

void main() {
  group('CloudinaryStorageService.upload', () {
    test('gửi đúng preset và thư mục theo người dùng, trả URL, báo tiến trình tới 1', () async {
      late http.BaseRequest sent;
      late String sentBody;
      final service = CloudinaryStorageService(
        _config,
        client: MockClient.streaming((request, body) async {
          sent = request;
          sentBody = await body.bytesToString();
          return _json(200, {'secure_url': 'https://res.cloudinary.com/demo/x.pdf', 'public_id': 'breakbite/reports/u1/x', 'bytes': 3});
        }),
      );
      final progress = <double>[];

      final file = await service.upload(
        folder: UploadFolder.reports,
        ownerId: 'u1',
        fileName: 'bien-lai.pdf',
        bytes: [1, 2, 3],
        onProgress: progress.add,
      );

      expect(sent.url.toString(), 'https://api.cloudinary.com/v1_1/demo/auto/upload');
      expect(sentBody, contains('bb_unsigned'));
      expect(sentBody, contains('breakbite/reports/u1'));
      expect(sentBody, contains('bien-lai.pdf'));
      expect(file.url, 'https://res.cloudinary.com/demo/x.pdf');
      expect(file.publicId, 'breakbite/reports/u1/x');
      expect(file.sizeBytes, 3);
      expect(progress.first, 0);
      expect(progress.last, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    });

    test('dịch vụ từ chối thì ném UploadFailure kèm lý do', () async {
      final service = CloudinaryStorageService(
        _config,
        client: MockClient.streaming((request, body) async {
          await body.drain<void>();
          return _json(400, {
            'error': {'message': 'Upload preset not found'}
          });
        }),
      );

      expect(
        () => service.upload(folder: UploadFolder.reports, ownerId: 'u1', fileName: 'a.pdf', bytes: [1]),
        throwsA(isA<UploadFailure>().having((e) => e.message, 'message', contains('Upload preset not found'))),
      );
    });

    test('mất mạng thì ném UploadFailure có thông báo cho người dùng', () async {
      final service = CloudinaryStorageService(
        _config,
        client: MockClient.streaming((request, body) async => throw http.ClientException('offline')),
      );

      expect(
        () => service.upload(folder: UploadFolder.incidents, ownerId: 'u1', fileName: 'a.png', bytes: [1]),
        throwsA(isA<UploadFailure>().having((e) => e.message, 'message', contains('mạng'))),
      );
    });

    test('chưa cấu hình hoặc tệp quá 5 MB thì không gửi request', () async {
      var calls = 0;
      final client = MockClient.streaming((request, body) async {
        calls++;
        return _json(200, {});
      });

      await expectLater(
        CloudinaryStorageService(const CloudinaryConfig(cloudName: '', uploadPreset: ''), client: client)
            .upload(folder: UploadFolder.reports, ownerId: 'u1', fileName: 'a.pdf', bytes: [1]),
        throwsA(isA<UploadFailure>()),
      );
      await expectLater(
        CloudinaryStorageService(_config, client: client).upload(
          folder: UploadFolder.menu,
          ownerId: 'q9-t2',
          fileName: 'big.png',
          bytes: List<int>.filled(StorageService.maxBytes + 1, 0),
        ),
        throwsA(isA<UploadFailure>()),
      );
      expect(calls, 0);
    });
  });
}
