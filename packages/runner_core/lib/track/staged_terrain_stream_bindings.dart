/// Binds existing scheduler selections to admitted staged terrain records.
library;

import '../collision/terrain/terrain_numeric.dart';
import 'staged_terrain_catalog.dart';
import 'track_streamer.dart';

/// Creates staged-terrain bindings from the active legacy scheduler snapshot.
///
/// This is a fail-closed bridge, not a second chunk selector. The scheduler
/// remains responsible for active chunk order and world intervals; this adapter
/// only checks that each selected key has compatible generated local geometry
/// before it can be included in a future atomic terrain publication.
final class StagedTerrainStreamBindingBuilder {
  const StagedTerrainStreamBindingBuilder();

  /// Returns canonical streamed bindings for [activeChunks].
  ///
  /// Starts and ends must lie exactly on Core's physics grid. A selected chunk
  /// must have a stable key and its generated width must equal the scheduler's
  /// active interval, preventing a stale artifact from shifting downstream
  /// chunks while still looking locally valid.
  List<StagedTerrainChunkBinding> build({
    required StagedTerrainArtifactCatalog catalog,
    required Iterable<ActiveTrackChunkSnapshot> activeChunks,
  }) {
    final ordered = List<ActiveTrackChunkSnapshot>.of(activeChunks)
      ..sort((left, right) => left.index.compareTo(right.index));
    final bindings = <StagedTerrainChunkBinding>[];
    int? previousIndex;
    for (final active in ordered) {
      if (previousIndex == active.index) {
        throw ArgumentError.value(
          activeChunks,
          'activeChunks',
          'Streamed chunk indices must be unique.',
        );
      }
      previousIndex = active.index;
      final key = active.chunkKey;
      if (key == null) {
        throw StateError(
          'Streamed chunk ${active.index} (${active.patternName}) has no '
          'authored key for staged terrain binding.',
        );
      }
      final startTicks = _exactPhysicsTicks(active.startX, 'active.startX');
      final endTicks = _exactPhysicsTicks(active.endX, 'active.endX');
      if (endTicks <= startTicks) {
        throw ArgumentError.value(
          active,
          'activeChunks',
          'Streamed chunk intervals must have positive width.',
        );
      }
      final staged = catalog.requireChunk(key);
      final expectedWidthTicks = staged.width * terrainPhysicsTicksPerWorldUnit;
      if (endTicks - startTicks != expectedWidthTicks) {
        throw StateError(
          'Streamed chunk ${active.index} ($key) has width '
          '${endTicks - startTicks} physics ticks but staged source requires '
          '$expectedWidthTicks.',
        );
      }
      bindings.add(
        catalog.bind(
          chunkKey: key,
          chunkIndex: active.index,
          worldOriginXTicks: startTicks,
        ),
      );
    }
    return List<StagedTerrainChunkBinding>.unmodifiable(bindings);
  }
}

int _exactPhysicsTicks(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite.');
  }
  final scaled = value * terrainPhysicsTicksPerWorldUnit;
  final rounded = scaled.round();
  if (scaled != rounded.toDouble()) {
    throw ArgumentError.value(
      value,
      name,
      'Must be exactly representable on the terrain physics grid.',
    );
  }
  return TerrainPoint(rounded, 0).xTicks;
}
