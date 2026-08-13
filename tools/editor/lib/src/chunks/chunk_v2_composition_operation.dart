import 'package:meta/meta.dart';

import 'chunk_domain_models.dart';
import 'chunk_v2_composition_commit.dart';
import 'chunk_v2_composition_semantics.dart';
import 'chunk_v2_file_data.dart';

/// The one canonical composition list targeted by a local operation.
enum ChunkV2CompositionTarget { tileLayers, prefabs, markers }

/// The structural change applied to the captured target list.
enum ChunkV2CompositionOperationKind { add, replace, delete }

/// Immutable identity and source snapshot captured before a composition UI
/// operation begins.
///
/// Derived presentation keys are retained only to reconcile UI selection. The
/// canonical source index identifies an existing record for the lifetime of
/// this operation. Owner key, owner revision, and the complete composition
/// snapshot protect the eventual plugin command from stale or misrouted edits.
@immutable
final class ChunkV2CompositionOperation {
  const ChunkV2CompositionOperation._({
    required this.expectedChunkKey,
    required this.expectedRevision,
    required this.before,
    required this.target,
    required this.kind,
    required this.sourceIndex,
    required this.presentationKey,
  });

  factory ChunkV2CompositionOperation.add({
    required ChunkV2FileData chunk,
    required ChunkV2CompositionTarget target,
  }) => ChunkV2CompositionOperation._(
    expectedChunkKey: chunk.chunkKey,
    expectedRevision: chunk.revision,
    before: ChunkV2CompositionSnapshot.fromChunk(chunk),
    target: target,
    kind: ChunkV2CompositionOperationKind.add,
    sourceIndex: null,
    presentationKey: null,
  );

  factory ChunkV2CompositionOperation.replace({
    required ChunkV2FileData chunk,
    required ChunkV2CompositionTarget target,
    required int sourceIndex,
    String? presentationKey,
  }) => ChunkV2CompositionOperation._existing(
    chunk: chunk,
    target: target,
    kind: ChunkV2CompositionOperationKind.replace,
    sourceIndex: sourceIndex,
    presentationKey: presentationKey,
  );

  factory ChunkV2CompositionOperation.delete({
    required ChunkV2FileData chunk,
    required ChunkV2CompositionTarget target,
    required int sourceIndex,
    String? presentationKey,
  }) => ChunkV2CompositionOperation._existing(
    chunk: chunk,
    target: target,
    kind: ChunkV2CompositionOperationKind.delete,
    sourceIndex: sourceIndex,
    presentationKey: presentationKey,
  );

  factory ChunkV2CompositionOperation._existing({
    required ChunkV2FileData chunk,
    required ChunkV2CompositionTarget target,
    required ChunkV2CompositionOperationKind kind,
    required int sourceIndex,
    required String? presentationKey,
  }) {
    final length = switch (target) {
      ChunkV2CompositionTarget.tileLayers => chunk.tileLayers.length,
      ChunkV2CompositionTarget.prefabs => chunk.prefabs.length,
      ChunkV2CompositionTarget.markers => chunk.markers.length,
    };
    RangeError.checkValidIndex(sourceIndex, List<Object?>.filled(length, null));
    return ChunkV2CompositionOperation._(
      expectedChunkKey: chunk.chunkKey,
      expectedRevision: chunk.revision,
      before: ChunkV2CompositionSnapshot.fromChunk(chunk),
      target: target,
      kind: kind,
      sourceIndex: sourceIndex,
      presentationKey: presentationKey,
    );
  }

  final String expectedChunkKey;
  final int expectedRevision;
  final ChunkV2CompositionSnapshot before;
  final ChunkV2CompositionTarget target;
  final ChunkV2CompositionOperationKind kind;
  final int? sourceIndex;

  /// Projection-local key captured for post-acceptance UI reconciliation.
  final String? presentationKey;

  ChunkV2CompositionCommit? buildTileLayer({TileLayerDef? candidate}) {
    _requireTarget(ChunkV2CompositionTarget.tileLayers, candidate);
    final next = _apply(before.tileLayers, candidate);
    return _build(
      ChunkV2CompositionSnapshot(
        tileLayers: canonicalizeChunkTileLayers(next),
        prefabs: before.prefabs,
        markers: before.markers,
      ),
    );
  }

