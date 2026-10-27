import 'package:run_protocol/replay_blob.dart';

import 'ghost_api.dart';
import 'ghost_replay_cache_unavailable.dart'
    if (dart.library.io) 'ghost_replay_cache_io.dart'
    as platform;

final class GhostReplayBootstrap {
  const GhostReplayBootstrap({
    required this.manifest,
    required this.replayBlob,
    required this.cacheKey,
    required this.cachedAtMs,
  });

  final GhostManifest manifest;
  final ReplayBlobV1 replayBlob;

  /// Opaque cache identity; only the platform cache interprets this value.
  final String cacheKey;
  final int cachedAtMs;
}

abstract class GhostReplayCache {
  Future<GhostReplayBootstrap> loadReplay({required GhostManifest manifest});
}

abstract class GhostReplayDownloader {
  Future<List<int>> downloadBytes({required Uri url});
}

/// Constructs only the selected platform's cache adapter.
GhostReplayCache createGhostReplayCache() => platform.createGhostReplayCache();

/// Local Practice never requests ghosts or allocates online cache storage.
class UnavailableGhostReplayCache implements GhostReplayCache {
  const UnavailableGhostReplayCache();

  @override
  Future<GhostReplayBootstrap> loadReplay({
    required GhostManifest manifest,
  }) async {
    throw UnsupportedError('Ghost replays are unavailable in local Practice.');
  }
}
