import 'dart:convert';

import 'package:googleapis/storage/v1.dart' as storage;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/validated_replay_archiver.dart';

void main() {
  for (final status in <int>[204, 404, 412, 500]) {
    test(
      'archive discard is generation fenced and handles HTTP $status',
      () async {
        late http.Request deletion;
        final client = MockClient((request) async {
          deletion = request;
          return http.Response(
            status == 204
                ? ''
                : jsonEncode({
                    'error': {'code': status, 'message': 'test failure'},
                  }),
            status,
          );
        });
        final operation =
            GoogleCloudStorageValidatedReplayArchiver(
              bucketName: 'bucket',
              apiProvider: _StorageApiProvider(storage.StorageApi(client)),
            ).discard(
              archivedReplay: const ArchivedValidatedReplay(
                objectPath: 'replay-submissions/validated/run_1.bin.gz',
                storageGeneration: '456',
              ),
            );
        if (status == 500) {
          await expectLater(operation, throwsA(anything));
        } else {
          await operation;
        }
        expect(deletion.method, 'DELETE');
        expect(deletion.url.queryParameters['ifGenerationMatch'], '456');
      },
    );
  }

  test(
    'archives an exact source generation under the validated prefix',
    () async {
      late http.Request copyRequest;
      final client = MockClient((request) async {
        copyRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{'generation': '456'}),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      });
      final archiver = GoogleCloudStorageValidatedReplayArchiver(
        bucketName: 'bucket',
        apiProvider: _StorageApiProvider(storage.StorageApi(client)),
      );

      final archived = await archiver.archive(
        runSessionId: 'run_1',
        sourceObjectPath: 'replay-submissions/pending/uid/run_1/replay.bin.gz',
        sourceStorageGeneration: '123',
      );

      expect(archived.objectPath, 'replay-submissions/validated/run_1.bin.gz');
      expect(archived.storageGeneration, '456');
      expect(copyRequest.url.queryParameters['sourceGeneration'], '123');
      expect(copyRequest.url.queryParameters['ifSourceGenerationMatch'], '123');
      expect(copyRequest.url.queryParameters['ifGenerationMatch'], '0');
    },
  );
}

final class _StorageApiProvider extends GoogleCloudApiProvider {
  _StorageApiProvider(this.api);

  final storage.StorageApi api;

  @override
  Future<storage.StorageApi> storageApi() async => api;
}
