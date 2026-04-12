import '../domain/authoring_types.dart';
import 'level_domain_models.dart';

List<ValidationIssue> validateLevelDocument(LevelDefsDocument document) {
  final issues = <ValidationIssue>[
    ...document.loadIssues,
    ...document.operationIssues,
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
        ),
      );
    }
  }

  final seenLevelIds = <String>{};
  final seenEnumOrdinals = <int>{};
  for (final level in canonicalLevels) {
    if (level.levelId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_level_id',
          message: 'A level is missing levelId.',
          sourcePath: sourcePath,
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
        ),
      );
    } else if (!seenLevelIds.add(level.levelId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_level_id',
          message: 'Duplicate levelId "${level.levelId}".',
          sourcePath: sourcePath,
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
        ),
      );
    } else if (!seenEnumOrdinals.add(level.enumOrdinal)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_enum_ordinal',
          message: 'Duplicate enumOrdinal ${level.enumOrdinal}.',
          sourcePath: sourcePath,
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
        ),
      );
    } else if (document.parallaxThemeSourceAvailable &&
        !document.availableParallaxVisualThemeIds.contains(
          level.visualThemeId,
        )) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'missing_parallax_theme',
          message:
              'Level "${level.levelId}" references unauthored visualThemeId '
              '"${level.visualThemeId}".',
          sourcePath: sourcePath,
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
          message:
              'Level "${level.levelId}" contains an assembly segment without segmentId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(segment.segmentId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_segment_id',
          message:
              'Level "${level.levelId}" segmentId "${segment.segmentId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!seenSegmentIds.add(segment.segmentId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'duplicate_segment_id',
          message:
              'Level "${level.levelId}" has duplicate segmentId "${segment.segmentId}".',
          sourcePath: sourcePath,
        ),
      );
    }

    if (segment.groupId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_group_id',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" must have a groupId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(segment.groupId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_group_id',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" groupId '
              '"${segment.groupId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!levelChunkThemeGroups.contains(segment.groupId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'unknown_assembly_group_id',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'references groupId "${segment.groupId}" that is not defined '
              'in chunkThemeGroups.',
          sourcePath: sourcePath,
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
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'minChunkCount must be > 0.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (segment.maxChunkCount <= 0) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_max_chunk_count',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'maxChunkCount must be > 0.',
          sourcePath: sourcePath,
        ),
      );
    } else if (segment.maxChunkCount < segment.minChunkCount) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_chunk_count_range',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" must '
              'satisfy minChunkCount <= maxChunkCount.',
          sourcePath: sourcePath,
        ),
      );
    }

    if (segment.requireDistinctChunks &&
        groupIsResolvable &&
        document.chunkCountSourceAvailable &&
        (availableGroupCounts[segment.groupId] ?? 0) < segment.maxChunkCount) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'insufficient_distinct_group_chunks',
          message:
              'Level "${level.levelId}" segment "${segment.segmentId}" '
              'requires ${segment.maxChunkCount} distinct chunks, but group '
              '"${segment.groupId}" only has ${availableGroupCounts[segment.groupId] ?? 0}.',
          sourcePath: sourcePath,
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
        message: 'Level "${level.levelId}" $fieldLabel must be >= 0.',
        sourcePath: sourcePath,
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
