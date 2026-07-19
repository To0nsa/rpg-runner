import 'dart:convert';

import 'package:googleapis/storage/v1.dart' as storage;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:replay_validator/src/google_api_helpers.dart';
import 'package:replay_validator/src/replay_loader.dart';

void main() {
  test('collectReplayBytes returns payload at the exact byte limit', () async {
    final bytes = await collectReplayBytes(
      Stream<List<int>>.fromIterable(const <List<int>>[
        <int>[1, 2],
        <int>[3, 4],
      ]),
      maxBytes: 4,
    );

    expect(bytes, <int>[1, 2, 3, 4]);
  });

  test(
    'collectReplayBytes stops when streamed payload exceeds limit',
    () async {
      await expectLater(
        collectReplayBytes(
          Stream<List<int>>.fromIterable(const <List<int>>[
            <int>[1, 2],
            <int>[3, 4],
          ]),
          maxBytes: 3,
        ),
        throwsA(
          isA<ReplayPayloadTooLargeException>()
              .having((error) => error.maxBytes, 'maxBytes', 3)
              .having((error) => error.observedBytes, 'observedBytes', 4),
        ),
      );
    },
  );

  test('storage loader downloads the exact finalized generation', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        const <int>[1, 2, 3],
        200,
        headers: const <String, String>{
          'content-type': 'application/octet-stream',
        },
      );
    });
    final loader = GoogleCloudStorageReplayLoader(
      bucketName: 'bucket',
      apiProvider: _TestApiProvider(storage.StorageApi(client)),
    );

    final loaded = await loader.loadReplay(
      runSessionId: 'run_1',
      objectPath: 'replays/run_1.bin',
      storageGeneration: '123456',
    );

    expect(loaded.bytes, <int>[1, 2, 3]);
    expect(loaded.storageGeneration, '123456');
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['generation'], '123456');
    expect(requests.single.url.queryParameters['ifGenerationMatch'], '123456');
  });

  test('storage loader classifies a missing generation as evidence loss', () {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 404,
            'message': 'not found',
            'status': 'NOT_FOUND',
          },
        }),
        404,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final loader = GoogleCloudStorageReplayLoader(
      bucketName: 'bucket',
      apiProvider: _TestApiProvider(storage.StorageApi(client)),
    );

    expect(
      loader.loadReplay(
        runSessionId: 'run_1',
        objectPath: 'replays/run_1.bin',
        storageGeneration: '123456',
      ),
      throwsA(isA<ReplayGenerationUnavailableException>()),
    );
  });
}

final class _TestApiProvider extends GoogleCloudApiProvider {
  _TestApiProvider(this.api);

  final storage.StorageApi api;

  @override
  Future<storage.StorageApi> storageApi() async => api;
}
