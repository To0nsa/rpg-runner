import '../../snapshots/trap_snapshot.dart';
import '../../track/staged_terrain_catalog.dart';
import '../../track/track_streamer.dart';
import '../../traps/trap_catalog.dart';
import '../../traps/trap_placement.dart';
import '../../traps/trap_validation.dart';
import '../entity_id.dart';

/// State for one streamed placement; traps are not damageable ECS entities.
final class TrapState {
  TrapState({
    required this.source,
    required this.placement,
    required this.originX,
  }) : frameIndex = TrapCatalog.get(source.trapId).idleFrameIndex;
  final TrapSourceRef source;
  final TrapPlacement placement;
  final double originX;
  double get x => originX + placement.x;
  double get y => placement.y.toDouble();
  TrapPhase phase = TrapPhase.idle;
  int activationTick = -1;
  int cooldownUntilTick = -1;
  int frameIndex;
  bool fired = false;
  EntityId? dart;
  final Set<EntityId> attemptedTargets = {};
}

/// Stream-owned state, synchronized only after the matching terrain publishes.
final class TrapStore {
  List<ActiveTrackChunkSnapshot>? _lastSelection;
  final List<TrapState> states = [];

  void synchronize(
    List<ActiveTrackChunkSnapshot> selected,
    StagedTerrainCatalog? catalog,
  ) {
    if (identical(selected, _lastSelection)) return;
    final retained = {for (final state in states) state.source: state};
    final next = <TrapState>[];
    for (final chunk in selected) {
      if (chunk.traps.isEmpty) continue;
      final key = chunk.chunkKey;
      if (key == null || catalog == null) {
        throw StateError('Traps require an admitted authored chunk.');
      }
      final terrain = catalog.requireChunk(key);
      validateTrapPlacements(
        chunk.traps,
        chunkWidth: terrain.width,
        chunkHeight: terrain.height,
      );
      for (var ordinal = 0; ordinal < chunk.traps.length; ordinal++) {
        final source = TrapSourceRef(
          trapId: chunk.traps[ordinal].trapId,
          chunkKey: key,
          chunkIndex: chunk.index,
          placementOrdinal: ordinal,
        );
        final old = retained[source];
        if (old != null &&
            (old.placement != chunk.traps[ordinal] ||
                old.originX != chunk.startX)) {
          throw StateError(
            'An active trap placement cannot change within a run.',
          );
        }
        next.add(
          old ??
              TrapState(
                source: source,
                placement: chunk.traps[ordinal],
                originX: chunk.startX,
              ),
        );
      }
    }
    states
      ..clear()
      ..addAll(next);
    _lastSelection = selected;
  }

  /// Release per-actor history before its ECS ID is recycled. Fired darts are
  /// independently owned by the projectile store and survive trap retirement.
  void removeEntity(EntityId entity) {
    for (final state in states) {
      state.attemptedTargets.remove(entity);
      if (state.dart == entity) state.dart = null;
    }
  }

  List<TrapSnapshot> buildSnapshots() => List.unmodifiable([
    for (final state in states)
      TrapSnapshot(
        source: state.source,
        x: state.x,
        y: state.y,
        facing: state.placement.facing,
        phase: state.phase,
        frameIndex: state.frameIndex,
      ),
  ]);
}
