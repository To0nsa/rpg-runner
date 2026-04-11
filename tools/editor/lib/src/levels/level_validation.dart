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

    if (level.themeId.isEmpty) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_theme_id',
          message: 'Level "${level.levelId}" must have a themeId.',
          sourcePath: sourcePath,
        ),
      );
    } else if (!stableLevelIdentifierPattern.hasMatch(level.themeId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_theme_id',
          message:
              'Level "${level.levelId}" themeId "${level.themeId}" must match '
              '${stableLevelIdentifierPattern.pattern}.',
          sourcePath: sourcePath,
        ),
      );
    } else if (document.parallaxThemeSourceAvailable &&
        !document.availableParallaxThemeIds.contains(level.themeId)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'missing_parallax_theme',
          message:
              'Level "${level.levelId}" references unauthored themeId '
              '"${level.themeId}".',
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
  }

  issues.sort(_compareIssues);
  return issues;
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
