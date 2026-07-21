import 'dart:typed_data';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart' as commons;

import 'google_api_helpers.dart';

/// Reports the first streamed byte count that exceeded the configured ceiling.
final class ReplayPayloadTooLargeException implements Exception {
  const ReplayPayloadTooLargeException({
    required this.maxBytes,
    required this.observedBytes,
  });

  final int maxBytes;
  final int observedBytes;

  @override
  String toString() =>
      'ReplayPayloadTooLarge(maxBytes=$maxBytes, observedBytes=$observedBytes)';
}

/// Indicates that the exact finalized object generation is no longer readable.
final class ReplayGenerationUnavailableException implements Exception {
  const ReplayGenerationUnavailableException({
    required this.objectPath,
    required this.storageGeneration,
  });

  final String objectPath;
  final String storageGeneration;
}

/// Replay bytes bound to the object path and generation that supplied them.
class LoadedReplay {
  const LoadedReplay({
    required this.runSessionId,
    required this.objectPath,
    required this.storageGeneration,
    required this.bytes,
  });

  final String runSessionId;
  final String objectPath;
  final String storageGeneration;
  final List<int> bytes;
}

/// Loads only explicitly identified replay evidence.
///
/// Implementations must not replace [storageGeneration] with the latest object
/// at [objectPath].
abstract class ReplayLoader {
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
    required String storageGeneration,
  });
}

class UnimplementedReplayLoader implements ReplayLoader {
  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
    required String storageGeneration,
  }) {
    throw UnimplementedError('Replay loading is not configured.');
  }
}

class GoogleCloudStorageReplayLoader implements ReplayLoader {
  GoogleCloudStorageReplayLoader({
    required this.bucketName,
    required this.apiProvider,
    this.maxBytes = 8 * 1024 * 1024,
  }) {
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }
  }

  final String bucketName;
  final GoogleCloudApiProvider apiProvider;
  final int maxBytes;

  @override
  Future<LoadedReplay> loadReplay({
    required String runSessionId,
    required String objectPath,
    required String storageGeneration,
  }) async {
    final storageApi = await apiProvider.storageApi();
    final Object object;
    try {
      object = await storageApi.objects.get(
        bucketName,
        objectPath,
        generation: storageGeneration,
        ifGenerationMatch: storageGeneration,
        downloadOptions: commons.DownloadOptions.fullMedia,
      );
    } catch (error) {
      if (isApiNotFound(error) || isApiConflict(error)) {
        throw ReplayGenerationUnavailableException(
          objectPath: objectPath,
          storageGeneration: storageGeneration,
        );
      }
      rethrow;
    }
    if (object is! commons.Media) {
      throw StateError(
        'Expected media response for object "$objectPath", got metadata.',
      );
    }
    final bytes = await collectReplayBytes(object.stream, maxBytes: maxBytes);
    return LoadedReplay(
      runSessionId: runSessionId,
      objectPath: objectPath,
      storageGeneration: storageGeneration,
      bytes: bytes,
    );
  }
}

/// Collects a replay stream while enforcing [maxBytes] during consumption.
///
/// The returned list never exceeds the byte ceiling.
Future<List<int>> collectReplayBytes(
  Stream<List<int>> stream, {
  required int maxBytes,
}) async {
  if (maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
  }
  final bytes = BytesBuilder(copy: false);
  var observedBytes = 0;
  await for (final chunk in stream) {
    observedBytes += chunk.length;
    if (observedBytes > maxBytes) {
      throw ReplayPayloadTooLargeException(
        maxBytes: maxBytes,
        observedBytes: observedBytes,
      );
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
