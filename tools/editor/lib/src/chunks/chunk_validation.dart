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
  final knownLevelIds = document.availableLevelIds.toSet();
  const tolerance = 1e-9;

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

    if (!_isSnapped(chunk.height.toDouble(), document.runtimeGridSnap) ||
        !_isSnapped(chunk.tileSize.toDouble(), document.runtimeGridSnap)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'chunk_grid_snap_violation',
          message:
              'Chunk ${chunk.id} dimensions/tileSize must be snapped to runtime grid '
              '${document.runtimeGridSnap}.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (chunk.entrySocket.isEmpty || chunk.exitSocket.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_socket',
          message: 'Chunk ${chunk.id} must define entrySocket and exitSocket.',
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

    if (!_isSnapped(
      chunk.groundProfile.topY.toDouble(),
      document.runtimeGridSnap,
    )) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'ground_profile_snap_violation',
          message:
              'Chunk ${chunk.id} groundProfile.topY must be snapped to runtime grid.',
          sourcePath: sourcePath,
        ),
      );
    }

    final gapIdSet = <String>{};
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
  return value == chunkDifficultyEasy ||
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
