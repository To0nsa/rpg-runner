import 'package:googleapis/storage/v1.dart' as storage;

import 'google_api_helpers.dart';

const String _validatedReplayPrefix = 'replay-submissions/validated';

/// Immutable replay artifact created after a replay has passed deterministic
/// validation and before its accepted handoff is committed.
final class ArchivedValidatedReplay {
  const ArchivedValidatedReplay({
    required this.objectPath,
    required this.storageGeneration,
  });

  final String objectPath;
  final String storageGeneration;
}

/// Moves accepted replay evidence out of the short-lived client upload area.
///
/// Storage and Firestore cannot commit atomically. An archive can therefore
/// exist before the accepted handoff, but the handoff never commits unless this
/// exact immutable archive is available.
abstract interface class ValidatedReplayArchiver {
  Future<ArchivedValidatedReplay> archive({
    required String runSessionId,
    required String sourceObjectPath,
    required String sourceStorageGeneration,
  });
}

/// Legacy-compatible test fallback. The environment-built worker always uses
/// [GoogleCloudStorageValidatedReplayArchiver].
class PassthroughValidatedReplayArchiver implements ValidatedReplayArchiver {
  const PassthroughValidatedReplayArchiver();

  @override
  Future<ArchivedValidatedReplay> archive({
    required String runSessionId,
    required String sourceObjectPath,
    required String sourceStorageGeneration,
  }) async => ArchivedValidatedReplay(
    objectPath: sourceObjectPath,
    storageGeneration: sourceStorageGeneration,
  );
}

class GoogleCloudStorageValidatedReplayArchiver
    implements ValidatedReplayArchiver {
  GoogleCloudStorageValidatedReplayArchiver({
    required this.bucketName,
    required this.apiProvider,
  });

  final String bucketName;
  final GoogleCloudApiProvider apiProvider;

  @override
  Future<ArchivedValidatedReplay> archive({
    required String runSessionId,
    required String sourceObjectPath,
    required String sourceStorageGeneration,
  }) async {
    final destinationObjectPath = validatedReplayObjectPath(runSessionId);
    final storageApi = await apiProvider.storageApi();
    try {
      final copied = await storageApi.objects.copy(
        storage.Object(),
        bucketName,
        sourceObjectPath,
        bucketName,
        destinationObjectPath,
        sourceGeneration: sourceStorageGeneration,
        ifSourceGenerationMatch: sourceStorageGeneration,
        ifGenerationMatch: '0',
      );
      final destinationGeneration = _positiveGeneration(copied.generation);
      if (destinationGeneration == null) {
        throw StateError(
          'Validated replay copy omitted destination object generation.',
        );
      }
      return ArchivedValidatedReplay(
        objectPath: destinationObjectPath,
        storageGeneration: destinationGeneration,
      );
    } catch (error) {
      if (!isApiConflict(error)) {
        rethrow;
      }
      final source = await storageApi.objects.get(
        bucketName,
        sourceObjectPath,
        generation: sourceStorageGeneration,
        ifGenerationMatch: sourceStorageGeneration,
      );
      final destination = await storageApi.objects.get(
        bucketName,
        destinationObjectPath,
      );
      if (source is! storage.Object ||
          destination is! storage.Object ||
          source.size != destination.size ||
          source.crc32c == null ||
          source.crc32c != destination.crc32c) {
        throw StateError(
          'Existing validated replay does not match finalized replay evidence.',
        );
      }
      final destinationGeneration = _positiveGeneration(destination.generation);
      if (destinationGeneration == null) {
        throw StateError(
          'Existing validated replay omitted destination object generation.',
        );
      }
      return ArchivedValidatedReplay(
        objectPath: destinationObjectPath,
        storageGeneration: destinationGeneration,
      );
    }
  }
}

String validatedReplayObjectPath(String runSessionId) {
  final normalized = runSessionId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      runSessionId,
      'runSessionId',
      'must be non-empty',
    );
  }
  return '$_validatedReplayPrefix/$normalized.bin.gz';
}

String? _positiveGeneration(String? raw) {
  if (raw == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(raw)) {
    return null;
  }
  return raw;
}
