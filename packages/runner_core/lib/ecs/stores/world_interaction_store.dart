import '../../collision/terrain/terrain_numeric.dart';
import '../../interactions/world_interaction_catalog.dart';
import '../../snapshots/world_interaction_snapshot.dart';
import '../../track/staged_terrain_catalog.dart';
import '../../interactions/world_interaction_placement.dart';
import '../../track/track_streamer.dart';

/// One admitted top surface attached to a streamed prefab occurrence.
final class WorldInteractionState {
  WorldInteractionState({
    required this.binding,
    required this.instanceId,
    required this.chunkIndex,
    required this.placementKey,
    required this.leftTicks,
    required this.rightTicks,
    required this.topTicks,
    required this.scale,
    this.activationTick,
  });

  final WorldInteractionBinding binding;
  final String instanceId;
  final int chunkIndex;
  final String? placementKey;
  final int leftTicks, rightTicks, topTicks;
  final double scale;
  int? activationTick;
  int elapsedTicks = 0;
}

/// Active views are stream-owned; activation memory belongs to the whole run.
/// Binding consumes admitted terrain provenance, never sprite bounds or a
/// second collision compiler. Authored campaign bindings reuse the same resolver.
final class WorldInteractionStore {
  List<ActiveTrackChunkSnapshot>? _lastSelection;
  List<WorldInteractionBinding>? _lastBindings;
  final List<WorldInteractionState> states = [];
  final Map<String, int> _activatedAt = {};

  /// Call after publishing the selected terrain. Missing/ambiguous targets and
  /// shapes without a flat top fail before the active collection is replaced.
  void synchronize(
    List<ActiveTrackChunkSnapshot> selected,
    StagedTerrainCatalog? catalog, {
    List<WorldInteractionBinding> bindings = WorldInteractionCatalog.bindings,
  }) {
    if (identical(selected, _lastSelection) &&
        identical(bindings, _lastBindings)) {
      return;
    }
    final retained = {for (final state in states) state.instanceId: state};
    final next = <WorldInteractionState>[];
    final ids = <String>{};
    for (final chunk in selected) {
      for (final binding in bindings) {
        if (chunk.chunkKey != binding.chunkKey ||
            (binding.missionChunkId != null &&
                binding.missionChunkId != chunk.missionChunkId)) {
          continue;
        }
        if (catalog == null) {
          throw StateError('World interactions require admitted terrain.');
        }
        final terrain = catalog.requireChunk(binding.chunkKey);
        final surface = resolveWorldInteractionSurface(binding, terrain);
        final origin = physicsCoordinateToTicks(
          chunk.startX,
          name: 'chunk.startX',
        );
        final id = '${chunk.index}:${binding.key}';
        if (!ids.add(id)) {
          throw StateError('Duplicate interaction identity: $id');
        }
        final candidate = WorldInteractionState(
          binding: binding,
          instanceId: id,
          chunkIndex: chunk.index,
          placementKey: surface.placementKey,
          leftTicks: origin + surface.leftTicks,
          rightTicks: origin + surface.rightTicks,
          topTicks: surface.topTicks,
          scale: surface.scale,
          activationTick: _activatedAt[id],
        );
        final old = retained[id];
        if (old != null &&
            (old.placementKey != candidate.placementKey ||
                old.leftTicks != candidate.leftTicks ||
                old.rightTicks != candidate.rightTicks ||
                old.topTicks != candidate.topTicks ||
                old.scale != candidate.scale ||
                old.binding.interactionId != binding.interactionId ||
                old.binding.appearanceId != binding.appearanceId)) {
          throw StateError('An active interaction cannot change within a run.');
        }
        next.add(old ?? candidate);
      }
    }
    states
      ..clear()
      ..addAll(next);
    _lastSelection = selected;
    _lastBindings = bindings;
  }

  /// Remembers a successful activation even when its chunk is later retired.
  void activate(WorldInteractionState state, int tick) {
    if (state.activationTick != null) return;
    state.activationTick = tick;
    _activatedAt[state.instanceId] = tick;
  }

  List<WorldInteractionSnapshot> buildSnapshots() => List.unmodifiable([
    for (final state in states)
      WorldInteractionSnapshot(
        instanceId: state.instanceId,
        interactionId: state.binding.interactionId,
        appearanceId: state.binding.appearanceId,
        x:
            (state.leftTicks + state.rightTicks) /
            (2 * terrainPhysicsTicksPerWorldUnit),
        y: state.topTicks / terrainPhysicsTicksPerWorldUnit,
        scale: state.scale,
        zIndex: state.binding.zIndex,
        active: state.activationTick != null,
        elapsedTicks: state.elapsedTicks,
      ),
  ]);
}
