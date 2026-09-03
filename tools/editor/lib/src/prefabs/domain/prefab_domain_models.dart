import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../../chunks/chunk_v2_file_data.dart';
import '../../domain/authoring_types.dart';
import '../models/models.dart';

/// Prefab-domain plugin document/scene shapes.
///
/// This file is the seam between generic authoring contracts and prefab-specific
/// data carried through session/plugin/page flows.

/// Resolved whole-pixel visual bounds for one prefab-v3 collision owner.
@immutable
class PrefabV3VisualBounds {
  const PrefabV3VisualBounds({required this.widthPx, required this.heightPx});

  final int widthPx;
  final int heightPx;
}

/// Read-only chunk-placement impact for one stable prefab key.
@immutable
final class PrefabV3DownstreamImpact {
  PrefabV3DownstreamImpact({
    required this.prefabKey,
    required Iterable<String> referencingChunkKeys,
    required this.placementCount,
  }) : referencingChunkKeys = List<String>.unmodifiable(
         referencingChunkKeys.toSet().toList()..sort(),
       );

  final String prefabKey;
  final List<String> referencingChunkKeys;
  final int placementCount;
}

/// Read-only current Chunk source captured for transformed Prefab review.
@immutable
final class PrefabV3DownstreamChunk {
  PrefabV3DownstreamChunk({
    required this.data,
    required this.sourcePath,
    required this.baselineContents,
    Iterable<String> baselineCollisionErrorIdentities = const <String>[],
  }) : baselineCollisionErrorIdentities = List<String>.unmodifiable(
         baselineCollisionErrorIdentities,
       );

  final ChunkV2FileData data;
  final String sourcePath;
  final String baselineContents;
  final List<String> baselineCollisionErrorIdentities;
}

/// The normal loader selects this only for strict v3 source; legacy or missing
/// source becomes a migration-required document with no editable prefab data.
/// Export can update already-current source but cannot migrate legacy files.
/// This is the normal Prefab-v3 authoring document.
@immutable
class PrefabV3Document extends AuthoringDocument {
  PrefabV3Document({
    required this.data,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    required this.prefabBaselineContents,
    required this.tileBaselineContents,
    Iterable<String> changedPrefabKeys = const <String>[],
    Iterable<PrefabV3DownstreamImpact> downstreamImpacts =
        const <PrefabV3DownstreamImpact>[],
    Iterable<PrefabV3DownstreamChunk> downstreamChunks =
        const <PrefabV3DownstreamChunk>[],
  }) : visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       changedPrefabKeys = List<String>.unmodifiable(
         changedPrefabKeys.toSet().toList()..sort(),
       ),
       downstreamImpacts = List<PrefabV3DownstreamImpact>.unmodifiable(
         List<PrefabV3DownstreamImpact>.of(downstreamImpacts)
           ..sort((left, right) => left.prefabKey.compareTo(right.prefabKey)),
       ),
       downstreamChunks = List<PrefabV3DownstreamChunk>.unmodifiable(
         List<PrefabV3DownstreamChunk>.of(downstreamChunks)..sort(
           (left, right) => left.data.chunkKey.compareTo(right.data.chunkKey),
         ),
       );

  final PrefabV3FileData data;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final String? prefabBaselineContents;
  final String? tileBaselineContents;
  final List<String> changedPrefabKeys;
  final List<PrefabV3DownstreamImpact> downstreamImpacts;
  final List<PrefabV3DownstreamChunk> downstreamChunks;

  PrefabV3Document copyWith({
    PrefabV3FileData? data,
    PrefabTileFileData? tileData,
    Map<String, PrefabV3VisualBounds>? visualBoundsByPrefabKey,
    List<String>? atlasImagePaths,
    Map<String, Size>? atlasImageSizes,
    String? prefabBaselineContents,
    bool keepPrefabBaselineContents = true,
    String? tileBaselineContents,
    bool keepTileBaselineContents = true,
    Iterable<String>? changedPrefabKeys,
    Iterable<PrefabV3DownstreamImpact>? downstreamImpacts,
    Iterable<PrefabV3DownstreamChunk>? downstreamChunks,
  }) => PrefabV3Document(
    data: data ?? this.data,
    tileData: tileData ?? this.tileData,
    visualBoundsByPrefabKey:
        visualBoundsByPrefabKey ?? this.visualBoundsByPrefabKey,
    atlasImagePaths: atlasImagePaths ?? this.atlasImagePaths,
    atlasImageSizes: atlasImageSizes ?? this.atlasImageSizes,
    prefabBaselineContents: keepPrefabBaselineContents
        ? (prefabBaselineContents ?? this.prefabBaselineContents)
        : null,
    tileBaselineContents: keepTileBaselineContents
        ? (tileBaselineContents ?? this.tileBaselineContents)
        : null,
    changedPrefabKeys: changedPrefabKeys ?? this.changedPrefabKeys,
    downstreamImpacts: downstreamImpacts ?? this.downstreamImpacts,
    downstreamChunks: downstreamChunks ?? this.downstreamChunks,
  );
}

/// Read-only scene projection for the current prefab-v3 plugin document.
@immutable
class PrefabV3Scene extends EditableScene {
  PrefabV3Scene({
    required this.data,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    Iterable<PrefabV3DownstreamImpact> downstreamImpacts =
        const <PrefabV3DownstreamImpact>[],
  }) : visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       downstreamImpacts = List<PrefabV3DownstreamImpact>.unmodifiable(
         List<PrefabV3DownstreamImpact>.of(downstreamImpacts)
           ..sort((left, right) => left.prefabKey.compareTo(right.prefabKey)),
       );

  final PrefabV3FileData data;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final List<PrefabV3DownstreamImpact> downstreamImpacts;
}
