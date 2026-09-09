import '../domain/authoring_types.dart';
import '../parallax/parallax_validation.dart';
import 'level_domain_models.dart';

List<ValidationIssue> validateLevelDocument(LevelDefsDocument document) {
  final issues = <ValidationIssue>[
    ...document.loadIssues,
    ...document.operationIssues,
    if (document.parallaxDocument case final parallaxDocument?)
      ...validateParallaxDocument(parallaxDocument),
  ];
  final sourcePath = document.baseline?.sourcePath ?? levelDefsSourcePath;
  final canonicalLevels = List<LevelDef>.from(document.levels)
    ..sort(compareLevelDefsCanonical);

  if (!_levelOrderingMatches(document.levels)) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'non_canonical_level_order',
        message: 'Levels must be ordered deterministically by levelId.',
        sourcePath: sourcePath,
      ),
    );
  }

  if (document.levels.isNotEmpty) {
    final activeLevelId = document.activeLevelId;
    if (activeLevelId == null || activeLevelId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_active_level',
          message: 'Active level context is missing.',
          sourcePath: sourcePath,
        ),
      );
    } else if (findLevelDefById(document.levels, activeLevelId) == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'unknown_level_id',
          message: 'Active level "$activeLevelId" is not authored.',
          sourcePath: sourcePath,
          ownerKey: activeLevelId,
        ),
      );
    }
  }

  final seenLevelIds = <String>{};
  final seenEnumOrdinals = <int>{};
  final persistedById = <String, LevelDef>{
    for (final level in document.baselineLevels) level.levelId: level,
  };
  var highestPersistedOrdinal = 0;
  for (final persisted in persistedById.values) {
    if (persisted.enumOrdinal > highestPersistedOrdinal) {
      highestPersistedOrdinal = persisted.enumOrdinal;
    }
    if (findLevelDefById(document.levels, persisted.levelId) == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'persisted_level_removed',
          message:
              'Persisted Level "${persisted.levelId}" cannot be removed. Exclude or deprecate it instead.',
          sourcePath: sourcePath,
          ownerKey: persisted.levelId,
        ),
      );
    }
  }
  for (final level in canonicalLevels) {
    final persisted = persistedById[level.levelId];
    if (persisted != null && persisted.enumOrdinal != level.enumOrdinal) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'persisted_level_ordinal_changed',
          message:
              'Persisted Level "${level.levelId}" must retain ordinal ${persisted.enumOrdinal}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (persisted == null &&
        level.enumOrdinal <= highestPersistedOrdinal) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'new_level_ordinal_not_appended',
          message:
              'New Level "${level.levelId}" must use an ordinal above $highestPersistedOrdinal.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }
    if (level.levelId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_level_id',
          message: 'A level is missing levelId.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(level.levelId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_level_id',
          message:
              'levelId "${level.levelId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!seenLevelIds.add(level.levelId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_level_id',
          message: 'Duplicate levelId "${level.levelId}".',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (level.enumOrdinal <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_enum_ordinal',
          message:
              'Level "${level.levelId}" enumOrdinal must be a positive integer.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!seenEnumOrdinals.add(level.enumOrdinal)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_enum_ordinal',
          message: 'Duplicate enumOrdinal ${level.enumOrdinal}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (level.revision <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_revision',
          message:
              'Level "${level.levelId}" has invalid revision ${level.revision}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (level.displayName.trim().isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_display_name',
          message: 'Level "${level.levelId}" must have a displayName.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (level.visualThemeId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_theme_id',
          message: 'Level "${level.levelId}" must have a visualThemeId.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(level.visualThemeId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_theme_id',
          message:
              'Level "${level.levelId}" visualThemeId "${level.visualThemeId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (document.parallaxThemeSourceAvailable &&
        !document.availableParallaxVisualThemeIds.contains(
          level.visualThemeId,
        )) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_parallax_theme',
          message:
              'Level "${level.levelId}" references unauthored visualThemeId '
              '"${level.visualThemeId}".',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    final seenChunkThemeGroups = <String>{};
    if (level.chunkThemeGroups.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_chunk_theme_groups',
          message:
              'Level "${level.levelId}" must define at least one chunkThemeGroups value.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }
    for (final chunkThemeGroupId in level.chunkThemeGroups) {
      if (chunkThemeGroupId.isEmpty) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_chunk_theme_group_id',
            message:
                'Level "${level.levelId}" has an empty chunkThemeGroups entry.',
            sourcePath: sourcePath,
            ownerKey: level.levelId,
          ),
        );
        continue;
      }
      if (!stableLevelIdentifierPattern.hasMatch(chunkThemeGroupId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_chunk_theme_group_id',
            message:
                'Level "${level.levelId}" chunkThemeGroups entry "$chunkThemeGroupId" must match '
                '${stableLevelIdentifierPattern.pattern}.',
            sourcePath: sourcePath,
            ownerKey: level.levelId,
          ),
        );
      }
      if (!seenChunkThemeGroups.add(chunkThemeGroupId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_chunk_theme_group_id',
            message:
                'Level "${level.levelId}" has duplicate chunkThemeGroups entry "$chunkThemeGroupId".',
            sourcePath: sourcePath,
            ownerKey: level.levelId,
          ),
        );
      }
    }
    if (!level.chunkThemeGroups.contains(defaultLevelChunkThemeGroupId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_default_chunk_theme_group',
          message:
              'Level "${level.levelId}" chunkThemeGroups must include '
              '"$defaultLevelChunkThemeGroupId".',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (!level.cameraCenterY.isFinite) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_camera_center_y',
          message: 'Level "${level.levelId}" cameraCenterY must be finite.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (level.cameraCenterY < 0 || level.cameraCenterY > 2000) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'unusual_camera_center_y',
          message:
              'Level "${level.levelId}" uses unusual cameraCenterY '
              '${formatCanonicalLevelNumber(level.cameraCenterY)}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (!level.groundTopY.isFinite) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_ground_top_y',
          message: 'Level "${level.levelId}" groundTopY must be finite.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (level.groundTopY < 0 || level.groundTopY > 2000) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'unusual_ground_top_y',
          message:
              'Level "${level.levelId}" uses unusual groundTopY '
              '${formatCanonicalLevelNumber(level.groundTopY)}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    _validateChunkWindow(
      issues,
      sourcePath: sourcePath,
      level: level,
      fieldLabel: 'earlyPatternChunks',
      value: level.earlyPatternChunks,
    );
    _validateChunkWindow(
      issues,
      sourcePath: sourcePath,
      level: level,
      fieldLabel: 'easyPatternChunks',
      value: level.easyPatternChunks,
    );
    _validateChunkWindow(
      issues,
      sourcePath: sourcePath,
      level: level,
      fieldLabel: 'normalPatternChunks',
      value: level.normalPatternChunks,
    );
    _validateChunkWindow(
      issues,
      sourcePath: sourcePath,
      level: level,
      fieldLabel: 'noEnemyChunks',
      value: level.noEnemyChunks,
    );

    if (level.status != levelStatusActive &&
        level.status != levelStatusDeprecated) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_status',
          message:
              'Level "${level.levelId}" status must be "$levelStatusActive" '
              'or "$levelStatusDeprecated".',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (level.status == levelStatusDeprecated &&
        document.activeLevelId == level.levelId) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'deprecated_active_level',
          message: 'Active level "${level.levelId}" is deprecated.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (document.chunkCountSourceAvailable &&
        (document.authoredChunkCountsByLevelId[level.levelId] ?? 0) == 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'level_has_no_chunks',
          message: 'Level "${level.levelId}" has no authored chunks.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    _validateAssembly(
      issues,
      document: document,
      sourcePath: sourcePath,
      level: level,
    );
  }

  issues.sort(_compareIssues);
  return issues;
}

