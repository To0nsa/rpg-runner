import 'local_replay_artifact_store_unavailable.dart'
    if (dart.library.io) 'local_replay_artifact_store_io.dart'
    as platform;

/// Deletes replay artifacts owned by this app installation.
abstract interface class LocalReplayArtifactStore {
  Future<void> clear();
}

LocalReplayArtifactStore createLocalReplayArtifactStore() =>
    platform.createLocalReplayArtifactStore();
