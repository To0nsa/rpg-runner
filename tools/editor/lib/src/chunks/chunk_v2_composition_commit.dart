import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';
import '../domain/strict_authoring_json.dart';
import '../domain/strict_authoring_metadata_codec.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_models.dart';
import 'chunk_v2_validation.dart';

/// Immutable composition fields retained by one chunk-v2 owner.
///
/// Identity, revision, metadata, dimensions, and collision geometry are
/// intentionally absent and cannot be changed through this contract.
@immutable
final class ChunkV2CompositionSnapshot {
  ChunkV2CompositionSnapshot({
    required Iterable<TileLayerDef> tileLayers,
    required Iterable<PlacedPrefabDef> prefabs,
    required Iterable<PlacedMarkerDef> markers,
  }) : tileLayers = List<TileLayerDef>.unmodifiable(tileLayers),
       prefabs = List<PlacedPrefabDef>.unmodifiable(prefabs),
       markers = List<PlacedMarkerDef>.unmodifiable(markers);

  factory ChunkV2CompositionSnapshot.fromChunk(ChunkV2FileData chunk) =>
      ChunkV2CompositionSnapshot(
        tileLayers: chunk.tileLayers,
        prefabs: chunk.prefabs,
        markers: chunk.markers,
      );

  final List<TileLayerDef> tileLayers;
  final List<PlacedPrefabDef> prefabs;
  final List<PlacedMarkerDef> markers;
}

/// One optimistic-concurrency composition edit for an existing chunk owner.
@immutable
final class ChunkV2CompositionCommit {
  const ChunkV2CompositionCommit({required this.before, required this.after});

  final ChunkV2CompositionSnapshot before;
  final ChunkV2CompositionSnapshot after;
}

/// Result of applying one typed chunk-v2 composition commit.
final class ChunkV2CompositionCommitResult {
  ChunkV2CompositionCommitResult({
    required this.chunk,
    required this.accepted,
    required this.changed,
    Iterable<ValidationIssue> issues = const <ValidationIssue>[],
  }) : issues = List<ValidationIssue>.unmodifiable(issues);

  final ChunkV2FileData chunk;
  final bool accepted;
  final bool changed;
  final List<ValidationIssue> issues;
}

/// Fail-closed composition and revision policy for an existing chunk owner.
///
/// Candidate lists must already satisfy the strict source codec contract. The
/// replacement is then run through complete chunk-v2 validation so placement
/// expansion, marker contracts, seams, bounds, overlap, and capacities remain
/// authoritative outside route widgets.
final class ChunkV2CompositionCommitPolicy {
  const ChunkV2CompositionCommitPolicy();

