import 'dart:isolate';

import '../navigation/types/terrain_surface_graph.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_stream_bindings.dart';
import 'staged_terrain_stream_candidate.dart';
import 'track_streamer.dart';

/// Run-owned, bounded preparation of exact future terrain publications.
///
/// Readiness never controls simulation: [take] returns null on a miss, and the
/// caller must synchronously build the actual selection. Only admitted bindings
/// and immutable profiles enter the worker; no live Core or scheduler is sent.
final class StagedTerrainPreparer {
  StagedTerrainPreparer({
    required this.catalog,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
  }) : groundEnemyProfiles = List.unmodifiable(groundEnemyProfiles);

  /// Eight spawn/cull states cover at least four future chunk boundaries with
  /// the normal margins, including both sides of an exact shared boundary.
  static const selectionCapacity = 8;

  final StagedTerrainCatalog catalog;
  final List<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles;
  final Map<String, StagedTerrainStreamCandidate> _ready = {};
  Map<String, List<ActiveTrackChunkSnapshot>> _wanted = {};
  Future<void>? _pending;
  bool _disposed = false;
  Object? _lastError;
  int _hits = 0;
  int _misses = 0;

  /// Performance evidence only; these values never enter snapshots or replays.
  ({int hits, int misses, int ready, String? lastError}) get stats => (
    hits: _hits,
    misses: _misses,
    ready: _ready.length,
    lastError: _lastError?.toString(),
  );

  /// Consumes only an exact selection match and assigns its live version.
  StagedTerrainStreamCandidate? take(
    List<ActiveTrackChunkSnapshot> selection, {
    required int geometryVersion,
  }) {
    final candidate = _ready.remove(_selectionKey(selection));
    if (candidate == null) {
      _misses += 1;
      return null;
    }
    _hits += 1;
    return candidate.withGeometryVersion(geometryVersion);
  }

  /// Replaces the target window and waits until its current missing states are
  /// prepared. Concurrent calls coalesce; obsolete results are discarded.
  ///
  /// Worker failures (including unsupported isolates) disable preparation for
  /// this instance and remain visible in [stats]. They never suppress a required
  /// synchronous build or change the simulation's error behavior.
  Future<void> prepare(List<List<ActiveTrackChunkSnapshot>> selections) {
    if (selections.length > selectionCapacity) {
      throw ArgumentError('Terrain preparation window exceeds capacity.');
    }
    if (_disposed || _lastError != null) return Future<void>.value();
    _wanted = {
      for (final selection in selections)
        _selectionKey(selection): List.unmodifiable(selection),
    };
    _ready.removeWhere((key, _) => !_wanted.containsKey(key));
    // Binding and isolate handoff run after the current simulation/frame stack.
    return _pending ??= Future<void>(_fill).whenComplete(() => _pending = null);
  }

  Future<void> _fill() async {
    try {
      while (!_disposed) {
        final missing = _wanted.entries
            .where((entry) => !_ready.containsKey(entry.key))
            .toList();
        if (missing.isEmpty) return;
        final request = _PreparationRequest(
          selections: [
            for (final entry in missing)
              const StagedTerrainStreamBindingBuilder().build(
                catalog: catalog,
                activeChunks: entry.value,
              ),
          ],
          profiles: groundEnemyProfiles,
        );
        final candidates = await _prepareInIsolate(request);
        if (_disposed) return;
        for (var i = 0; i < missing.length; i += 1) {
          final key = missing[i].key;
          if (_wanted.containsKey(key)) _ready[key] = candidates[i];
        }
      }
    } catch (error) {
      disable(error);
    }
  }

  /// Records a speculative preparation failure without failing an earlier
  /// simulation tick. Actual selected content still follows normal admission.
  void disable(Object error) {
    _lastError = error;
    _ready.clear();
    _wanted.clear();
  }

  /// Releases retained data and prevents refills after the owning run closes.
  /// An already-running worker may finish; its bounded result is discarded.
  void dispose() {
    _disposed = true;
    _ready.clear();
    _wanted.clear();
  }
}

String _selectionKey(List<ActiveTrackChunkSnapshot> selection) => selection
    .map(
      (chunk) =>
          '${chunk.index}:${chunk.chunkKey?.length}:${chunk.chunkKey}:'
          '${chunk.startX}:${chunk.endX}',
    )
    .join('|');

final class _PreparationRequest {
  const _PreparationRequest({required this.selections, required this.profiles});
  final List<List<StagedTerrainChunkBinding>> selections;
  final List<TerrainSurfaceGraphBuildProfile> profiles;
}

// Keep the closure outside the preparer so it cannot capture the run/catalog.
Future<List<StagedTerrainStreamCandidate>> _prepareInIsolate(
  _PreparationRequest request,
) => Isolate.run(
  () => [
    for (final bindings in request.selections)
      const StagedTerrainStreamCandidateBuilder().buildFromBindings(
        bindings: bindings,
        geometryVersion: 0,
        groundEnemyProfiles: request.profiles,
      ),
  ],
  debugName: 'terrain-preparation',
);
