import 'dart:convert';
import 'dart:io';

import '../domain/authoring_types.dart';
import '../parallax/parallax_store.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'level_domain_models.dart';

class LevelStore {
  static const String defsPath = levelDefsSourcePath;
  static const String chunksDirectoryPath = 'assets/authoring/level/chunks';

  const LevelStore();

  Future<LevelDefsDocument> load(
    EditorWorkspace workspace, {
    String? preferredActiveLevelId,
  }) async {
    final file = File(workspace.resolve(defsPath));
    final loadIssues = <ValidationIssue>[];
    String? raw;
    LevelSourceBaseline? baseline;

    if (file.existsSync()) {
      try {
        raw = await file.readAsString();
        baseline = LevelSourceBaseline(
          sourcePath: defsPath,
          fingerprint: WorkspaceFileIo.fingerprint(raw),
        );
      } on Object catch (error) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'level_defs_read_failed',
            message: 'Failed to read $defsPath: $error',
            sourcePath: defsPath,
          ),
        );
      }
    } else {
      loadIssues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'missing_level_defs_file',
          message: 'Required level_defs.json file is missing.',
          sourcePath: defsPath,
        ),
      );
    }

    final levels = <LevelDef>[];
    if (raw != null) {
      levels.addAll(_parseRoot(raw, sourcePath: defsPath, issues: loadIssues));
      final canonical = renderCanonicalLevelDefsJson(levels);
      if (_normalizeNewlines(raw) != canonical) {
        loadIssues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'non_canonical_level_defs',
            message:
                'level_defs.json must use canonical field order, list order, '
                'identifier normalization, and numeric formatting.',
            sourcePath: defsPath,
          ),
        );
      }
    }

    final canonicalLevels = List<LevelDef>.from(levels)
      ..sort(compareLevelDefsCanonical);
    final sceneOrderedLevels = List<LevelDef>.from(levels)
      ..sort(compareLevelDefsForScene);
    final activeLevelId = _resolveActiveLevelId(
      sceneOrderedLevels,
      preferredActiveLevelId,
    );
    final parallaxThemeSnapshot = _loadParallaxVisualThemeIds(workspace);
    final chunkCountSnapshot = _loadAuthoredChunkCounts(workspace);

    return LevelDefsDocument(
      workspaceRootPath: workspace.rootPath,
      levels: List<LevelDef>.unmodifiable(canonicalLevels),
      baseline: baseline,
      baselineLevels: List<LevelDef>.unmodifiable(canonicalLevels),
      activeLevelId: activeLevelId,
      availableParallaxVisualThemeIds: List<String>.unmodifiable(
        parallaxThemeSnapshot.visualThemeIds,
      ),
      parallaxThemeSourceAvailable: parallaxThemeSnapshot.sourceAvailable,
      authoredChunkCountsByLevelId: Map<String, int>.unmodifiable(
        chunkCountSnapshot.countsByLevelId,
      ),
      authoredChunkAssemblyGroupCountsByLevelId:
          Map<String, Map<String, int>>.unmodifiable(
            chunkCountSnapshot.assemblyGroupCountsByLevelId.map(
              (levelId, groupCounts) =>
                  MapEntry(levelId, Map<String, int>.unmodifiable(groupCounts)),
            ),
          ),
      chunkCountSourceAvailable: chunkCountSnapshot.sourceAvailable,
      loadIssues: List<ValidationIssue>.unmodifiable(loadIssues),
    );
  }

  LevelSavePlan buildSavePlan(
    EditorWorkspace workspace, {
    required LevelDefsDocument document,
  }) {
    final file = File(workspace.resolve(defsPath));
    final beforeContent = file.existsSync() ? file.readAsStringSync() : null;
    final afterContent = renderCanonicalLevelDefsJson(document.levels);
    if (_normalizeNewlines(beforeContent ?? '') == afterContent) {
      return const LevelSavePlan(
        changedLevelIds: <String>[],
        writes: <LevelFileWrite>[],
      );
    }

    return LevelSavePlan(
      changedLevelIds: _computeChangedLevelIds(document),
      writes: <LevelFileWrite>[
        LevelFileWrite(
          relativePath: defsPath,
          beforeContent: beforeContent,
          afterContent: afterContent,
        ),
      ],
    );
  }

  Future<void> save(
    EditorWorkspace workspace, {
    required LevelDefsDocument document,
    required LevelSavePlan savePlan,
  }) async {
    if (savePlan.writes.isEmpty) {
      return;
    }
    _verifyNoSourceDrift(workspace, document: document);
    for (final write in savePlan.writes) {
      final file = File(workspace.resolve(write.relativePath));
      WorkspaceFileIo.atomicWrite(file, write.afterContent);
    }
  }

  List<LevelDef> _parseRoot(
    String raw, {
    required String sourcePath,
    required List<ValidationIssue> issues,
  }) {
    final decoded = _parseJsonMap(raw);
    if (decoded == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_level_defs_json',
          message: '$sourcePath is not a valid JSON object.',
          sourcePath: sourcePath,
        ),
      );
      return const <LevelDef>[];
    }

    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != levelDefsSchemaVersion) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_schema_version',
          message:
              'schemaVersion must be the integer $levelDefsSchemaVersion in '
              '$sourcePath.',
          sourcePath: sourcePath,
        ),
      );
    }

    final rawLevels = decoded['levels'];
    if (rawLevels is! List<Object?>) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_levels_array',
          message: 'levels must be an array of objects.',
          sourcePath: sourcePath,
        ),
      );
      return const <LevelDef>[];
    }

    final levels = <LevelDef>[];
    final levelIds = <String>{};
    final enumOrdinals = <int>{};
    for (var i = 0; i < rawLevels.length; i += 1) {
      final rawLevel = rawLevels[i];
      if (rawLevel is! Map<String, Object?>) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'invalid_level_entry',
            message: 'levels[$i] must be an object.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      final level = _parseLevel(
        rawLevel,
        sourcePath: sourcePath,
        prefix: 'levels[$i]',
        issues: issues,
      );
      if (level == null) {
        continue;
      }
      if (!levelIds.add(level.levelId)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_level_id',
            message: 'levelId "${level.levelId}" is duplicated.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      if (!enumOrdinals.add(level.enumOrdinal)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_enum_ordinal',
            message: 'enumOrdinal ${level.enumOrdinal} is duplicated.',
            sourcePath: sourcePath,
          ),
        );
        continue;
      }
      levels.add(level);
    }

    levels.sort(compareLevelDefsCanonical);
    return levels;
  }

  LevelDef? _parseLevel(
    Map<String, Object?> raw, {
    required String sourcePath,
    required String prefix,
    required List<ValidationIssue> issues,
  }) {
    final levelId = _readRequiredString(
      raw,
      field: 'levelId',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final revision = _readRequiredInt(
      raw,
      field: 'revision',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final displayName = _readRequiredString(
      raw,
      field: 'displayName',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final visualThemeId = _readRequiredString(
      raw,
      field: 'visualThemeId',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final chunkThemeGroups = _readOptionalStringList(
      raw,
      field: 'chunkThemeGroups',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
      fallback: const <String>[defaultLevelChunkThemeGroupId],
    );
    final cameraCenterY = _readRequiredDouble(
      raw,
      field: 'cameraCenterY',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final groundTopY = _readRequiredDouble(
      raw,
      field: 'groundTopY',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final earlyPatternChunks = _readRequiredInt(
      raw,
      field: 'earlyPatternChunks',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final easyPatternChunks = _readRequiredInt(
      raw,
      field: 'easyPatternChunks',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final normalPatternChunks = _readRequiredInt(
      raw,
      field: 'normalPatternChunks',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final noEnemyChunks = _readRequiredInt(
      raw,
      field: 'noEnemyChunks',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final enumOrdinal = _readRequiredInt(
      raw,
      field: 'enumOrdinal',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final status = _readRequiredString(
      raw,
      field: 'status',
      sourcePath: sourcePath,
      prefix: prefix,
      issues: issues,
    );
    final assembly = _parseAssembly(
      raw['assembly'],
      sourcePath: sourcePath,
      prefix: '$prefix.assembly',
      issues: issues,
    );

    if (levelId.isEmpty ||
        revision == null ||
        displayName.isEmpty ||
        visualThemeId.isEmpty ||
        cameraCenterY == null ||
        groundTopY == null ||
        earlyPatternChunks == null ||
        easyPatternChunks == null ||
        normalPatternChunks == null ||
        noEnemyChunks == null ||
        enumOrdinal == null ||
        status.isEmpty) {
      return null;
    }

    return LevelDef(
      levelId: levelId,
      revision: revision,
      displayName: displayName,
      visualThemeId: visualThemeId,
      chunkThemeGroups: chunkThemeGroups,
      cameraCenterY: cameraCenterY,
      groundTopY: groundTopY,
      earlyPatternChunks: earlyPatternChunks,
      easyPatternChunks: easyPatternChunks,
      normalPatternChunks: normalPatternChunks,
      noEnemyChunks: noEnemyChunks,
      enumOrdinal: enumOrdinal,
      status: status,
      assembly: assembly,
    ).normalized();
  }

  _ParallaxThemeSnapshot _loadParallaxVisualThemeIds(
    EditorWorkspace workspace,
  ) {
    final file = File(workspace.resolve(ParallaxStore.defsPath));
    if (!file.existsSync()) {
      return const _ParallaxThemeSnapshot(
        visualThemeIds: <String>[],
        sourceAvailable: false,
      );
    }
    final map = _parseJsonMap(file.readAsStringSync());
    if (map == null) {
      return const _ParallaxThemeSnapshot(
        visualThemeIds: <String>[],
        sourceAvailable: false,
      );
    }
    final rawThemes = map['themes'];
    if (rawThemes is! List<Object?>) {
      return const _ParallaxThemeSnapshot(
        visualThemeIds: <String>[],
        sourceAvailable: false,
      );
    }
    final visualThemeIds = <String>{};
    for (final rawTheme in rawThemes) {
      if (rawTheme is! Map<String, Object?>) {
        continue;
      }
      final visualThemeId = _normalizedString(rawTheme['parallaxThemeId']);
      if (visualThemeId.isNotEmpty) {
        visualThemeIds.add(visualThemeId);
      }
    }
    final sortedVisualThemeIds = visualThemeIds.toList(growable: false)..sort();
    return _ParallaxThemeSnapshot(
      visualThemeIds: List<String>.unmodifiable(sortedVisualThemeIds),
      sourceAvailable: true,
    );
  }

  _ChunkCountSnapshot _loadAuthoredChunkCounts(EditorWorkspace workspace) {
    final chunkDirectory = Directory(workspace.resolve(chunksDirectoryPath));
    if (!chunkDirectory.existsSync()) {
      return const _ChunkCountSnapshot(
        countsByLevelId: <String, int>{},
        assemblyGroupCountsByLevelId: <String, Map<String, int>>{},
        sourceAvailable: false,
      );
    }
    final countsByLevelId = <String, int>{};
    final assemblyGroupCountsByLevelId = <String, Map<String, int>>{};
    final files =
        chunkDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final map = _parseJsonMap(file.readAsStringSync());
      if (map == null) {
        continue;
      }
      final levelId = _normalizedString(map['levelId']);
      if (levelId.isEmpty) {
        continue;
      }
      countsByLevelId[levelId] = (countsByLevelId[levelId] ?? 0) + 1;
      final status = _normalizedString(
        map['status'],
        fallback: levelStatusActive,
      );
      if (status == levelStatusDeprecated) {
        continue;
      }
      final assemblyGroupId = _normalizedString(
        map['assemblyGroupId'],
        fallback: defaultAssemblyGroupId,
      );
      final groupCounts = assemblyGroupCountsByLevelId.putIfAbsent(
        levelId,
        () => <String, int>{},
      );
      groupCounts[assemblyGroupId] = (groupCounts[assemblyGroupId] ?? 0) + 1;
    }
    final sortedEntries = countsByLevelId.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedGroupEntries = assemblyGroupCountsByLevelId.entries.toList(
      growable: false,
    )..sort((a, b) => a.key.compareTo(b.key));
    return _ChunkCountSnapshot(
      countsByLevelId: <String, int>{
        for (final entry in sortedEntries) entry.key: entry.value,
      },
      assemblyGroupCountsByLevelId: <String, Map<String, int>>{
        for (final entry in sortedGroupEntries)
          entry.key: <String, int>{
            for (final groupEntry in (entry.value.entries.toList(
              growable: false,
            )..sort((a, b) => a.key.compareTo(b.key))))
              groupEntry.key: groupEntry.value,
          },
      },
      sourceAvailable: true,
    );
  }

  void _verifyNoSourceDrift(
    EditorWorkspace workspace, {
    required LevelDefsDocument document,
  }) {
    final baseline = document.baseline;
    if (baseline == null) {
      return;
    }
    final file = File(workspace.resolve(baseline.sourcePath));
    if (!file.existsSync()) {
      throw StateError(
        'Source drift detected for ${baseline.sourcePath}: file no longer '
        'exists. Reload before export.',
      );
    }
    final currentFingerprint = WorkspaceFileIo.fingerprint(
      file.readAsStringSync(),
    );
    if (currentFingerprint != baseline.fingerprint) {
      throw StateError(
        'Source drift detected for ${baseline.sourcePath}. Reload before '
        'export.',
      );
    }
  }
}

class LevelSavePlan {
  const LevelSavePlan({required this.changedLevelIds, required this.writes});

  final List<String> changedLevelIds;
  final List<LevelFileWrite> writes;

  bool get hasChanges => writes.isNotEmpty;
}

class LevelFileWrite {
  const LevelFileWrite({
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}

class _ParallaxThemeSnapshot {
  const _ParallaxThemeSnapshot({
    required this.visualThemeIds,
    required this.sourceAvailable,
  });

  final List<String> visualThemeIds;
  final bool sourceAvailable;
}

class _ChunkCountSnapshot {
  const _ChunkCountSnapshot({
    required this.countsByLevelId,
    required this.assemblyGroupCountsByLevelId,
    required this.sourceAvailable,
  });

  final Map<String, int> countsByLevelId;
  final Map<String, Map<String, int>> assemblyGroupCountsByLevelId;
  final bool sourceAvailable;
}

String? _resolveActiveLevelId(List<LevelDef> levels, String? preferredLevelId) {
  if (levels.isEmpty) {
    return null;
  }
  if (preferredLevelId != null &&
      levels.any((level) => level.levelId == preferredLevelId)) {
    return preferredLevelId;
  }
  return levels.first.levelId;
}

List<String> _computeChangedLevelIds(LevelDefsDocument document) {
  final currentById = <String, LevelDef>{
    for (final level in document.levels) level.levelId: level.normalized(),
  };
  final baselineById = <String, LevelDef>{
    for (final level in document.baselineLevels)
      level.levelId: level.normalized(),
  };
  final changedLevelIds = <String>{};
  for (final current in currentById.entries) {
    final baseline = baselineById[current.key];
    if (baseline == null || !levelDefEquals(current.value, baseline)) {
      changedLevelIds.add(current.key);
    }
  }
  for (final baseline in baselineById.keys) {
    if (!currentById.containsKey(baseline)) {
      changedLevelIds.add(baseline);
    }
  }
  final sorted = changedLevelIds.toList(growable: false)..sort();
  return List<String>.unmodifiable(sorted);
}

Map<String, Object?>? _parseJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
  } on Object {
    return null;
  }
  return null;
}

String _readRequiredString(
  Map<String, Object?> raw, {
  required String field,
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  final value = _normalizedString(raw[field]);
  if (value.isNotEmpty) {
    return value;
  }
  issues.add(
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: 'missing_$field',
      message: '$prefix.$field must be a non-empty string.',
      sourcePath: sourcePath,
    ),
  );
  return '';
}

int? _readRequiredInt(
  Map<String, Object?> raw, {
  required String field,
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  final value = raw[field];
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  issues.add(
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: 'invalid_$field',
      message: '$prefix.$field must be an integer.',
      sourcePath: sourcePath,
    ),
  );
  return null;
}

double? _readRequiredDouble(
  Map<String, Object?> raw, {
  required String field,
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  final value = raw[field];
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  issues.add(
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: 'invalid_$field',
      message: '$prefix.$field must be a finite number.',
      sourcePath: sourcePath,
    ),
  );
  return null;
}

bool? _readRequiredBool(
  Map<String, Object?> raw, {
  required String field,
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  final value = raw[field];
  if (value is bool) {
    return value;
  }
  issues.add(
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: 'invalid_$field',
      message: '$prefix.$field must be a boolean.',
      sourcePath: sourcePath,
    ),
  );
  return null;
}

List<String> _readOptionalStringList(
  Map<String, Object?> raw, {
  required String field,
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
  required List<String> fallback,
}) {
  final value = raw[field];
  if (value == null) {
    return fallback;
  }
  if (value is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_$field',
        message: '$prefix.$field must be an array of strings when present.',
        sourcePath: sourcePath,
      ),
    );
    return fallback;
  }
  final strings = <String>[];
  var hasInvalidValue = false;
  for (final entry in value) {
    final normalized = _normalizedString(entry);
    if (normalized.isEmpty) {
      hasInvalidValue = true;
      continue;
    }
    strings.add(normalized);
  }
  if (hasInvalidValue) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_$field',
        message: '$prefix.$field entries must be non-empty strings.',
        sourcePath: sourcePath,
      ),
    );
  }
  if (strings.isEmpty) {
    return fallback;
  }
  return normalizeLevelChunkThemeGroups(strings);
}

LevelAssemblyDef? _parseAssembly(
  Object? raw, {
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  if (raw == null) {
    return null;
  }
  if (raw is! Map<String, Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_assembly',
        message: '$prefix must be an object.',
        sourcePath: sourcePath,
      ),
    );
    return null;
  }
  final loopSegments = _readRequiredBool(
    raw,
    field: 'loopSegments',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  final rawSegments = raw['segments'];
  if (rawSegments is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'invalid_assembly_segments',
        message: '$prefix.segments must be an array.',
        sourcePath: sourcePath,
      ),
    );
    return null;
  }

  final segments = <LevelAssemblySegmentDef>[];
  for (var i = 0; i < rawSegments.length; i += 1) {
    final entry = rawSegments[i];
    if (entry is! Map<String, Object?>) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'invalid_assembly_segment',
          message: '$prefix.segments[$i] must be an object.',
          sourcePath: sourcePath,
        ),
      );
      continue;
    }
    final segment = _parseAssemblySegment(
      entry,
      sourcePath: sourcePath,
      prefix: '$prefix.segments[$i]',
      issues: issues,
    );
    if (segment != null) {
      segments.add(segment);
    }
  }

  if (loopSegments == null) {
    return null;
  }

  return LevelAssemblyDef(
    loopSegments: loopSegments,
    segments: List<LevelAssemblySegmentDef>.unmodifiable(segments),
  ).normalized();
}

