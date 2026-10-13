import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:np_pole_tag_stickerman/services/api_exception.dart';
import 'package:np_pole_tag_stickerman/services/api_services.dart';

void main() {
  late File photo;

  setUp(() {
    photo = File('${Directory.systemTemp.path}/upload_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() {
    if (photo.existsSync()) photo.deleteSync();
  });

  group('createPoleRecord', () {
    test('posts the record and returns the new record id', () async {
      // Nullable rather than `late`: Dart cannot see that the closure below
      // runs before the assertions, and calls a `late` local unassigned.
      http.Request? seen;

      final api = ApiService(client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'record_id': 907, 'tag_id': 41}), 201);
      }))
        ..setToken('token-abc');

      final id = await api.createPoleRecord({'tag_id': 41, 'remarks': 'leaning'});

      expect(id, 907);
      expect(seen!.method, 'POST');
      expect(seen!.url.path, endsWith('/pole-records'));
      expect(seen!.headers['Authorization'], 'Bearer token-abc');
      expect(jsonDecode(seen!.body)['remarks'], 'leaning');
    });

    // The backend answers 200 with the record that already exists rather than
    // erroring, so a reply lost on a flaky connection cannot make a duplicate.
    test('accepts the 200 that means the record was already filed', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(jsonEncode({'record_id': 907}), 200);
      }));

      expect(await api.createPoleRecord({'tag_id': 41}), 907);
    });

    test('a refusal comes back as ApiException carrying the server wording', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(
          jsonEncode({'detail': 'That tag is not assigned to you'}),
          403,
        );
      }));

      expect(
        () => api.createPoleRecord({'tag_id': 41}),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message',
                'That tag is not assigned to you')),
      );
    });

    test('an unreachable server comes back as status 0', () async {
      final api = ApiService(client: MockClient((_) async {
        throw const SocketException('no route to host');
      }));

      expect(
        () => api.createPoleRecord({'tag_id': 41}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 0)),
      );
    });
  });

  group('uploadPhoto', () {
    test('sends the file as multipart with its type and time', () async {
      // Nullable rather than `late`: Dart cannot see that the closure below
      // runs before the assertions, and calls a `late` local unassigned.
      http.Request? seen;

      final api = ApiService(client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'photo_id': 3}), 201);
      }))
        ..setToken('token-abc');

      await api.uploadPhoto(
        recordId: 907,
        path: photo.path,
        photoType: 'tag_closeup',
        takenAt: DateTime.utc(2026, 9, 9, 6, 30),
      );

      expect(seen!.method, 'POST');
      expect(seen!.url.path, endsWith('/pole-records/907/photos'));
      expect(seen!.headers['Authorization'], 'Bearer token-abc');
      // Multipart, not JSON: sending application/json here makes FastAPI
      // reject the form fields with a 422.
      expect(seen!.headers['content-type'], contains('multipart/form-data'));
      expect(seen!.body, contains('tag_closeup'));
      expect(seen!.body, contains('2026-09-09T06:30:00'));
    });

    test('a refusal comes back as ApiException', () async {
      final api = ApiService(client: MockClient((_) async {
        return http.Response(
          jsonEncode({'detail': 'This pole already has a tag closeup photo'}),
          409,
        );
      }));

      expect(
        () => api.uploadPhoto(
          recordId: 907,
          path: photo.path,
          photoType: 'tag_closeup',
          takenAt: DateTime.utc(2026, 9, 9, 6, 30),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