void _validateAssembly(
  List<ValidationIssue> issues, {
  required LevelDefsDocument document,
  required String sourcePath,
  required LevelDef level,
}) {
  final assembly = level.assembly;
  if (assembly == null) {
    return;
  }

  final seenSegmentIds = <String>{};
  final levelChunkThemeGroups = level.chunkThemeGroups.toSet();
  final availableGroupCounts =
      document.authoredChunkAssemblyGroupCountsByLevelId[level.levelId] ??
      const <String, int>{};

  for (final segment in assembly.segments) {
    var groupIsResolvable = false;
    if (segment.segmentId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_segment_id',
          elementId: segment.segmentId,
          fieldKey: 'segmentId',
          message:
              'Level "${level.levelId}" contains an assembly segment without segmentId.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(segment.segmentId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_segment_id',
          elementId: segment.segmentId,
          fieldKey: 'segmentId',
          message:
              'Level "${level.levelId}" segmentId "${segment.segmentId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!seenSegmentIds.add(segment.segmentId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_segment_id',
          elementId: segment.segmentId,
          fieldKey: 'segmentId',
          message:
              'Level "${level.levelId}" has duplicate segmentId "${segment.segmentId}".',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    if (segment.groupId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_group_id',
          elementId: segment.segmentId,
          fieldKey: 'groupId',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" must have a groupId.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(segment.groupId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_group_id',
          elementId: segment.segmentId,
          fieldKey: 'groupId',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" groupId '
              '"${segment.groupId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (!levelChunkThemeGroups.contains(segment.groupId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'unknown_assembly_group_id',
          elementId: segment.segmentId,
          fieldKey: 'groupId',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'references groupId "${segment.groupId}" that is not defined '
              'in chunkThemeGroups.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else {
      groupIsResolvable = true;
    }

    if (segment.minChunkCount <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_min_chunk_count',
          elementId: segment.segmentId,
          fieldKey: 'minChunkCount',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'minChunkCount must be > 0.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }
    if (segment.maxChunkCount <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_max_chunk_count',
          elementId: segment.segmentId,
          fieldKey: 'maxChunkCount',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'maxChunkCount must be > 0.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    } else if (segment.maxChunkCount < segment.minChunkCount) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_chunk_count_range',
          elementId: segment.segmentId,
          fieldKey: 'maxChunkCount',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" must '
              'satisfy minChunkCount <= maxChunkCount.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
        ),
      );
    }

    final availableCount = segment.difficulty == null
        ? (availableGroupCounts[segment.groupId] ?? 0)
        : document.authoredSchedulerChunks
              .where(
                (chunk) =>
                    chunk.levelId == level.levelId &&
                    chunk.assemblyGroupId == segment.groupId &&
                    chunk.tier == segment.difficulty,
              )
              .map((chunk) => chunk.chunkKey)
              .toSet()
              .length;
    final requiredCount = segment.requireDistinctChunks
        ? segment.maxChunkCount
        : 1;
    if ((segment.requireDistinctChunks || segment.difficulty != null) &&
        groupIsResolvable &&
        document.chunkCountSourceAvailable &&
        availableCount < requiredCount) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: segment.difficulty == null
              ? 'insufficient_distinct_group_chunks'
              : 'insufficient_section_chunks',
          elementId: segment.segmentId,
          fieldKey: segment.difficulty == null
              ? 'requireDistinctChunks'
              : 'difficulty',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'requires $requiredCount ${segment.requireDistinctChunks ? 'distinct ' : ''}'
              '${segment.difficulty == null ? '' : '${segment.difficulty!.name} '}chunks, '
              'but group "${segment.groupId}" only has $availableCount matching active chunks.',
          sourcePath: sourcePath,
          ownerKey: level.levelId,
          blockingOperations: <AuthoringOperation>{
            AuthoringOperation.play,
            if (level.includeInBuild) AuthoringOperation.build,
          },
        ),
      );
    }
  }
}

