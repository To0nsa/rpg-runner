import 'dart:io';

/// Deletes replay-recorder artifacts owned by this app installation.
abstract interface class LocalReplayArtifactStore {
  Future<void> clear();
}

/// Clears the dedicated recorder spool directory under the system temp path.
///
/// The directory is created only by the app's recorder setup and contains
/// replay blobs plus intermediate frame spools. Keeping cleanup to this exact
/// directory prevents account deletion from following caller-supplied paths.
final class FileLocalReplayArtifactStore implements LocalReplayArtifactStore {
  FileLocalReplayArtifactStore({Directory? spoolDirectory})
    : _spoolDirectory = spoolDirectory ?? defaultReplaySpoolDirectory();

  final Directory _spoolDirectory;

  @override
  Future<void> clear() async {
    if (!await _spoolDirectory.exists()) {
      return;
    }
    await _spoolDirectory.delete(recursive: true);
  }
}

Directory defaultReplaySpoolDirectory() {
  return Directory(
    '${Directory.systemTemp.path}'
    '${Platform.pathSeparator}rpg_runner'
    '${Platform.pathSeparator}replay_spool',
  );
}
