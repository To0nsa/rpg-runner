import 'package:_discoveryapis_commons/_discoveryapis_commons.dart'
    as commons;

import 'google_api_helpers.dart';

class LoadedReplay {
  const LoadedReplay({
    required this.runSessionId,
    required this.objectPath,
    required this.bytes,
  });

  final String runSessionId;
  final String objectPath;
  final List<int> bytes;
}

abstract class ReplayLoader {
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
  });
}

class UnimplementedReplayLoader implements ReplayLoader {
  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
  }) {
    throw UnimplementedError(
      'Replay loading implementation lands in Phase 4.',
    );
  }
}

class GoogleCloudStorageReplayLoader implements ReplayLoader {
  GoogleCloudStorageReplayLoader({
    required this.bucketName,
    required this.apiProvider,
  });

  final String bucketName;
  final GoogleCloudApiProvider apiProvider;

  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
  }) async {
    final storageApi = await apiProvider.storageApi();
    final object = await storageApi.objects.get(
      bucketName,
      objectPath,
      downloadOptions: commons.DownloadOptions.fullMedia,
    );
    if (object is! commons.Media) {
      throw StateError(
        'Expected media response for object "$objectPath", got metadata.',
      );
    }
    final bytes = await object.stream
        .expand((List<int> chunk) => chunk)
        .toList();
    return LoadedReplay(
      runSessionId: runSessionId,
      objectPath: objectPath,
      bytes: bytes,
    );
  }
}
