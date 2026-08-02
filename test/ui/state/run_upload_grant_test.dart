import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/state/run/run_session_api.dart';
import 'package:rpg_runner/ui/state/run/run_submission_coordinator.dart';

void main() {
  group('RunUploadGrant', () {
    test('decodes a signed POST form that binds the replay content type', () {
      final grant = RunUploadGrant.fromJson(<String, Object?>{
        'runSessionId': 'run_1',
        'objectPath': 'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
        'uploadUrl': 'https://storage.example.invalid/',
        'uploadMethod': 'POST',
        'uploadFields': <String, String>{
          'Content-Type': 'application/octet-stream',
          'key': 'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
          'policy': 'signed-policy',
        },
        'contentType': 'application/octet-stream',
        'maxBytes': 8 * 1024 * 1024,
        'expiresAtMs': 1_800_000_000_000,
      });

      expect(grant.uploadMethod, 'POST');
      expect(grant.uploadFields['policy'], 'signed-policy');
    });

    test('rejects a legacy PUT grant or an unbound content type', () {
      final grant = <String, Object?>{
        'runSessionId': 'run_1',
        'objectPath': 'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
        'uploadUrl': 'https://storage.example.invalid/',
        'uploadMethod': 'POST',
        'uploadFields': <String, String>{
          'Content-Type': 'application/octet-stream',
          'key': 'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
        },
        'contentType': 'application/octet-stream',
        'maxBytes': 8 * 1024 * 1024,
        'expiresAtMs': 1_800_000_000_000,
      };

      expect(
        () => RunUploadGrant.fromJson(<String, Object?>{
          ...grant,
          'uploadMethod': 'PUT',
        }),
        throwsFormatException,
      );
      expect(
        () => RunUploadGrant.fromJson(<String, Object?>{
          ...grant,
          'contentType': 'application/json',
        }),
        throwsFormatException,
      );
    });
  });

  test(
    'HttpRunReplayUploader sends every signed field before the replay file',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'rpg-runner-upload-test-',
      );
      final client = HttpClient();
      try {
        final replayFile = File('${temporaryDirectory.path}/replay.bin.gz');
        await replayFile.writeAsBytes(utf8.encode('compressed-replay'));
        final contentLengthBytes = await replayFile.length();
        final requestFuture = server.first;
        final uploadFuture = HttpRunReplayUploader(httpClient: client)
            .uploadReplay(
              uploadGrant: RunUploadGrant(
                runSessionId: 'run_1',
                objectPath:
                    'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
                uploadUrl: 'http://${server.address.address}:${server.port}/',
                uploadMethod: 'POST',
                uploadFields: const <String, String>{
                  'Content-Type': 'application/octet-stream',
                  'key': 'replay-submissions/pending/uid_1/run_1/replay.bin.gz',
                  'policy': 'signed-policy',
                },
                contentType: 'application/octet-stream',
                maxBytes: 1024,
                expiresAtMs: 1_800_000_000_000,
              ),
              replayFilePath: replayFile.path,
              contentLengthBytes: contentLengthBytes,
              contentType: 'application/octet-stream',
            );

        final request = await requestFuture;
        expect(request.method, 'POST');
        expect(request.headers.contentType?.mimeType, 'multipart/form-data');
        final body = await utf8.decodeStream(request);
        expect(body, contains('name="Content-Type"'));
        expect(body, contains('name="key"'));
        expect(body, contains('name="policy"'));
        expect(body, contains('name="file"; filename="replay.bin.gz"'));
        expect(body, contains('compressed-replay'));
        await request.response.close();
        await uploadFuture;
      } finally {
        client.close(force: true);
        await server.close(force: true);
        await temporaryDirectory.delete(recursive: true);
      }
    },
  );
}