  ChunkV2CompositionCommitResult apply({
    required ChunkV2Document document,
    required int chunkIndex,
    required ChunkV2CompositionCommit commit,
  }) {
    if (chunkIndex < 0 || chunkIndex >= document.chunks.length) {
      throw RangeError.index(chunkIndex, document.chunks, 'chunkIndex');
    }
    final chunk = document.chunks[chunkIndex];
    final current = ChunkV2CompositionSnapshot.fromChunk(chunk);
    final sourcePath =
        document.sourcePathByChunkKey[chunk.chunkKey] ?? chunk.chunkKey;
    if (!_snapshotsEqual(current, commit.before)) {
      return _rejected(
        chunk,
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_v2_composition_commit_stale',
          message:
              'Chunk ${chunk.chunkKey} changed after this composition edit '
              'began; reload its current source before committing.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (_snapshotsEqual(commit.before, commit.after)) {
      return ChunkV2CompositionCommitResult(
        chunk: chunk,
        accepted: true,
        changed: false,
      );
    }

    final structuralIssue = _strictStructureIssue(
      chunk: chunk,
      snapshot: commit.after,
      sourcePath: sourcePath,
    );
    if (structuralIssue != null) return _rejected(chunk, structuralIssue);

    final nextChunk = chunk.copyWith(
      revision: chunk.revision + 1,
      tileLayers: commit.after.tileLayers,
      prefabs: commit.after.prefabs,
      markers: commit.after.markers,
    );
    final chunks = document.chunks.toList(growable: false);
    chunks[chunkIndex] = nextChunk;
    final issues = validateChunkV2Document(document.copyWith(chunks: chunks));
    if (issues.any((issue) => issue.severity == ValidationSeverity.error)) {
      return ChunkV2CompositionCommitResult(
        chunk: chunk,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }
    return ChunkV2CompositionCommitResult(
      chunk: nextChunk,
      accepted: true,
      changed: true,
      issues: issues,
    );
  }
}

ValidationIssue? _strictStructureIssue({
  required ChunkV2FileData chunk,
  required ChunkV2CompositionSnapshot snapshot,
  required String sourcePath,
}) {
  try {
    StrictAuthoringJson.requireStrictStringOrder(
      snapshot.tileLayers.map((layer) => layer.id),
      sourcePath: '$sourcePath.tileLayers',
    );
    for (var index = 0; index < snapshot.tileLayers.length; index += 1) {
      final current = snapshot.tileLayers[index];
      final decoded = PolygonAuthoringMetadataCodec.decodeTileLayer(
        current.toJson(),
        sourcePath: '$sourcePath.tileLayers[$index]',
      );
      if (!_tileLayersEqual(current, decoded)) {
        throw FormatException(
          '$sourcePath.tileLayers[$index] is not canonical.',
        );
      }
    }

    StrictAuthoringJson.requireComparatorOrder(
      snapshot.prefabs,
      comparePlacedPrefabsDeterministic,
      sourcePath: '$sourcePath.prefabs',
    );
    for (var index = 0; index < snapshot.prefabs.length; index += 1) {
      final current = snapshot.prefabs[index];
      final decoded = PolygonAuthoringMetadataCodec.decodePlacement(
        current.toJson(),
        sourcePath: '$sourcePath.prefabs[$index]',
      );
      if (!_prefabsEqual(current, decoded)) {
        throw FormatException('$sourcePath.prefabs[$index] is not canonical.');
      }
    }

    StrictAuthoringJson.requireComparatorOrder(
      snapshot.markers,
      comparePlacedMarkersDeterministic,
      sourcePath: '$sourcePath.markers',
    );
    for (var index = 0; index < snapshot.markers.length; index += 1) {
      final current = snapshot.markers[index];
      final decoded = PolygonAuthoringMetadataCodec.decodeMarker(
        current.toJson(),
        sourcePath: '$sourcePath.markers[$index]',
      );
      if (!_markersEqual(current, decoded)) {
        throw FormatException('$sourcePath.markers[$index] is not canonical.');
      }
    }
  } on FormatException catch (error) {
    return ValidationIssue(
      severity: ValidationSeverity.error,
      code: 'chunk_v2_composition_noncanonical',
      message: 'Chunk ${chunk.chunkKey} composition is invalid: $error',
      sourcePath: sourcePath,
    );
  }
  return null;
}

ChunkV2CompositionCommitResult _rejected(
  ChunkV2FileData chunk,
  ValidationIssue issue,
) => ChunkV2CompositionCommitResult(
  chunk: chunk,
  accepted: false,
  changed: false,
  issues: <ValidationIssue>[issue],
);

bool _snapshotsEqual(
  ChunkV2CompositionSnapshot left,
  ChunkV2CompositionSnapshot right,
) =>
    _listsEqual(left.tileLayers, right.tileLayers, _tileLayersEqual) &&
    _listsEqual(left.prefabs, right.prefabs, _prefabsEqual) &&
    _listsEqual(left.markers, right.markers, _markersEqual);

bool _listsEqual<T>(
  List<T> left,
  List<T> right,
  bool Function(T left, T right) equals,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (!equals(left[index], right[index])) return false;
  }
  return true;
}

bool _tileLayersEqual(TileLayerDef left, TileLayerDef right) =>
    left.id == right.id &&
    left.kind == right.kind &&
    left.visible == right.visible;

bool _prefabsEqual(PlacedPrefabDef left, PlacedPrefabDef right) =>
    left.prefabId == right.prefabId &&
    left.prefabKey == right.prefabKey &&
    left.x == right.x &&
    left.y == right.y &&
    left.zIndex == right.zIndex &&
    left.snapToGrid == right.snapToGrid &&
    left.scale == right.scale &&
    left.flipX == right.flipX &&
    left.flipY == right.flipY;

bool _markersEqual(PlacedMarkerDef left, PlacedMarkerDef right) =>
    left.markerId == right.markerId &&
    left.x == right.x &&
    left.y == right.y &&
    left.chancePercent == right.chancePercent &&
    left.salt == right.salt &&
    left.placement == right.placement;
