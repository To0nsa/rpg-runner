import '../domain/authoring_types.dart';
import 'chunk_domain_models.dart';

List<ValidationIssue> validateChunkDocument(ChunkDocument document) {
  final issues = <ValidationIssue>[
    ...document.loadIssues,
    ...document.operationIssues,
  ];
  final sortedChunks = List<LevelChunkDef>.from(document.chunks)
    ..sort(_compareChunksForValidation);

  if (document.availableLevelIds.isEmpty) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_level_options',
        message:
            'No active level options are available. Export is blocked until '
            'a level source can be resolved.',
      ),
    );
  }

  final activeLevelId = document.activeLevelId;
  if (activeLevelId == null || activeLevelId.isEmpty) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'missing_active_level',
        message: 'Active level context is missing.',
      ),
    );
  }

  final chunkKeySet = <String>{};
  final chunkIdSet = <String>{};
  final filenameLowerSet = <String>{};
  final knownPrefabKeys = document.prefabData.prefabs
      .map((prefab) => prefab.prefabKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  final knownPrefabIds = document.prefabData.prefabs
      .map((prefab) => prefab.id)
      .where((id) => id.isNotEmpty)
      .toSet();
  final knownLevelIds = document.availableLevelIds.toSet();
  final assemblyGroupOptionsByLevelId = document.assemblyGroupOptionsByLevelId;
  const tolerance = 1e-9;
  const knownEnemyMarkerIds = <String>{
    'unocoDemon',
    'grojib',
    'hashash',
    'derf',
  };
  const knownMarkerPlacements = <String>{
    markerPlacementGround,
    markerPlacementHighestSurfaceAtX,
    markerPlacementObstacleTop,
  };

  for (final chunk in sortedChunks) {
    final sourcePath = document.baselineByChunkKey[chunk.chunkKey]?.sourcePath;

    if (chunk.schemaVersion <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_schema_version',
          message: 'Chunk ${chunk.id} has invalid schemaVersion.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.chunkKey.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_chunk_key',
          message: 'Chunk ${chunk.id} is missing chunkKey.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!chunk.chunkIdentity.isValid) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'malformed_chunk_key',
          message:
              'Chunk ${chunk.id} has malformed chunkKey ${chunk.chunkKey}. '
              'Only lowercase letters, digits, and underscore are allowed.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!chunkKeySet.add(chunk.chunkKey)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_chunk_key',
          message: 'Duplicate chunkKey: ${chunk.chunkKey}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.id.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_chunk_id',
          message: 'Chunk with key ${chunk.chunkKey} is missing id.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!chunkIdSet.add(chunk.id)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_chunk_id',
          message: 'Duplicate chunk id: ${chunk.id}.',
          sourcePath: sourcePath,
        ),
      );
    }

    final fileNameLower = '${chunk.chunkKey.toLowerCase()}.json';
    if (!filenameLowerSet.add(fileNameLower)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'filename_collision_case_insensitive',
          message:
              'Case-insensitive filename collision for chunkKey ${chunk.chunkKey}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.revision <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_revision',
          message: 'Chunk ${chunk.id} has invalid revision ${chunk.revision}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.levelId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_level_id',
          message: 'Chunk ${chunk.id} is missing levelId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!knownLevelIds.contains(chunk.levelId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'unknown_level_id',
          message:
              'Chunk ${chunk.id} has unknown levelId ${chunk.levelId} for current level options.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (activeLevelId != null &&
        activeLevelId.isNotEmpty &&
        chunk.levelId.isNotEmpty &&
        chunk.levelId != activeLevelId) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'active_level_mismatch',
          message:
              'Chunk ${chunk.id} levelId ${chunk.levelId} does not match active level $activeLevelId.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.assemblyGroupId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_assembly_group_id',
          message: 'Chunk ${chunk.id} is missing assemblyGroupId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!stableChunkAssemblyGroupPattern.hasMatch(
      chunk.assemblyGroupId,
    )) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_assembly_group_id',
          message:
              'Chunk ${chunk.id} assemblyGroupId "${chunk.assemblyGroupId}" '
              'must match ${stableChunkAssemblyGroupPattern.pattern}.',
          sourcePath: sourcePath,
        ),
      );
    } else {
      final allowedAssemblyGroupIds =
          assemblyGroupOptionsByLevelId[chunk.levelId] ??
          const <String>[defaultChunkAssemblyGroupId];
      if (!allowedAssemblyGroupIds.contains(chunk.assemblyGroupId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'unknown_assembly_group_id',
            message:
                'Chunk ${chunk.id} assemblyGroupId "${chunk.assemblyGroupId}" '
                'is not allowed for levelId "${chunk.levelId}".',
            sourcePath: sourcePath,
          ),
        );
      }
    }

    if (chunk.tileSize <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_tile_size',
          message: 'Chunk ${chunk.id} has invalid tileSize ${chunk.tileSize}.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (chunk.width <= 0 || chunk.height <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_chunk_dimensions',
          message:
              'Chunk ${chunk.id} has invalid dimensions ${chunk.width}x${chunk.height}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if ((chunk.width - document.runtimeChunkWidth).abs() > tolerance) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_width_mismatch',
          message:
              'Chunk ${chunk.id} width ${chunk.width} must match runtime chunkWidth '
              '${document.runtimeChunkWidth.toStringAsFixed(1)}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.height != document.lockedChunkHeight) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_height_mismatch',
          message:
              'Chunk ${chunk.id} height ${chunk.height} must match locked chunk '
              'height ${document.lockedChunkHeight}.',
          sourcePath: sourcePath,
        ),
      );
    }

    final runtimeTileSize = document.runtimeGridSnap.round();
    if (runtimeTileSize <= 0 || chunk.tileSize != runtimeTileSize) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_tile_size_mismatch',
          message:
              'Chunk ${chunk.id} tileSize ${chunk.tileSize} must equal '
              'runtime grid tileSize $runtimeTileSize.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (!_isKnownDifficulty(chunk.difficulty)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_difficulty',
          message:
              'Chunk ${chunk.id} has unknown difficulty ${chunk.difficulty}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (!_isKnownStatus(chunk.status)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_status',
          message: 'Chunk ${chunk.id} has unknown status ${chunk.status}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (!_isKnownGroundProfileKind(chunk.groundProfile.kind)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_ground_profile_kind',
          message:
              'Chunk ${chunk.id} has unsupported groundProfile.kind ${chunk.groundProfile.kind}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.groundProfile.topY != document.runtimeGroundTopY) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'ground_profile_top_y_mismatch',
          message:
              'Chunk ${chunk.id} groundProfile.topY ${chunk.groundProfile.topY} '
              'must match runtime groundTopY ${document.runtimeGroundTopY}.',
          sourcePath: sourcePath,
        ),
      );
    }

    final gapIdSet = <String>{};
    final sortedPrefabs = List<PlacedPrefabDef>.from(chunk.prefabs)
      ..sort(comparePlacedPrefabsDeterministic);

    for (final prefab in sortedPrefabs) {
      if (prefab.prefabId.isEmpty && prefab.prefabKey.isEmpty) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'missing_prefab_ref',
            message:
                'Chunk ${chunk.id} contains prefab placement with no prefabId/prefabKey.',
            sourcePath: sourcePath,
          ),
        );
      }

      final matchesKnownKey = prefab.prefabKey.isNotEmpty
          ? knownPrefabKeys.contains(prefab.prefabKey)
          : false;
      final matchesKnownId = prefab.prefabId.isNotEmpty
          ? knownPrefabIds.contains(prefab.prefabId)
          : false;
      if (!matchesKnownKey && !matchesKnownId) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'unknown_prefab_ref',
            message:
                'Chunk ${chunk.id} references unknown prefab "${prefab.resolvedPrefabRef}".',
            sourcePath: sourcePath,
          ),
        );
      }

      if (prefab.snapToGrid &&
          (!_isSnapped(prefab.x.toDouble(), document.runtimeGridSnap) ||
              !_isSnapped(prefab.y.toDouble(), document.runtimeGridSnap))) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'prefab_snap_violation',
            message:
                'Chunk ${chunk.id} prefab placement '
                '"${prefab.resolvedPrefabRef}" is not snapped to runtime grid.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!isPrefabPlacementScaleInRange(prefab.scale)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'prefab_scale_out_of_range',
            message:
                'Chunk ${chunk.id} prefab placement '
                '"${prefab.resolvedPrefabRef}" scale ${prefab.scale} must be '
                'between $minPrefabPlacementScale and $maxPrefabPlacementScale.',
            sourcePath: sourcePath,
          ),
        );
      } else if (!isPrefabPlacementScaleStepAligned(prefab.scale)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'prefab_scale_step_violation',
            message:
                'Chunk ${chunk.id} prefab placement '
                '"${prefab.resolvedPrefabRef}" scale ${prefab.scale} must use '
                'step $prefabPlacementScaleStep.',
            sourcePath: sourcePath,
          ),
        );
      }
    }

    final sortedMarkers = List<PlacedMarkerDef>.from(chunk.markers)
      ..sort(comparePlacedMarkersDeterministic);

    for (final marker in sortedMarkers) {
      if (marker.markerId.isEmpty) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'missing_marker_id',
            message: 'Chunk ${chunk.id} has marker with empty markerId.',
            sourcePath: sourcePath,
          ),
        );
      } else if (!knownEnemyMarkerIds.contains(marker.markerId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'unknown_enemy_marker_id',
            message:
                'Chunk ${chunk.id} marker references unknown enemy "${marker.markerId}".',
            sourcePath: sourcePath,
          ),
        );
      }

      if (marker.x < 0 || marker.x > chunk.width) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_x_out_of_bounds',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} x is outside chunk width.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (marker.y < 0 || marker.y > chunk.height) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_y_out_of_bounds',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} y is outside chunk height.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!_isSnapped(marker.x.toDouble(), document.runtimeGridSnap) ||
          !_isSnapped(marker.y.toDouble(), document.runtimeGridSnap)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_snap_violation',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} is not snapped to runtime grid.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (marker.chancePercent < 0 || marker.chancePercent > 100) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_chance_out_of_range',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} chancePercent must be between 0 and 100.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (marker.salt < 0) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_salt_negative',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} salt must be >= 0.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!knownMarkerPlacements.contains(marker.placement)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'marker_invalid_placement',
            message:
                'Chunk ${chunk.id} marker ${marker.markerId} has unsupported placement ${marker.placement}.',
            sourcePath: sourcePath,
          ),
        );
      }
    }

    final sortedGaps = List<GroundGapDef>.from(chunk.groundGaps)
      ..sort(_compareGapsForValidation);
    var previousGapEnd = -1;

    for (final gap in sortedGaps) {
      if (gap.gapId.isEmpty) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'missing_gap_id',
            message: 'Chunk ${chunk.id} has ground gap with empty gapId.',
            sourcePath: sourcePath,
          ),
        );
      } else if (!gapIdSet.add(gap.gapId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_gap_id',
            message: 'Chunk ${chunk.id} has duplicate gapId ${gap.gapId}.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!_isKnownGroundGapType(gap.type)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_gap_type',
            message:
                'Chunk ${chunk.id} gap ${gap.gapId} has unsupported type ${gap.type}.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (gap.width <= 0) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_gap_width',
            message:
                'Chunk ${chunk.id} gap ${gap.gapId} width must be positive.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (gap.x < 0 || gap.x + gap.width > chunk.width) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'gap_out_of_bounds',
            message:
                'Chunk ${chunk.id} gap ${gap.gapId} is outside chunk width.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (!_isSnapped(gap.x.toDouble(), document.runtimeGridSnap) ||
          !_isSnapped(gap.width.toDouble(), document.runtimeGridSnap)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'gap_snap_violation',
            message:
                'Chunk ${chunk.id} gap ${gap.gapId} is not snapped to runtime grid.',
            sourcePath: sourcePath,
          ),
        );
      }

      if (gap.x < previousGapEnd) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'overlapping_gaps',
            message: 'Chunk ${chunk.id} has overlapping ground gaps.',
            sourcePath: sourcePath,
          ),
        );
      }

      final end = gap.x + gap.width;
      if (end > previousGapEnd) {
        previousGapEnd = end;
      }
    }
  }

  issues.sort(_compareIssues);
  return issues;
}

