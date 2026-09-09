import 'package:runner_core/track/chunk_pattern_tier.dart';

import '../domain/authoring_identifiers.dart';
import '../domain/authoring_intent_reconciliation.dart';
import '../domain/authoring_session_semantics.dart';
import '../domain/authoring_types.dart';
import '../parallax/parallax_domain_models.dart';
import '../workspace/editor_workspace.dart';
import 'level_domain_models.dart';
import 'level_history_reconciliation.dart';
import 'level_intent_reconciliation.dart';
import 'level_store.dart';
import 'level_theme_save_coordinator.dart';
import 'level_validation.dart';

const String levelThemeModeCreate = 'create';
const String levelThemeModeExisting = 'existing';
const String levelThemeModeCopy = 'copy';

/// Level export result with structured post-commit cleanup state.
final class LevelThemeExportResult extends ExportResult {
  LevelThemeExportResult({
    required super.applied,
    super.artifacts,
    super.recovery,
    this.cleanupRequiredPaths = const <String>[],
  }) : super(
         outcome: cleanupRequiredPaths.isNotEmpty
             ? ExportOutcome.appliedWithCleanupRequired
             : null,
         message: cleanupRequiredPaths.isEmpty
             ? null
             : 'Sources were saved; transaction cleanup is still required.',
       );

  final List<String> cleanupRequiredPaths;

  bool get cleanupRequired => cleanupRequiredPaths.isNotEmpty;
}

