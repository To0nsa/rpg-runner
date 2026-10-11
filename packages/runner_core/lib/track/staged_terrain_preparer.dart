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
/// [requireSelection] prioritizes an exact live selection and completes as soon
/// as it is available. The host may wait before a tick; preparation never moves
/// the simulation. Only immutable bindings and profiles enter the worker.
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
  final Set<String> _inFlight = {};
  ({
    String key,
    List<ActiveTrackChunkSnapshot> selection,
    Completer<void> completion,
  })?
  _required;
  Timer? _requiredTimeout;
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
    final key = _selectionKey(selection);
    final candidate = _ready.remove(key);
    if (candidate == null) {
      _misses += 1;
      return null;
    }
    _wanted.remove(key);
    if (_required?.key == key) {
      _required = null;
      _requiredTimeout?.cancel();
      _requiredTimeout = null;
    }
    _hits += 1;
    return candidate.withGeometryVersion(geometryVersion);
  }

  /// Replaces the target window and waits until its current missing states are
  /// prepared. Selections must be ordered nearest first. Concurrent calls replace
  /// the queue; each complete result is available before later jobs finish.
  ///
  /// Speculative failures remain visible in [stats]. A required request fails
  /// explicitly so a live host can offer recovery without constructing terrain
  /// on its frame stack.
  Future<void> prepare(List<List<ActiveTrackChunkSnapshot>> selections) =>
      _prepare(selections, concurrency: 1);

  /// Awaits the complete startup window with two native workers, or one
  /// cooperative browser lane. Runtime refills still use [prepare]'s one worker.
  /// Cancellation/failure drains already-started jobs without publishing them.
  Future<void> prepareForRun(List<List<ActiveTrackChunkSnapshot>> selections) =>
      _prepare(
        selections,
        concurrency: preparation.startupPreparationConcurrency,
      );

  Future<void> _prepare(
    List<List<ActiveTrackChunkSnapshot>> selections, {
    required int concurrency,
  }) {
    if (selections.length > selectionCapacity) {
      throw ArgumentError('Terrain preparation window exceeds capacity.');
    }
    if (_disposed || _lastError != null) return Future<void>.value();
    final required = _required;
    final targets = {
      if (required != null) required.key: required.selection,
      for (final selection in selections)
        _selectionKey(selection): List<ActiveTrackChunkSnapshot>.unmodifiable(
          selection,
        ),
    };
    _wanted = Map.fromEntries(targets.entries.take(selectionCapacity));
    _ready.removeWhere((key, _) => !_wanted.containsKey(key));
    // Binding and isolate handoff run after the current simulation/frame stack.
    return _pending ??= Future<void>(() => _fill(concurrency));
  }

  /// Reserves a required selection ahead of speculative work. There can be only
  /// one outstanding live tick; repeated requests for it share the same future.
  /// The candidate remains protected until [take]. A dead worker fails after
  /// [timeout], allowing the owner to replace this preparer and retry.
  Future<void> requireSelection(
    List<ActiveTrackChunkSnapshot> selection, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (_disposed) {
      return Future.error(StateError('Terrain preparation disposed.'));
    }
    if (_lastError != null) return Future.error(_lastError!);
    final key = _selectionKey(selection);
    final required = _required;
    if (required != null) {
      if (required.key != key) {
        return Future.error(
          StateError('A different terrain selection is pending.'),
        );
      }
      return required.completion.future;
    }
    final completion = Completer<void>();
    _required = (
      key: key,
      selection: List.unmodifiable(selection),
      completion: completion,
    );
    if (_ready.containsKey(key)) {
      completion.complete();
    } else {
      _requiredTimeout = Timer(
        timeout,
        () => disable(
          TimeoutException('Required terrain preparation timed out.', timeout),
        ),
      );
    }
    unawaited(prepare(_wanted.values.toList()));
    return completion.future;
  }

  Future<void> _fill(int concurrency) async {
    try {
      await Future.wait<void>([
        for (var lane = 0; lane < concurrency; lane++) _fillLane(),
      ]);
    } finally {
      // A completed drain cannot absorb a new request without starting a pump.
      _pending = null;
    }
  }

  Future<void> _fillLane() async {
    try {
      while (!_disposed && _lastError == null) {
        MapEntry<String, List<ActiveTrackChunkSnapshot>>? next;
        for (final entry in _wanted.entries) {
          if (!_ready.containsKey(entry.key) &&
              !_inFlight.contains(entry.key)) {
            next = entry;
            break;
          }
        }
        if (next == null) return;
        _inFlight.add(next.key);
        try {
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
          if (_disposed ||
              _lastError != null ||
              !_wanted.containsKey(next.key)) {
            _discarded += 1;
          } else {
            _ready[next.key] = candidate;
            final required = _required;
            if (required?.key == next.key &&
                !required!.completion.isCompleted) {
              _requiredTimeout?.cancel();
              _requiredTimeout = null;
              required.completion.complete();
            }
          }
        } finally {
          _inFlight.remove(next.key);
        }
        if (_disposed || _lastError != null) return;
        // Re-read the latest queue after every handoff. A replaced window must
        // not wait for obsolete selections, nor for the rest of an old batch.
      }
    } catch (error) {
      disable(error);
    }
  }

  /// Records a speculative preparation failure without failing an earlier
  /// simulation tick. Actual selected content still follows normal admission.
  void disable(Object error) {
    _lastError = error;
    // A later speculative failure cannot revoke an already completed live
    // reservation before its awaiting owner consumes it.
    final reservedKey = _required?.completion.isCompleted == true
        ? _required!.key
        : null;
    _failRequired(error);
    _ready.removeWhere((key, _) => key != reservedKey);
    _wanted.clear();
  }

  void _failRequired(Object error) {
    _requiredTimeout?.cancel();
    _requiredTimeout = null;
    final required = _required;
    _required = null;
    if (required != null && !required.completion.isCompleted) {
      required.completion.completeError(error);
    }
  }

  /// Releases retained data and prevents refills after the owning run closes.
  /// An already-running worker may finish; its bounded result is discarded.
  void dispose() {
    _disposed = true;
    _failRequired(StateError('Terrain preparation disposed.'));
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
