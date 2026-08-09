import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../../domain/authoring_types.dart';
import '../models/models.dart';

/// Prefab-domain plugin document/scene shapes.
///
/// This file is the seam between generic authoring contracts and prefab-specific
/// data carried through session/plugin/page flows.

/// Plugin-owned immutable snapshot for the prefab authoring domain.
///
/// [data] is the authoritative editable model. Atlas metadata is kept on the
/// document so validation and scene projection can resolve source image bounds
/// without re-scanning disk on each operation.
@immutable
class PrefabDocument extends AuthoringDocument {
  PrefabDocument({
    required this.data,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    List<String> migrationHints = const <String>[],
    this.prefabBaselineContents,
    this.tileBaselineContents,
  }) : atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       migrationHints = List<String>.unmodifiable(migrationHints);

  final PrefabData data;

  /// Discovered atlas image paths under the prefab level asset directory.
  final List<String> atlasImagePaths;

  /// Pixel dimensions keyed by atlas image path.
  final Map<String, Size> atlasImageSizes;

  /// Load/migration notices that should remain attached to this document until
  /// the next repository reload.
  final List<String> migrationHints;

  /// Baseline prefab_defs.json content loaded from repository, if present.
  final String? prefabBaselineContents;

  /// Baseline tile_defs.json content loaded from repository, if present.
  final String? tileBaselineContents;

  /// Returns a new immutable snapshot with selected fields replaced.
  PrefabDocument copyWith({
    PrefabData? data,
    List<String>? atlasImagePaths,
    Map<String, Size>? atlasImageSizes,
    List<String>? migrationHints,
    String? prefabBaselineContents,
    bool keepPrefabBaselineContents = true,
    String? tileBaselineContents,
    bool keepTileBaselineContents = true,
  }) {
    return PrefabDocument(
      data: data ?? this.data,
      atlasImagePaths: atlasImagePaths ?? this.atlasImagePaths,
      atlasImageSizes: atlasImageSizes ?? this.atlasImageSizes,
      migrationHints: migrationHints ?? this.migrationHints,
      prefabBaselineContents: keepPrefabBaselineContents
          ? (prefabBaselineContents ?? this.prefabBaselineContents)
          : null,
      tileBaselineContents: keepTileBaselineContents
          ? (tileBaselineContents ?? this.tileBaselineContents)
          : null,
    );
  }
}

/// UI-facing scene projection for prefab editing routes.
///
/// Carries only the data needed by prefab creator pages; export baseline and
/// repository write concerns stay in plugin/store layers.
@immutable
class PrefabScene extends EditableScene {
  PrefabScene({
    required this.data,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    List<String> migrationHints = const <String>[],
  }) : atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       migrationHints = List<String>.unmodifiable(migrationHints);

  final PrefabData data;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final List<String> migrationHints;
}

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

/// Temporary read-only plugin document used to stage prefab-v3 commands.
///
/// The normal loader never selects this type while repository source is v2,
/// and export rejects changed instances. At the single schema cutover it
/// replaces [PrefabDocument] rather than remaining as a parallel authority.
@immutable
class PrefabV3StagingDocument extends AuthoringDocument {
  PrefabV3StagingDocument({
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

  PrefabV3StagingDocument copyWith({
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
  }) => PrefabV3StagingDocument(
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
  );
}

/// Read-only scene projection for the staged prefab-v3 plugin document.
@immutable
class PrefabV3StagingScene extends EditableScene {
  PrefabV3StagingScene({
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