bool _isKnownDifficulty(String value) {
  return value == chunkDifficultyEarly ||
      value == chunkDifficultyEasy ||
      value == chunkDifficultyNormal ||
      value == chunkDifficultyHard;
}

bool _isKnownStatus(String value) {
  return value == chunkStatusActive || value == chunkStatusDeprecated;
}

bool _isKnownGroundProfileKind(String value) {
  return value == groundProfileKindFlat;
}

bool _isKnownGroundGapType(String value) {
  return value == groundGapTypePit;
}

bool _isSnapped(double value, double gridSnap) {
  if (gridSnap <= 0 || !value.isFinite) {
    return false;
  }
  final snapped = (value / gridSnap).roundToDouble() * gridSnap;
  return (value - snapped).abs() < 1e-9;
}

int _compareIssues(ValidationIssue a, ValidationIssue b) {
  final sourceCompare = (a.sourcePath ?? '').compareTo(b.sourcePath ?? '');
  if (sourceCompare != 0) {
    return sourceCompare;
  }
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) {
    return codeCompare;
  }
  return a.message.compareTo(b.message);
}

int _compareChunksForValidation(LevelChunkDef a, LevelChunkDef b) {
  final levelCompare = a.levelId.compareTo(b.levelId);
  if (levelCompare != 0) {
    return levelCompare;
  }
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  return a.chunkKey.compareTo(b.chunkKey);
}

int _compareGapsForValidation(GroundGapDef a, GroundGapDef b) {
  final xCompare = a.x.compareTo(b.x);
  if (xCompare != 0) {
    return xCompare;
  }
  final widthCompare = a.width.compareTo(b.width);
  if (widthCompare != 0) {
    return widthCompare;
  }
  return a.gapId.compareTo(b.gapId);
}