class LevelDomainPlugin
    implements
        AuthoringDomainPlugin,
        AuthoringSessionSemantics,
        AuthoringHistoryReconciliation,
        AuthoringIntentReconciliation {
  LevelDomainPlugin({
    LevelStore store = const LevelStore(),
    LevelThemeSaveCoordinator? saveCoordinator,
  }) : _store = store,
       _saveCoordinator =
           saveCoordinator ?? LevelThemeSaveCoordinator(levelStore: store);

  static const String pluginId = 'levels';

  final LevelStore _store;
  final LevelThemeSaveCoordinator _saveCoordinator;
  String? _preferredActiveLevelId;

  @override
  String get id => pluginId;

  @override
  AuthoringReapplyPlan planReapply({
    required AuthoringDocument current,
    required AuthoringDocument original,
    required Map<String, AuthoringConflictChoice> resolutions,
  }) => planLevelIntentReapply(
    current: _asLevelDocument(current),
    original: _asLevelDocument(original),
    resolutions: resolutions,
  );

  @override
  AuthoringDocument? restoreContent({
    required AuthoringDocument current,
    required AuthoringDocument historical,
  }) {
    final currentLevels = _asLevelDocument(current);
    final historicalLevels = _asLevelDocument(historical);
    final content = reconcileLevelHistoryContent(
      current: currentLevels,
      historical: historicalLevels,
    );
    if (content == null) return null;
    if (!content.hasChanges) return current;
    final sceneLevels = List<LevelDef>.from(content.levels)
      ..sort(compareLevelDefsForScene);
    final selectedId =
        findLevelDefById(content.levels, currentLevels.activeLevelId) != null
        ? currentLevels.activeLevelId
        : findLevelDefById(content.levels, historicalLevels.activeLevelId) !=
              null
        ? historicalLevels.activeLevelId
        : sceneLevels.firstOrNull?.levelId;
    return _withCandidateState(
      currentLevels.copyWith(
        clearActiveLevelId: selectedId == null,
        parallaxDocument: currentLevels.parallaxDocument?.copyWith(
          clearActiveLevelId: selectedId == null,
        ),
        clearOperationIssues: true,
      ),
      levels: content.levels,
      activeLevelId: selectedId,
      themes: content.themes,
      sessionCreatedThemeIds: content.createdThemeIds,
    );
  }

  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      command.kind == 'set_active_level';

  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) {
    final restoredLevels = _asLevelDocument(restored);
    final currentLevelId = _asLevelDocument(current).activeLevelId;
    final selectedId =
        findLevelDefById(restoredLevels.levels, currentLevelId) != null
        ? currentLevelId
        : restoredLevels.activeLevelId;
    _preferredActiveLevelId = selectedId;
    if (selectedId == restoredLevels.activeLevelId) return restoredLevels;
    return restoredLevels.copyWith(
      activeLevelId: selectedId,
      parallaxDocument: restoredLevels.parallaxDocument?.copyWith(
        activeLevelId: selectedId,
      ),
    );
  }

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
      case 'create_and_assign_theme':
        return _createAndAssignTheme(levelDocument, command.payload);
      case 'copy_assign_theme':
        return _createAndAssignTheme(
          levelDocument,
          command.payload,
          copyLayers: true,
        );
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
    final blockingIssues = validateLevelDocument(levelDocument)
        .where((issue) => issue.blocks(AuthoringOperation.save))
        .toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export levels while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }

    final savePlan = _saveCoordinator.buildSavePlan(
      workspace,
      document: levelDocument,
    );
    if (!savePlan.hasChanges) {
      return LevelThemeExportResult(
        applied: false,
        artifacts: const <ExportArtifact>[
          ExportArtifact(
            title: 'level_summary.md',
            content: '# Level Export\n\nchangedLevels: 0\n\nNo level edits detected.',
          ),
        ],
      );
    }

    final applyResult = _saveCoordinator.apply(
      workspace,
      document: levelDocument,
      savePlan: savePlan,
    );
    return LevelThemeExportResult(
      applied: true,
      cleanupRequiredPaths: applyResult.cleanupRequiredPaths,
      recovery: applyResult.recovery,
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
    final savePlan = _saveCoordinator.buildSavePlan(
      workspace,
      document: levelDocument,
    );
    if (!savePlan.hasChanges) {
      return PendingChanges.empty;
    }
    return PendingChanges(
      changedItemIds: savePlan.changedItemIds,
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
    return _withCandidateState(document, activeLevelId: levelId);
  }

  LevelDefsDocument _createLevel(
    LevelDefsDocument document,
    Map<String, Object?> payload, {
    LevelDef? copySource,
  }) {
    document = _clearOperationIssuesIfNeeded(document);
    final name = _normalizedString(payload['displayName']);
    final levelId = _normalizedString(
      payload['levelId'],
      fallback: name.isEmpty
          ? ''
          : _allocateUniqueLevelId(document.levels, name),
    );
    if (levelId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'create_level_missing_level_id',
        message: 'Enter a name for the new Level.',
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
    final themeMode = _normalizedString(payload['themeMode']);
    if (themeMode != levelThemeModeCreate &&
        themeMode != levelThemeModeExisting &&
        themeMode != levelThemeModeCopy) {
      return _withOperationIssue(
        document,
        code: 'create_level_missing_theme_mode',
        message:
            'Choose whether the new level creates a visual theme or reuses an '
            'existing theme.',
      );
    }
    final createsTheme = themeMode != levelThemeModeExisting;
    final visualThemeId = _normalizedString(
      payload['visualThemeId'],
      fallback: createsTheme ? _allocateUniqueThemeId(document, levelId) : '',
    );
    if (visualThemeId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'create_level_missing_theme_id',
        message: 'Create level requires a non-empty visual theme ID.',
      );
    }
    final initialTheme = payload['createdThemeSnapshot'];
    if (initialTheme != null &&
        (themeMode != levelThemeModeCreate ||
            initialTheme is! ParallaxThemeDef ||
            initialTheme.parallaxThemeId != visualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'create_theme_snapshot_invalid',
        message:
            'A retained background snapshot must name its new theme identity.',
      );
    }
    if (!stableLevelIdentifierPattern.hasMatch(visualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'create_level_invalid_theme_id',
        message:
            'visualThemeId "$visualThemeId" must match '
            '${stableLevelIdentifierPattern.pattern}.',
      );
    }
    if (themeMode == levelThemeModeExisting &&
        !_themeExists(document, visualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'create_level_unknown_existing_theme',
        message:
            'Cannot reuse unknown visual theme "$visualThemeId". Choose an '
            'authored theme or create a new one.',
      );
    }
    ParallaxThemeDef? copiedTheme;
    if (themeMode == levelThemeModeCopy) {
      copiedTheme = findParallaxThemeById(
        document.parallaxDocument?.themes ?? [],
        _normalizedString(payload['sourceVisualThemeId']),
      );
      if (copiedTheme == null) {
        return _withOperationIssue(
          document,
          code: 'copy_theme_source_missing',
          message: 'Choose an existing background to copy.',
        );
      }
    }
    if (createsTheme) {
      final issue = _newThemeIssue(document, visualThemeId);
      if (issue != null) return issue;
    }

    final nextLevel = LevelDef(
      levelId: levelId,
      revision: 1,
      displayName: _normalizedString(
        payload['displayName'],
        fallback: titleCaseLevelId(levelId),
      ),
      visualThemeId: visualThemeId,
      chunkThemeGroups:
          copySource != null && payload['copySectionDesign'] == true
          ? copySource.chunkThemeGroups
          : const <String>[defaultLevelChunkThemeGroupId],
      assembly: copySource != null && payload['copySectionDesign'] == true
          ? copySource.assembly
          : null,
      cameraCenterY: _doubleOrDefault(
        payload['cameraCenterY'],
        fallback: copySource?.cameraCenterY ?? defaultLevelCameraCenterY,
      ),
      groundTopY: _doubleOrDefault(
        payload['groundTopY'],
        fallback: copySource?.groundTopY ?? defaultLevelGroundTopY,
      ),
      earlyPatternChunks: _intOrDefault(
        payload['earlyPatternChunks'],
        fallback: copySource?.earlyPatternChunks ?? defaultEarlyPatternChunks,
      ),
      easyPatternChunks: _intOrDefault(
        payload['easyPatternChunks'],
        fallback: copySource?.easyPatternChunks ?? defaultEasyPatternChunks,
      ),
      normalPatternChunks: _intOrDefault(
        payload['normalPatternChunks'],
        fallback: copySource?.normalPatternChunks ?? defaultNormalPatternChunks,
      ),
      noEnemyChunks: _intOrDefault(
        payload['noEnemyChunks'],
        fallback: copySource?.noEnemyChunks ?? defaultNoEnemyChunks,
      ),
      enumOrdinal: _intOrDefault(
        payload['enumOrdinal'],
        fallback: _nextEnumOrdinal(document.levels),
      ),
      status: levelStatusActive,
      includeInBuild: false,
    ).normalized();

    final nextLevels = List<LevelDef>.from(document.levels)
      ..add(nextLevel)
      ..sort(compareLevelDefsCanonical);
    var nextThemes = document.parallaxDocument?.themes;
    var nextCreatedThemeIds = document.sessionCreatedParallaxThemeIds;
    if (createsTheme) {
      nextThemes = <ParallaxThemeDef>[
        ...document.parallaxDocument!.themes,
        ParallaxThemeDef(
          parallaxThemeId: visualThemeId,
          revision: 1,
          layers:
              (initialTheme as ParallaxThemeDef?)?.layers ??
              copiedTheme?.layers ??
              const <ParallaxLayerDef>[],
        ),
      ]..sort(compareParallaxThemesDeterministic);
      nextCreatedThemeIds = <String>{
        ...document.sessionCreatedParallaxThemeIds,
        visualThemeId,
      };
    }
    final candidate = _withCandidateState(
      document,
      levels: List<LevelDef>.unmodifiable(nextLevels),
      activeLevelId: levelId,
      themes: nextThemes,
      sessionCreatedThemeIds: nextCreatedThemeIds,
    );
    final rejected = _rejectInvalidCompoundCandidate(
      document,
      candidate,
      code: 'create_level_invalid_candidate',
      action: 'create Level "$levelId"',
    );
    if (rejected != null) return rejected;
    _preferredActiveLevelId = levelId;
    return candidate;
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
        _normalizedString(
          payload['displayName'],
          fallback: '${source.levelId}_copy',
        ),
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
    if (payload.containsKey('copySectionDesign') &&
        payload['copySectionDesign'] is! bool) {
      return _withOperationIssue(
        document,
        code: 'duplicate_level_invalid_design_mode',
        message: 'Copy section design must be an explicit boolean.',
      );
    }
    final themeMode = _normalizedString(
      payload['themeMode'],
      fallback: levelThemeModeExisting,
    );
    return _createLevel(document, <String, Object?>{
      ...payload,
      'levelId': requestedLevelId,
      'displayName': _normalizedString(
        payload['displayName'],
        fallback: '${source.displayName} Copy',
      ),
      'themeMode': themeMode,
      'sourceVisualThemeId': _normalizedString(
        payload['sourceVisualThemeId'],
        fallback: source.visualThemeId,
      ),
      if (themeMode == levelThemeModeExisting)
        'visualThemeId': _normalizedString(
          payload['visualThemeId'],
          fallback: source.visualThemeId,
        ),
    }, copySource: source);
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

    final persisted = findLevelDefById(document.baselineLevels, levelId);
    if (persisted != null &&
        _intOrDefault(payload['enumOrdinal'], fallback: source.enumOrdinal) !=
            persisted.enumOrdinal) {
      return _withOperationIssue(
        document,
        code: 'update_level_persisted_ordinal',
        message:
            'Persisted Level "$levelId" must retain ordinal ${persisted.enumOrdinal}.',
      );
    }
    if (payload.containsKey('includeInBuild') &&
        payload['includeInBuild'] is! bool) {
      return _withOperationIssue(
        document,
        code: 'update_level_invalid_build_inclusion',
        message: 'Build inclusion must be an explicit boolean.',
      );
    }
    final requestedVisualThemeId = _normalizedString(
      payload['visualThemeId'],
      fallback: source.visualThemeId,
    );
    if (!_themeExists(document, requestedVisualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'update_level_unknown_theme',
        message:
            'Cannot assign unknown visual theme "$requestedVisualThemeId". '
            'Choose an authored theme or create and assign a new one.',
      );
    }

    final nextLevel = source
        .copyWith(
          displayName: _normalizedString(
            payload['displayName'],
            fallback: source.displayName,
          ),
          visualThemeId: requestedVisualThemeId,
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
          includeInBuild: payload['includeInBuild'] as bool?,
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

  LevelDefsDocument _createAndAssignTheme(
    LevelDefsDocument document,
    Map<String, Object?> payload, {
    bool copyLayers = false,
  }) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    final source = findLevelDefById(document.levels, levelId);
    if (source == null) {
      return _withOperationIssue(
        document,
        code: 'create_assign_theme_missing_level',
        message: 'Cannot assign a theme to unknown levelId "$levelId".',
      );
    }
    final visualThemeId = _normalizedString(
      payload['visualThemeId'],
      fallback: _allocateUniqueThemeId(document, levelId),
    );
    if (visualThemeId.isEmpty ||
        !stableLevelIdentifierPattern.hasMatch(visualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'create_assign_theme_invalid_id',
        message:
            'New visual theme ID must match '
            '${stableLevelIdentifierPattern.pattern}.',
      );
    }
    final issue = _newThemeIssue(document, visualThemeId);
    if (issue != null) return issue;
    final initialTheme = payload['createdThemeSnapshot'];
    if (initialTheme != null &&
        (copyLayers ||
            initialTheme is! ParallaxThemeDef ||
            initialTheme.parallaxThemeId != visualThemeId)) {
      return _withOperationIssue(
        document,
        code: 'create_theme_snapshot_invalid',
        message:
            'A retained background snapshot must name its new theme identity.',
      );
    }
    final copiedTheme = copyLayers
        ? findParallaxThemeById(
            document.parallaxDocument!.themes,
            _normalizedString(payload['sourceVisualThemeId']),
          )
        : null;
    if (copyLayers && copiedTheme == null) {
      return _withOperationIssue(
        document,
        code: 'copy_theme_source_missing',
        message: 'Choose an existing background to copy.',
      );
    }

    final nextLevel = _bumpRevision(
      source.copyWith(visualThemeId: visualThemeId),
      fromLevel: source,
    );
    final nextLevels = document.levels
        .map((level) => level.levelId == levelId ? nextLevel : level)
        .toList(growable: false);
    final nextThemes = <ParallaxThemeDef>[
      ...document.parallaxDocument!.themes,
      ParallaxThemeDef(
        parallaxThemeId: visualThemeId,
        revision: 1,
        layers:
            (initialTheme as ParallaxThemeDef?)?.layers ??
            copiedTheme?.layers ??
            const <ParallaxLayerDef>[],
      ),
    ]..sort(compareParallaxThemesDeterministic);
    final candidate = _withCandidateState(
      document,
      levels: nextLevels,
      themes: nextThemes,
      sessionCreatedThemeIds: <String>{
        ...document.sessionCreatedParallaxThemeIds,
        visualThemeId,
      },
    );
    return _rejectInvalidCompoundCandidate(
          document,
          candidate,
          code: 'create_assign_theme_invalid_candidate',
          action: 'create and assign visual theme "$visualThemeId"',
        ) ??
        candidate;
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
    return _withCandidateState(
      document,
      levels: List<LevelDef>.unmodifiable(nextLevels),
    );
  }

  LevelDefsDocument? _newThemeIssue(
    LevelDefsDocument document,
    String visualThemeId,
  ) {
    final parallaxDocument = document.parallaxDocument;
    if (parallaxDocument == null) {
      return _withOperationIssue(
        document,
        code: 'create_theme_source_unavailable',
        message:
            'Parallax source is unavailable. Reload a valid workspace before '
            'creating a visual theme.',
      );
    }
    if (parallaxDocument.loadIssues.any(
      (issue) => issue.blocks(AuthoringOperation.save),
    )) {
      return _withOperationIssue(
        document,
        code: 'create_theme_source_invalid',
        message:
            'Parallax source has blocking validation issues. Resolve them '
            'before creating a visual theme.',
      );
    }
    if (findParallaxThemeById(parallaxDocument.themes, visualThemeId) != null ||
        findParallaxThemeById(parallaxDocument.baselineThemes, visualThemeId) !=
            null) {
      return _withOperationIssue(
        document,
        code: 'create_theme_id_collision',
        message:
            'Visual theme "$visualThemeId" already exists. Choose Use existing '
            'theme to reuse it.',
      );
    }
    final symbol = generatedParallaxThemeSymbolSuffix(visualThemeId);
    for (final theme in parallaxDocument.themes) {
      if (generatedParallaxThemeSymbolSuffix(theme.parallaxThemeId) == symbol) {
        return _withOperationIssue(
          document,
          code: 'create_theme_generated_symbol_collision',
          message:
              'Visual theme "$visualThemeId" would generate the same Dart '
              'symbol as "${theme.parallaxThemeId}".',
        );
      }
    }
    return null;
  }

  bool _themeExists(LevelDefsDocument document, String visualThemeId) {
    final parallaxDocument = document.parallaxDocument;
    if (parallaxDocument != null) {
      return findParallaxThemeById(parallaxDocument.themes, visualThemeId) !=
          null;
    }
    return document.availableParallaxVisualThemeIds.contains(visualThemeId);
  }

  LevelDefsDocument? _rejectInvalidCompoundCandidate(
    LevelDefsDocument source,
    LevelDefsDocument candidate, {
    required String code,
    required String action,
  }) {
    final blockingCodes =
        validateLevelDocument(candidate)
            .where((issue) => issue.blocks(AuthoringOperation.save))
            .map((issue) => issue.code)
            .toSet()
            .toList()
          ..sort();
    if (blockingCodes.isEmpty) return null;
    return _withOperationIssue(
      source,
      code: code,
      message:
          'Cannot $action because the complete Level/theme candidate has '
          'blocking issue(s): ${blockingCodes.join(', ')}.',
    );
  }

  LevelDefsDocument _withCandidateState(
    LevelDefsDocument document, {
    List<LevelDef>? levels,
    String? activeLevelId,
    List<ParallaxThemeDef>? themes,
    Set<String>? sessionCreatedThemeIds,
  }) {
    final nextLevels = List<LevelDef>.from(levels ?? document.levels)
      ..sort(compareLevelDefsCanonical);
    final nextActiveLevelId = activeLevelId ?? document.activeLevelId;
    final parallaxDocument = document.parallaxDocument;
    if (parallaxDocument == null) {
      return document.copyWith(
        levels: List<LevelDef>.unmodifiable(nextLevels),
        activeLevelId: nextActiveLevelId,
      );
    }

    final usedThemeIds = nextLevels.map((level) => level.visualThemeId).toSet();
    final requestedCreatedIds = Set<String>.from(
      sessionCreatedThemeIds ?? document.sessionCreatedParallaxThemeIds,
    );
    final retainedCreatedIds = requestedCreatedIds.intersection(usedThemeIds);
    final nextThemes =
        List<ParallaxThemeDef>.from(themes ?? parallaxDocument.themes)
          ..removeWhere(
            (theme) =>
                requestedCreatedIds.contains(theme.parallaxThemeId) &&
                !retainedCreatedIds.contains(theme.parallaxThemeId),
          );
    nextThemes.sort(compareParallaxThemesDeterministic);
    final availableThemeIds =
        nextThemes.map((theme) => theme.parallaxThemeId).toList(growable: false)
          ..sort();
    final levelIds =
        nextLevels.map((level) => level.levelId).toList(growable: false)
          ..sort();
    final themeIdByLevelId = <String, String>{
      for (final level in nextLevels) level.levelId: level.visualThemeId,
    };
    final nextParallaxDocument = parallaxDocument.copyWith(
      themes: List<ParallaxThemeDef>.unmodifiable(nextThemes),
      availableLevelIds: List<String>.unmodifiable(levelIds),
      activeLevelId: nextActiveLevelId,
      levelOptionSource: 'level_workflow_candidate',
      parallaxThemeIdByLevelId: Map<String, String>.unmodifiable(
        themeIdByLevelId,
      ),
    );
    return document.copyWith(
      levels: List<LevelDef>.unmodifiable(nextLevels),
      activeLevelId: nextActiveLevelId,
      availableParallaxVisualThemeIds: List<String>.unmodifiable(
        availableThemeIds,
      ),
      parallaxThemeSourceAvailable: parallaxDocument.baseline != null,
      parallaxDocument: nextParallaxDocument,
      sessionCreatedParallaxThemeIds: Set<String>.unmodifiable(
        retainedCreatedIds,
      ),
    );
  }

  String _buildSummary(LevelThemeSavePlan savePlan) {
    final lines = <String>[
      '# Level And Visual Theme Export',
      '',
      'changedItems: ${savePlan.changedItemIds.length}',
      'changedFiles: ${savePlan.writes.length}',
      '',
      '## Items',
      ...savePlan.changedItemIds.map((itemId) => '- $itemId'),
      '',
      '## Files',
      ...savePlan.writes.map((write) => '- ${write.relativePath}'),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(LevelThemeFileWrite write) {
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

String _allocateUniqueThemeId(LevelDefsDocument document, String seed) {
  final claimed = <String>{
    ...document.availableParallaxVisualThemeIds,
    ...?document.parallaxDocument?.themes.map((theme) => theme.parallaxThemeId),
  };
  final symbols = claimed.map(generatedParallaxThemeSymbolSuffix).toSet();
  final base = _slugifyLevelId(seed, fallback: 'background');
  var candidate = base;
  var suffix = 2;
  while (claimed.contains(candidate) ||
      symbols.contains(generatedParallaxThemeSymbolSuffix(candidate))) {
    candidate = '${base}_${suffix++}';
  }
  return candidate;
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

List<String> _parseChunkThemeGroups(
  Object? raw, {
  required List<String> fallback,
}) {
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
    final difficultyRaw = rawSegment['difficulty'];
    final difficulty = ChunkPatternTier.values
        .where((tier) => tier.name == difficultyRaw)
        .firstOrNull;
    if (rawSegment.containsKey('difficulty') && difficulty == null) {
      return _AssemblyPayloadParseResult(
        issueMessage:
            'assembly.segments[$i].difficulty must be early, easy, normal, or hard.',
      );
    }
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
        difficulty: difficulty,
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