LevelAssemblySegmentDef? _parseAssemblySegment(
  Map<String, Object?> raw, {
  required String sourcePath,
  required String prefix,
  required List<ValidationIssue> issues,
}) {
  final segmentId = _readRequiredString(
    raw,
    field: 'segmentId',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  final groupId = _readRequiredString(
    raw,
    field: 'groupId',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  final minChunkCount = _readRequiredInt(
    raw,
    field: 'minChunkCount',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  final maxChunkCount = _readRequiredInt(
    raw,
    field: 'maxChunkCount',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  final requireDistinctChunks = _readRequiredBool(
    raw,
    field: 'requireDistinctChunks',
    sourcePath: sourcePath,
    prefix: prefix,
    issues: issues,
  );
  if (segmentId.isEmpty ||
      groupId.isEmpty ||
      minChunkCount == null ||
      maxChunkCount == null ||
      requireDistinctChunks == null) {
    return null;
  }
  return LevelAssemblySegmentDef(
    segmentId: segmentId,
    groupId: groupId,
    minChunkCount: minChunkCount,
    maxChunkCount: maxChunkCount,
    requireDistinctChunks: requireDistinctChunks,
  ).normalized();
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    final normalized = raw.trim().replaceAll('\\', '/');
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

String _normalizeNewlines(String raw) {
  return raw.replaceAll('\r\n', '\n');
}
