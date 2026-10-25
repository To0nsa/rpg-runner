import 'local_replay_artifact_store.dart';

LocalReplayArtifactStore createLocalReplayArtifactStore() =>
    const _UnavailableReplayArtifactStore();

class _UnavailableReplayArtifactStore implements LocalReplayArtifactStore {
  const _UnavailableReplayArtifactStore();

  @override
  Future<void> clear() async {
    throw UnsupportedError('Replay storage is unavailable on this platform.');
  }
}
