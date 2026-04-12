import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'level_domain_models.dart';
import 'level_store.dart';
import 'level_validation.dart';

class LevelDomainPlugin implements AuthoringDomainPlugin {
  LevelDomainPlugin({LevelStore store = const LevelStore()}) : _store = store;

  static const String pluginId = 'levels';

  final LevelStore _store;
  String? _preferredActiveLevelId;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final loaded = await _store.load(
      workspace,
      preferredActiveLevelId: _preferredActiveLevelId,
    );
    _preferredActiveLevelId = loaded.activeLevelId;
    return loaded;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    return validateLevelDocument(_asLevelDocument(document));
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final levelDocument = _asLevelDocument(document);
    final sceneLevels = List<LevelDef>.from(levelDocument.levels)
      ..sort(compareLevelDefsForScene);
    final activeLevel = findLevelDefById(
      sceneLevels,
      levelDocument.activeLevelId,
    );
    return LevelScene(
      levels: List<LevelDef>.unmodifiable(sceneLevels),
      activeLevelId: levelDocument.activeLevelId,
      activeLevel: activeLevel,
      availableParallaxVisualThemeIds:
          levelDocument.availableParallaxVisualThemeIds,
      authoredChunkCountsByLevelId: levelDocument.authoredChunkCountsByLevelId,
      authoredChunkAssemblyGroupCountsByLevelId:
          levelDocument.authoredChunkAssemblyGroupCountsByLevelId,
      sourcePath: levelDocument.baseline?.sourcePath ?? LevelStore.defsPath,
      workspaceRootPath: levelDocument.workspaceRootPath,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final levelDocument = _asLevelDocument(document);
    switch (command.kind) {
      case 'set_active_level':
        return _setActiveLevel(levelDocument, command.payload);
      case 'create_level':
        return _createLevel(levelDocument, command.payload);
      case 'duplicate_level':
        return _duplicateLevel(levelDocument, command.payload);
      case 'update_level':
        return _updateLevel(levelDocument, command.payload);
      case 'deprecate_level':
        return _setLevelStatus(
          levelDocument,
          command.payload,
          nextStatus: levelStatusDeprecated,
        );
      case 'reactivate_level':
        return _setLevelStatus(
          levelDocument,
          command.payload,
          nextStatus: levelStatusActive,
        );
      default:
        return _clearOperationIssuesIfNeeded(levelDocument);
    }
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final levelDocument = _asLevelDocument(document);
    final blockingIssues = validateLevelDocument(
      levelDocument,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export levels while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }

    final savePlan = _store.buildSavePlan(workspace, document: levelDocument);
    if (!savePlan.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: const <ExportArtifact>[
          ExportArtifact(
            title: 'level_summary.md',
            content:
                '# Level Export\n\nchangedLevels: 0\n\nNo level edits detected.',
          ),
        ],
      );
    }

