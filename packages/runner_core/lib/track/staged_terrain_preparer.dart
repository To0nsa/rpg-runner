import 'dart:async';

import '../navigation/types/terrain_surface_graph.dart';
import 'staged_terrain_catalog.dart';
import 'staged_terrain_stream_bindings.dart';
import 'staged_terrain_stream_candidate.dart';
import 'track_streamer.dart';
import 'terrain_candidate_preparation_native.dart'
    if (dart.library.js_interop) 'terrain_candidate_preparation_cooperative.dart'
    as preparation;

/// Run-owned, bounded preparation of exact future terrain publications.
///
/// Readiness never controls simulation: [take] returns null on a miss, and the
/// caller must synchronously build the actual selection. Only admitted bindings
/// and immutable profiles enter the worker; no live Core or scheduler is sent.
final class StagedTerrainPreparer {
  StagedTerrainPreparer({
    required this.catalog,
    required Iterable<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles,
    TerrainCandidatePreparation prepareCandidate = prepareTerrainCandidate,
  }) : groundEnemyProfiles = List.unmodifiable(groundEnemyProfiles),
       _prepareCandidate = prepareCandidate;

  /// Eight spawn/cull states cover at least four future chunk boundaries with
  /// the normal margins, including both sides of an exact shared boundary.
  static const selectionCapacity = 8;

  final TerrainCandidatePreparation _prepareCandidate;
  final StagedTerrainCatalog catalog;
  final List<TerrainSurfaceGraphBuildProfile> groundEnemyProfiles;
  final Map<String, StagedTerrainStreamCandidate> _ready = {};
  Map<String, List<ActiveTrackChunkSnapshot>> _wanted = {};
  Future<void>? _pending;
  bool _disposed = false;
  Object? _lastError;
  int _hits = 0;
  int _misses = 0;
  int _completed = 0;
  int _discarded = 0;
  int _lastPreparationMicros = 0;
  int _maxPreparationMicros = 0;

  /// Performance evidence only; these values never enter snapshots or replays.
  TerrainPreparationStats get stats => (
    hits: _hits,
    misses: _misses,
    ready: _ready.length,
    completed: _completed,
    discarded: _discarded,
    lastPreparationMicros: _lastPreparationMicros,
    maxPreparationMicros: _maxPreparationMicros,
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
  /// prepared. Selections must be ordered nearest first. Concurrent calls replace
  /// the queue; each complete result is available before later jobs finish.
  ///
  /// Preparation failures disable preparation for
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
    return _pending ??= Future<void>(_fill);
  }

  Future<void> _fill() async {
    try {
      while (!_disposed && _lastError == null) {
        MapEntry<String, List<ActiveTrackChunkSnapshot>>? next;
        for (final entry in _wanted.entries) {
          if (!_ready.containsKey(entry.key)) {
            next = entry;
            break;
          }
        }
        if (next == null) return;
        final bindings = const StagedTerrainStreamBindingBuilder().build(
          catalog: catalog,
          activeChunks: next.value,
        );
        final watch = Stopwatch()..start();
        final candidate = await _prepareCandidate(
          bindings,
          groundEnemyProfiles,
        );
        watch.stop();
        _completed += 1;
        _lastPreparationMicros = watch.elapsedMicroseconds;
        if (_lastPreparationMicros > _maxPreparationMicros) {
          _maxPreparationMicros = _lastPreparationMicros;
        }
        if (_disposed || _lastError != null || !_wanted.containsKey(next.key)) {
          _discarded += 1;
        } else {
          _ready[next.key] = candidate;
        }
        if (_disposed || _lastError != null) return;
        // Re-read the latest queue after every handoff. A replaced window must
        // not wait for obsolete selections, nor for the rest of an old batch.
      }
    } catch (error) {
      disable(error);
    } finally {
      // Release ownership before the drain future completes. A new request in
      // that completion gap must start its own pump, not join a finished one.
      _pending = null;
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

/// Builds one complete candidate from admitted, immutable preparation inputs.
/// Implementations must preserve the exact synchronous builder's output and
/// complete only after all collision, navigation and render records are ready.
typedef TerrainCandidatePreparation =
    Future<StagedTerrainStreamCandidate> Function(
      List<StagedTerrainChunkBinding> bindings,
      List<TerrainSurfaceGraphBuildProfile> profiles,
    );

/// Prepares one exact candidate using an isolate on native platforms or
/// cooperative event-queue slices in browsers. No live run state is captured.
Future<StagedTerrainStreamCandidate> prepareTerrainCandidate(
  List<StagedTerrainChunkBinding> bindings,
  List<TerrainSurfaceGraphBuildProfile> profiles,
) => preparation.prepareTerrainCandidate(bindings, profiles);

/// Diagnostic counters and end-to-end worker latency; never simulation inputs.
typedef TerrainPreparationStats = ({
  int hits,
  int misses,
  int ready,
  int completed,
  int discarded,
  int lastPreparationMicros,
  int maxPreparationMicros,
  String? lastError,
});