  ChunkV2CompositionCommit? buildPrefab({PlacedPrefabDef? candidate}) {
    _requireTarget(ChunkV2CompositionTarget.prefabs, candidate);
    final next = _apply(before.prefabs, candidate);
    return _build(
      ChunkV2CompositionSnapshot(
        tileLayers: before.tileLayers,
        prefabs: canonicalizeChunkPrefabs(next),
        markers: before.markers,
      ),
    );
  }

  ChunkV2CompositionCommit? buildMarker({PlacedMarkerDef? candidate}) {
    _requireTarget(ChunkV2CompositionTarget.markers, candidate);
    final next = _apply(before.markers, candidate);
    return _build(
      ChunkV2CompositionSnapshot(
        tileLayers: before.tileLayers,
        prefabs: before.prefabs,
        markers: canonicalizeChunkMarkers(next),
      ),
    );
  }

  void _requireTarget(ChunkV2CompositionTarget expected, Object? candidate) {
    if (target != expected) {
      throw StateError(
        'Operation targets ${target.name}, not ${expected.name}.',
      );
    }
    if (kind != ChunkV2CompositionOperationKind.delete && candidate == null) {
      throw ArgumentError.notNull('candidate');
    }
    if (kind == ChunkV2CompositionOperationKind.delete && candidate != null) {
      throw ArgumentError.value(candidate, 'candidate', 'must be null');
    }
  }

  List<T> _apply<T>(List<T> current, T? candidate) {
    final next = List<T>.of(current);
    switch (kind) {
      case ChunkV2CompositionOperationKind.add:
        next.add(candidate as T);
        break;
      case ChunkV2CompositionOperationKind.replace:
        next[sourceIndex!] = candidate as T;
        break;
      case ChunkV2CompositionOperationKind.delete:
        next.removeAt(sourceIndex!);
        break;
    }
    return next;
  }

  ChunkV2CompositionCommit? _build(ChunkV2CompositionSnapshot after) {
    if (chunkCompositionSnapshotsEqual(before, after)) return null;
    return ChunkV2CompositionCommit(
      expectedChunkKey: expectedChunkKey,
      expectedRevision: expectedRevision,
      before: before,
      after: after,
    );
  }
}

/// Returns the accepted prefab's derived key only for one exact record match.
String? uniqueChunkPrefabSelectionKey(
  Iterable<PlacedPrefabDef> current,
  PlacedPrefabDef accepted,
) {
  final matches = buildChunkPlacedPrefabSelections(
    current,
  ).where((selection) => chunkPrefabsEqual(selection.prefab, accepted));
  return matches.length == 1 ? matches.single.selectionKey : null;
}

/// Returns the accepted marker's derived key only for one exact record match.
String? uniqueChunkMarkerSelectionKey(
  Iterable<PlacedMarkerDef> current,
  PlacedMarkerDef accepted,
) {
  final matches = buildChunkPlacedMarkerSelections(
    current,
  ).where((selection) => chunkMarkersEqual(selection.marker, accepted));
  return matches.length == 1 ? matches.single.selectionKey : null;
}

/// Resolves one prefab selection by its exact current projection key.
ChunkPlacedPrefabSelection? resolveChunkPrefabSelection(
  Iterable<PlacedPrefabDef> current,
  String selectionKey,
) {
  final matches = buildChunkPlacedPrefabSelections(
    current,
  ).where((selection) => selection.selectionKey == selectionKey);
  return matches.length == 1 ? matches.single : null;
}

/// Resolves one marker selection by its exact current projection key.
ChunkPlacedMarkerSelection? resolveChunkMarkerSelection(
  Iterable<PlacedMarkerDef> current,
  String selectionKey,
) {
  final matches = buildChunkPlacedMarkerSelections(
    current,
  ).where((selection) => selection.selectionKey == selectionKey);
  return matches.length == 1 ? matches.single : null;
}