void _validateChunkWindow(
  List<ValidationIssue> issues, {
  required String sourcePath,
  required LevelDef level,
  required String fieldLabel,
  required int value,
}) {
  if (value < 0) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_$fieldLabel',
        fieldKey: fieldLabel,
        message: 'Level "${level.levelId}" $fieldLabel must be >= 0.',
        sourcePath: sourcePath,
        ownerKey: level.levelId,
      ),
    );
  }
}

bool _levelOrderingMatches(List<LevelDef> levels) {
  final expected = List<LevelDef>.from(levels)..sort(compareLevelDefsCanonical);
  if (expected.length != levels.length) {
    return false;
  }
  for (var i = 0; i < levels.length; i += 1) {
    if (levels[i].levelId != expected[i].levelId) {
      return false;
    }
  }
  return true;
}

int _compareIssues(ValidationIssue a, ValidationIssue b) {
  final sourceCompare = (a.sourcePath ?? '').compareTo(b.sourcePath ?? '');
  if (sourceCompare != 0) {
    return sourceCompare;
  }
  final severityCompare = a.severity.index.compareTo(b.severity.index);
  if (severityCompare != 0) {
    return severityCompare;
  }
  final codeCompare = a.code.compareTo(b.code);
  if (codeCompare != 0) {
    return codeCompare;
  }
  return a.message.compareTo(b.message);
}