    await _store.save(workspace, document: levelDocument, savePlan: savePlan);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(
          title: 'level_summary.md',
          content: _buildSummary(savePlan),
        ),
      ],
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final levelDocument = _asLevelDocument(document);
    final savePlan = _store.buildSavePlan(workspace, document: levelDocument);
    if (!savePlan.hasChanges) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: savePlan.changedLevelIds,
      fileDiffs: savePlan.writes
          .map(
            (write) => PendingFileDiff(
              relativePath: write.relativePath,
              editCount: 1,
              unifiedDiff: _buildUnifiedDiff(write),
            ),
          )
          .toList(growable: false),
    );
  }

  LevelDefsDocument _setActiveLevel(
    LevelDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    if (levelId.isEmpty || findLevelDefById(document.levels, levelId) == null) {
      return _withOperationIssue(
        document,
        code: 'set_active_level_invalid',
        message:
            'Cannot set active level to "$levelId". Choose an authored level.',
      );
    }
    if (document.activeLevelId == levelId) {
      return document;
    }
    _preferredActiveLevelId = levelId;
    return document.copyWith(activeLevelId: levelId);
  }

  LevelDefsDocument _createLevel(
    LevelDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    if (levelId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'create_level_missing_level_id',
        message: 'Create level requires a non-empty levelId.',
      );
    }
    if (!stableLevelIdentifierPattern.hasMatch(levelId)) {
      return _withOperationIssue(
        document,
        code: 'create_level_invalid_level_id',
        message:
            'levelId "$levelId" must match ${stableLevelIdentifierPattern.pattern}.',
      );
    }
    if (findLevelDefById(document.levels, levelId) != null) {
      return _withOperationIssue(
        document,
        code: 'create_level_id_collision',
        message: 'Cannot create level. levelId "$levelId" already exists.',
      );
    }

    final nextLevel = LevelDef(
      levelId: levelId,
      revision: 1,
      displayName: _normalizedString(
        payload['displayName'],
        fallback: titleCaseLevelId(levelId),
      ),
      visualThemeId: _normalizedString(
        payload['visualThemeId'],
        fallback: levelId,
      ),
      chunkThemeGroups: const <String>[defaultLevelChunkThemeGroupId],
      cameraCenterY: _doubleOrDefault(
        payload['cameraCenterY'],
        fallback:
            _referenceLevel(document)?.cameraCenterY ??
            defaultLevelCameraCenterY,
      ),
      groundTopY: _doubleOrDefault(
        payload['groundTopY'],
        fallback:
            _referenceLevel(document)?.groundTopY ?? defaultLevelGroundTopY,
      ),
      earlyPatternChunks: _intOrDefault(
        payload['earlyPatternChunks'],
        fallback:
            _referenceLevel(document)?.earlyPatternChunks ??
            defaultEarlyPatternChunks,
      ),
      easyPatternChunks: _intOrDefault(
        payload['easyPatternChunks'],
        fallback:
            _referenceLevel(document)?.easyPatternChunks ??
            defaultEasyPatternChunks,
      ),
      normalPatternChunks: _intOrDefault(
        payload['normalPatternChunks'],
        fallback:
            _referenceLevel(document)?.normalPatternChunks ??
            defaultNormalPatternChunks,
      ),
      noEnemyChunks: _intOrDefault(
        payload['noEnemyChunks'],
        fallback:
            _referenceLevel(document)?.noEnemyChunks ?? defaultNoEnemyChunks,
      ),
      enumOrdinal: _intOrDefault(
        payload['enumOrdinal'],
        fallback: _nextEnumOrdinal(document.levels),
      ),
      status: levelStatusActive,
    ).normalized();

    final nextLevels = List<LevelDef>.from(document.levels)
      ..add(nextLevel)
      ..sort(compareLevelDefsCanonical);
    _preferredActiveLevelId = levelId;
    return document.copyWith(
      levels: List<LevelDef>.unmodifiable(nextLevels),
      activeLevelId: levelId,
    );
  }

  LevelDefsDocument _duplicateLevel(
    LevelDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final sourceLevelId = _normalizedString(payload['levelId']);
    final source = findLevelDefById(document.levels, sourceLevelId);
    if (source == null) {
      return _withOperationIssue(
        document,
        code: 'duplicate_level_missing_source',
        message: 'Cannot duplicate unknown levelId "$sourceLevelId".',
      );
    }
    final requestedLevelId = _normalizedString(
      payload['nextLevelId'],
      fallback: _allocateUniqueLevelId(
        document.levels,
        '${source.levelId}_copy',
      ),
    );
    if (!stableLevelIdentifierPattern.hasMatch(requestedLevelId)) {
      return _withOperationIssue(
        document,
        code: 'duplicate_level_invalid_level_id',
        message:
            'levelId "$requestedLevelId" must match ${stableLevelIdentifierPattern.pattern}.',
      );
    }
    if (findLevelDefById(document.levels, requestedLevelId) != null) {
      return _withOperationIssue(
        document,
        code: 'duplicate_level_id_collision',
        message:
            'Cannot duplicate level "${source.levelId}". levelId "$requestedLevelId" already exists.',
      );
    }
    final duplicate = source
        .copyWith(
          levelId: requestedLevelId,
          revision: 1,
          displayName: _normalizedString(
            payload['displayName'],
            fallback: '${source.displayName} Copy',
          ),
          enumOrdinal: _intOrDefault(
            payload['enumOrdinal'],
            fallback: _nextEnumOrdinal(document.levels),
          ),
          status: levelStatusActive,
        )
        .normalized();
    final nextLevels = List<LevelDef>.from(document.levels)
      ..add(duplicate)
      ..sort(compareLevelDefsCanonical);
    _preferredActiveLevelId = requestedLevelId;
    return document.copyWith(
      levels: List<LevelDef>.unmodifiable(nextLevels),
      activeLevelId: requestedLevelId,
    );
  }

  LevelDefsDocument _updateLevel(
    LevelDefsDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    final source = findLevelDefById(document.levels, levelId);
    if (source == null) {
      return _withOperationIssue(
        document,
        code: 'update_level_missing_source',
        message: 'Cannot update unknown levelId "$levelId".',
      );
    }

    final nextLevel = source
        .copyWith(
          displayName: _normalizedString(
            payload['displayName'],
            fallback: source.displayName,
          ),
          visualThemeId: _normalizedString(
            payload['visualThemeId'],
            fallback: source.visualThemeId,
          ),
          chunkThemeGroups: payload.containsKey('chunkThemeGroups')
              ? _parseChunkThemeGroups(
                  payload['chunkThemeGroups'],
                  fallback: source.chunkThemeGroups,
                )
              : source.chunkThemeGroups,
          cameraCenterY: _doubleOrDefault(
            payload['cameraCenterY'],
            fallback: source.cameraCenterY,
          ),
          groundTopY: _doubleOrDefault(
            payload['groundTopY'],
            fallback: source.groundTopY,
          ),
          earlyPatternChunks: _intOrDefault(
            payload['earlyPatternChunks'],
            fallback: source.earlyPatternChunks,
          ),
          easyPatternChunks: _intOrDefault(
            payload['easyPatternChunks'],
            fallback: source.easyPatternChunks,
          ),
          normalPatternChunks: _intOrDefault(
            payload['normalPatternChunks'],
            fallback: source.normalPatternChunks,
          ),
          noEnemyChunks: _intOrDefault(
            payload['noEnemyChunks'],
            fallback: source.noEnemyChunks,
          ),
          enumOrdinal: _intOrDefault(
            payload['enumOrdinal'],
            fallback: source.enumOrdinal,
          ),
          status: _normalizedString(payload['status'], fallback: source.status),
          assembly: payload.containsKey('assembly') ? null : source.assembly,
          clearAssembly: payload.containsKey('assembly'),
        )
        .normalized();
    if (payload.containsKey('assembly')) {
      final assemblyParse = _parseAssemblyPayload(payload['assembly']);
      if (assemblyParse.issueMessage != null) {
        return _withOperationIssue(
          document,
          code: 'update_level_invalid_assembly',
          message: assemblyParse.issueMessage!,
        );
      }
      final rebuiltLevel = nextLevel.copyWith(
        assembly: assemblyParse.value,
        clearAssembly: assemblyParse.value == null,
      );
      if (levelDefEquals(rebuiltLevel, source, ignoreRevision: true)) {
        return document;
      }
      final bumped = _bumpRevision(rebuiltLevel, fromLevel: source);
      return _replaceLevel(document, levelId: levelId, nextLevel: bumped);
    }
    if (levelDefEquals(nextLevel, source, ignoreRevision: true)) {
      return document;
    }
    final bumped = _bumpRevision(nextLevel, fromLevel: source);
    return _replaceLevel(document, levelId: levelId, nextLevel: bumped);
  }

  LevelDefsDocument _setLevelStatus(
    LevelDefsDocument document,
    Map<String, Object?> payload, {
    required String nextStatus,
  }) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    final source = findLevelDefById(document.levels, levelId);
    if (source == null) {
      return _withOperationIssue(
        document,
        code: '${nextStatus}_level_missing_source',
        message: 'Cannot update status for unknown levelId "$levelId".',
      );
    }
    if (source.status == nextStatus) {
      return document;
    }
    final nextLevel = _bumpRevision(
      source.copyWith(status: nextStatus).normalized(),
      fromLevel: source,
    );
    return _replaceLevel(document, levelId: levelId, nextLevel: nextLevel);
  }

  LevelDefsDocument _replaceLevel(
    LevelDefsDocument document, {
    required String levelId,
    required LevelDef nextLevel,
  }) {
    final nextLevels =
        document.levels
            .map((level) => level.levelId == levelId ? nextLevel : level)
            .toList(growable: false)
          ..sort(compareLevelDefsCanonical);
    return document.copyWith(levels: List<LevelDef>.unmodifiable(nextLevels));
  }

  LevelDef? _referenceLevel(LevelDefsDocument document) {
    final active = findLevelDefById(document.levels, document.activeLevelId);
    if (active != null) {
      return active;
    }
    if (document.levels.isEmpty) {
      return null;
    }
    final ordered = List<LevelDef>.from(document.levels)
      ..sort(compareLevelDefsForScene);
    return ordered.first;
  }

  String _buildSummary(LevelSavePlan savePlan) {
    final lines = <String>[
      '# Level Export',
      '',
      'changedLevels: ${savePlan.changedLevelIds.length}',
      'changedFiles: ${savePlan.writes.length}',
      '',
      '## Levels',
      ...savePlan.changedLevelIds.map((levelId) => '- $levelId'),
      '',
      '## Files',
      ...savePlan.writes.map((write) => '- ${write.relativePath}'),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(LevelFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final beforeLines = _splitLines(write.beforeContent ?? '');
    final afterLines = _splitLines(write.afterContent);
    final lines = <String>[
      'diff --git a/$path b/$path',
      '--- a/$path',
      '+++ b/$path',
      '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      ...beforeLines.map((line) => '-$line'),
      ...afterLines.map((line) => '+$line'),
    ];
    return lines.join('\n');
  }

  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  LevelDefsDocument _clearOperationIssuesIfNeeded(LevelDefsDocument document) {
    if (document.operationIssues.isEmpty) {
      return document;
    }
    return document.copyWith(clearOperationIssues: true);
  }

  LevelDefsDocument _withOperationIssue(
    LevelDefsDocument document, {
    required String code,
    required String message,
  }) {
    return document.copyWith(
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: code,
          message: message,
          sourcePath: document.baseline?.sourcePath ?? LevelStore.defsPath,
        ),
      ],
    );
  }

  LevelDefsDocument _asLevelDocument(AuthoringDocument document) {
    if (document is! LevelDefsDocument) {
      throw StateError(
        'LevelDomainPlugin expected LevelDefsDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }
}

int _nextEnumOrdinal(Iterable<LevelDef> levels) {
  var maxOrdinal = 0;
  for (final level in levels) {
    if (level.enumOrdinal > maxOrdinal) {
      maxOrdinal = level.enumOrdinal;
    }
  }
  if (maxOrdinal <= 0) {
    return 10;
  }
  return ((maxOrdinal / 10).floor() + 1) * 10;
}

String _allocateUniqueLevelId(Iterable<LevelDef> levels, String preferredSeed) {
  final existingIds = levels.map((level) => level.levelId).toSet();
  final base = _slugifyLevelId(preferredSeed, fallback: 'level');
  if (!existingIds.contains(base)) {
    return base;
  }
  var counter = 2;
  while (true) {
    final candidate = '${base}_$counter';
    if (!existingIds.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}

String _slugifyLevelId(String raw, {required String fallback}) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return fallback;
  }
  final normalized = lower.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  final collapsed = normalized
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (collapsed.isEmpty) {
    return fallback;
  }
  if (!RegExp(r'^[a-z]').hasMatch(collapsed)) {
    return '${fallback}_$collapsed';
  }
  return collapsed;
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

int _intOrDefault(Object? raw, {required int fallback}) {
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite) {
    return raw.toInt();
  }
  if (raw is String) {
    final parsed = int.tryParse(raw.trim());
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

double _doubleOrDefault(Object? raw, {required double fallback}) {
  if (raw is num && raw.isFinite) {
    return raw.toDouble();
  }
  if (raw is String) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) {
      return parsed;
    }
  }
  return fallback;
}

List<String> _parseChunkThemeGroups(Object? raw, {required List<String> fallback}) {
  if (raw is List) {
    final parsed = <String>[];
    for (final entry in raw) {
      final normalized = _normalizedString(entry);
      if (normalized.isNotEmpty) {
        parsed.add(normalized);
      }
    }
    if (parsed.isNotEmpty) {
      return normalizeLevelChunkThemeGroups(parsed);
    }
    return normalizeLevelChunkThemeGroups(fallback);
  }
  if (raw is String) {
    final parsed = raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    if (parsed.isNotEmpty) {
      return normalizeLevelChunkThemeGroups(parsed);
    }
  }
  return normalizeLevelChunkThemeGroups(fallback);
}

LevelDef _bumpRevision(LevelDef nextLevel, {required LevelDef fromLevel}) {
  final nextRevision = fromLevel.revision <= 0 ? 1 : fromLevel.revision + 1;
  return nextLevel.copyWith(revision: nextRevision);
}

_AssemblyPayloadParseResult _parseAssemblyPayload(Object? raw) {
  if (raw == null) {
    return const _AssemblyPayloadParseResult(value: null);
  }
  if (raw is! Map) {
    return const _AssemblyPayloadParseResult(
      issueMessage: 'assembly payload must be an object or null.',
    );
  }
  final loopSegments = _boolOrNull(raw['loopSegments']);
  if (loopSegments == null) {
    return const _AssemblyPayloadParseResult(
      issueMessage: 'assembly.loopSegments must be a boolean.',
    );
  }
  final rawSegments = raw['segments'];
  if (rawSegments is! List) {
    return const _AssemblyPayloadParseResult(
      issueMessage: 'assembly.segments must be an array.',
    );
  }
  final segments = <LevelAssemblySegmentDef>[];
  for (var i = 0; i < rawSegments.length; i += 1) {
    final rawSegment = rawSegments[i];
    if (rawSegment is! Map) {
      return _AssemblyPayloadParseResult(
        issueMessage: 'assembly.segments[$i] must be an object.',
      );
    }
    final segmentId = _normalizedString(rawSegment['segmentId']);
    final groupId = _normalizedString(rawSegment['groupId']);
    final minChunkCount = _intOrNull(rawSegment['minChunkCount']);
    final maxChunkCount = _intOrNull(rawSegment['maxChunkCount']);
    final requireDistinctChunks = _boolOrNull(
      rawSegment['requireDistinctChunks'],
    );
    if (segmentId.isEmpty ||
        groupId.isEmpty ||
        minChunkCount == null ||
        maxChunkCount == null ||
        requireDistinctChunks == null) {
      return _AssemblyPayloadParseResult(
        issueMessage:
            'assembly.segments[$i] is missing required fields or uses invalid value types.',
      );
    }
    segments.add(
      LevelAssemblySegmentDef(
        segmentId: segmentId,
        groupId: groupId,
        minChunkCount: minChunkCount,
        maxChunkCount: maxChunkCount,
        requireDistinctChunks: requireDistinctChunks,
      ).normalized(),
    );
  }
  if (segments.isEmpty) {
    return const _AssemblyPayloadParseResult(value: null);
  }
  return _AssemblyPayloadParseResult(
    value: LevelAssemblyDef(
      loopSegments: loopSegments,
      segments: List<LevelAssemblySegmentDef>.unmodifiable(segments),
    ).normalized(),
  );
}

int? _intOrNull(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num && raw.isFinite) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw.trim());
  }
  return null;
}

bool? _boolOrNull(Object? raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is String) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
        return true;
      case 'false':
        return false;
    }
  }
  return null;
}

class _AssemblyPayloadParseResult {
  const _AssemblyPayloadParseResult({this.value, this.issueMessage});

  final LevelAssemblyDef? value;
  final String? issueMessage;
}
