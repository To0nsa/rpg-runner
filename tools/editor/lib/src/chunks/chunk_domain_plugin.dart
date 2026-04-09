import '../domain/authoring_types.dart';
import '../prefabs/models/models.dart';
import '../prefabs/store/prefab_store.dart';
import '../workspace/editor_workspace.dart';
import 'chunk_domain_models.dart';
import 'chunk_store.dart';
import 'chunk_validation.dart';

class ChunkDomainPlugin implements AuthoringDomainPlugin {
  ChunkDomainPlugin({
    ChunkStore store = const ChunkStore(),
    PrefabStore prefabStore = const PrefabStore(),
  }) : _store = store,
       _prefabStore = prefabStore;

  static const String pluginId = 'chunks';
  final ChunkStore _store;
  final PrefabStore _prefabStore;
  String? _preferredActiveLevelId;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    var loaded = await _store.load(
      workspace,
      preferredActiveLevelId: _preferredActiveLevelId,
    );
    try {
      loaded = loaded.copyWith(
        prefabData: await _prefabStore.load(workspace.rootPath),
      );
    } on Object catch (error) {
      final nextLoadIssues = List<ValidationIssue>.from(loaded.loadIssues)
        ..add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'prefab_catalog_load_failed',
            message: 'Failed to load prefab catalog for chunk editing: $error',
            sourcePath: PrefabStore.prefabDefsPath,
          ),
        );
      loaded = loaded.copyWith(
        prefabData: const PrefabData(),
        loadIssues: List<ValidationIssue>.unmodifiable(nextLoadIssues),
      );
    }
    _preferredActiveLevelId = loaded.activeLevelId;
    return loaded;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final chunkDocument = _asChunkDocument(document);
    final scoped = _scopeDocumentToActiveLevel(chunkDocument);
    return validateChunkDocument(scoped);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final chunkDocument = _asChunkDocument(document);
    final scopedDocument = _scopeDocumentToActiveLevel(chunkDocument);
    final sortedChunks = List<LevelChunkDef>.from(scopedDocument.chunks)
      ..sort(_compareChunksForScene);
    final sourcePathByChunkKey = <String, String>{};
    for (final entry in scopedDocument.baselineByChunkKey.entries) {
      sourcePathByChunkKey[entry.key] = entry.value.sourcePath;
    }
    return ChunkScene(
      chunks: List<LevelChunkDef>.unmodifiable(sortedChunks),
      availableLevelIds: chunkDocument.availableLevelIds,
      activeLevelId: chunkDocument.activeLevelId,
      levelOptionSource: chunkDocument.levelOptionSource,
      sourcePathByChunkKey: Map<String, String>.unmodifiable(
        sourcePathByChunkKey,
      ),
      runtimeGridSnap: chunkDocument.runtimeGridSnap,
      runtimeChunkWidth: chunkDocument.runtimeChunkWidth,
      lockedChunkHeight: chunkDocument.lockedChunkHeight,
      runtimeGroundTopY: chunkDocument.runtimeGroundTopY,
      prefabData: chunkDocument.prefabData,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final chunkDocument = _asChunkDocument(document);
    switch (command.kind) {
      case 'set_active_level':
        return _setActiveLevel(chunkDocument, command.payload);
      case 'create_chunk':
        return _createChunk(chunkDocument, command.payload);
      case 'duplicate_chunk':
        return _duplicateChunk(chunkDocument, command.payload);
      case 'rename_chunk':
        return _renameChunk(chunkDocument, command.payload);
      case 'deprecate_chunk':
        return _deprecateChunk(chunkDocument, command.payload);
      case 'update_chunk_metadata':
        return _updateChunkMetadata(chunkDocument, command.payload);
      case 'update_ground_profile':
        return _updateGroundProfile(chunkDocument, command.payload);
      case 'add_ground_gap':
        return _addGroundGap(chunkDocument, command.payload);
      case 'update_ground_gap':
        return _updateGroundGap(chunkDocument, command.payload);
      case 'remove_ground_gap':
        return _removeGroundGap(chunkDocument, command.payload);
      case 'add_prefab_placement':
        return _addPrefabPlacement(chunkDocument, command.payload);
      case 'move_prefab_placement':
        return _movePrefabPlacement(chunkDocument, command.payload);
      case 'replace_prefab_placement':
        return _replacePrefabPlacement(chunkDocument, command.payload);
      case 'update_prefab_placement_settings':
        return _updatePrefabPlacementSettings(chunkDocument, command.payload);
      case 'remove_prefab_placement':
        return _removePrefabPlacement(chunkDocument, command.payload);
      default:
        return _clearOperationIssuesIfNeeded(chunkDocument);
    }
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final chunkDocument = _asChunkDocument(document);
    final scopedDocument = _scopeDocumentToActiveLevel(chunkDocument);
    final blockingIssues = validateChunkDocument(
      scopedDocument,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export chunks while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }

    final savePlan = _store.buildSavePlan(workspace, document: scopedDocument);
    if (!savePlan.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: <ExportArtifact>[
          ExportArtifact(
            title: 'chunk_summary.md',
            content:
                '# Chunk Export\n\nchangedChunks: 0\n\nNo chunk edits detected.',
          ),
        ],
      );
    }

    await _store.save(workspace, document: scopedDocument, savePlan: savePlan);
    final summary = _buildSummary(savePlan);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(title: 'chunk_summary.md', content: summary),
      ],
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final chunkDocument = _asChunkDocument(document);
    final scopedDocument = _scopeDocumentToActiveLevel(chunkDocument);
    final savePlan = _store.buildSavePlan(workspace, document: scopedDocument);
    if (!savePlan.hasChanges) {
      return PendingChanges.empty;
    }
    final fileDiffs = savePlan.writes
        .map(
          (write) => PendingFileDiff(
            relativePath: write.relativePath,
            editCount: 1,
            unifiedDiff: _buildUnifiedDiff(write),
          ),
        )
        .toList(growable: false);

    return PendingChanges(
      changedItemIds: savePlan.changedChunkKeys,
      fileDiffs: fileDiffs,
    );
  }

  ChunkDocument _setActiveLevel(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final levelId = _normalizedString(payload['levelId']);
    if (levelId.isEmpty || !document.availableLevelIds.contains(levelId)) {
      return _withOperationIssue(
        document,
        code: 'set_active_level_invalid',
        message:
            'Cannot set active level to "$levelId". Choose a known level option.',
      );
    }
    if (levelId == document.activeLevelId) {
      return document;
    }
    _preferredActiveLevelId = levelId;
    return document.copyWith(activeLevelId: levelId);
  }

  ChunkDocument _createChunk(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final existingIds = document.chunks.map((chunk) => chunk.id).toSet();
    final existingKeys = document.chunks.map((chunk) => chunk.chunkKey).toSet();

    final requestedId = _normalizedString(payload['id']);
    if (requestedId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'create_chunk_missing_id',
        message: 'Create chunk requires a non-empty id.',
      );
    }
    if (existingIds.contains(requestedId)) {
      return _withOperationIssue(
        document,
        code: 'create_chunk_id_collision',
        message: 'Cannot create chunk. id "$requestedId" already exists.',
      );
    }
    final newId = requestedId;
    final newChunkKey = _allocateUniqueChunkKey(existingKeys, requestedId);
    final activeLevelId =
        document.activeLevelId ??
        (document.availableLevelIds.isEmpty
            ? ''
            : document.availableLevelIds.first);

    final defaultTileSize = document.runtimeGridSnap.round();
    final chunk = normalizeChunkToAuthority(
      LevelChunkDef(
        chunkKey: newChunkKey,
        id: newId,
        revision: 1,
        schemaVersion: chunkSchemaVersion,
        levelId: activeLevelId,
        tileSize: defaultTileSize <= 0 ? 16 : defaultTileSize,
        width: document.runtimeChunkWidth.round(),
        height: document.lockedChunkHeight,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(
          kind: groundProfileKindFlat,
          topY: document.runtimeGroundTopY,
        ),
        groundGaps: const <GroundGapDef>[],
        tileLayers: const <TileLayerDef>[],
        prefabs: const <PlacedPrefabDef>[],
        markers: const <PlacedMarkerDef>[],
        tags: const <String>[],
        status: chunkStatusActive,
      ).normalized(),
      runtimeChunkWidth: document.runtimeChunkWidth,
      lockedChunkHeight: document.lockedChunkHeight,
      runtimeGroundTopY: document.runtimeGroundTopY,
    );

    final nextChunks = List<LevelChunkDef>.from(document.chunks)..add(chunk);
    return document.copyWith(chunks: nextChunks);
  }

  ChunkDocument _duplicateChunk(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final sourceChunkKey = _normalizedString(payload['chunkKey']);
    if (sourceChunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'duplicate_chunk_missing_source',
        message: 'Duplicate chunk requires source chunkKey.',
      );
    }
    final source = _findChunkByKey(document, sourceChunkKey);
    if (source == null) {
      return _withOperationIssue(
        document,
        code: 'duplicate_chunk_missing_source',
        message: 'Cannot duplicate unknown chunkKey "$sourceChunkKey".',
        chunkKey: sourceChunkKey,
      );
    }

    final existingIds = document.chunks.map((chunk) => chunk.id).toSet();
    final existingKeys = document.chunks.map((chunk) => chunk.chunkKey).toSet();
    final requestedId = _normalizedString(
      payload['id'],
      fallback: '${source.id}_copy',
    );
    if (existingIds.contains(requestedId)) {
      return _withOperationIssue(
        document,
        code: 'duplicate_chunk_id_collision',
        message:
            'Cannot duplicate chunk "${source.id}". Target id "$requestedId" already exists.',
        chunkKey: sourceChunkKey,
      );
    }
    final newId = requestedId;
    final newChunkKey = _allocateUniqueChunkKey(existingKeys, source.id);
    final duplicated = source
        .copyWith(
          chunkKey: newChunkKey,
          id: newId,
          revision: 1,
          status: chunkStatusActive,
        )
        .normalized();
    final lockedDuplicate = _normalizeChunkToDocumentAuthority(
      duplicated,
      document,
    );

    final nextChunks = List<LevelChunkDef>.from(document.chunks)
      ..add(lockedDuplicate);
    return document.copyWith(chunks: nextChunks);
  }

  ChunkDocument _renameChunk(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final nextId = _normalizedString(payload['id']);
    if (chunkKey.isEmpty || nextId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'rename_chunk_invalid_payload',
        message: 'Rename chunk requires chunkKey and non-empty target id.',
        chunkKey: chunkKey,
      );
    }

    final target = _findChunkByKey(document, chunkKey);
    if (target == null) {
      return _withOperationIssue(
        document,
        code: 'rename_chunk_missing_source',
        message: 'Cannot rename unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    if (target.id == nextId) {
      return document;
    }
    final idTakenByOther = document.chunks.any(
      (chunk) => chunk.id == nextId && chunk.chunkKey != chunkKey,
    );
    if (idTakenByOther) {
      return _withOperationIssue(
        document,
        code: 'rename_chunk_id_collision',
        message: 'Cannot rename chunk to "$nextId". id already exists.',
        chunkKey: chunkKey,
      );
    }

    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) => chunk.copyWith(id: nextId).normalized(),
    );
  }

  ChunkDocument _deprecateChunk(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    if (chunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'deprecate_chunk_invalid_payload',
        message: 'Deprecate chunk requires chunkKey.',
      );
    }
    if (_findChunkByKey(document, chunkKey) == null) {
      return _withOperationIssue(
        document,
        code: 'deprecate_chunk_missing_source',
        message: 'Cannot deprecate unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        if (chunk.status == chunkStatusDeprecated) {
          return chunk;
        }
        return _bumpRevision(
          chunk.copyWith(status: chunkStatusDeprecated).normalized(),
        );
      },
    );
  }

  ChunkDocument _updateChunkMetadata(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    if (chunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'update_chunk_metadata_invalid_payload',
        message: 'Update metadata requires chunkKey.',
      );
    }
    final target = _findChunkByKey(document, chunkKey);
    if (target == null) {
      return _withOperationIssue(
        document,
        code: 'update_chunk_metadata_missing_source',
        message: 'Cannot update metadata for unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final requestedId = _normalizedString(payload['id'], fallback: target.id);
    final idTakenByOther = document.chunks.any(
      (entry) => entry.id == requestedId && entry.chunkKey != chunkKey,
    );
    if (idTakenByOther) {
      return _withOperationIssue(
        document,
        code: 'update_chunk_metadata_id_collision',
        message: 'Cannot update metadata. id "$requestedId" already exists.',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        final resolvedId = _normalizedString(payload['id'], fallback: chunk.id);
        final resolvedTags = _parseTags(payload['tags'], fallback: chunk.tags);
        final nextChunk = _normalizeChunkToDocumentAuthority(
          chunk
              .copyWith(
                id: resolvedId,
                levelId: _normalizedString(
                  payload['levelId'],
                  fallback: chunk.levelId,
                ),
                tileSize: _intOrDefault(
                  payload['tileSize'],
                  fallback: chunk.tileSize,
                ),
                width: document.runtimeChunkWidth.round(),
                height: document.lockedChunkHeight,
                difficulty: _normalizedString(
                  payload['difficulty'],
                  fallback: chunk.difficulty,
                ),
                tags: resolvedTags,
                status: _normalizedString(
                  payload['status'],
                  fallback: chunk.status,
                ),
              )
              .normalized(),
          document,
        );
        if (_chunkEqualsWithoutRevision(nextChunk, chunk)) {
          return chunk;
        }
        return _bumpRevision(nextChunk);
      },
    );
  }

  ChunkDocument _updateGroundProfile(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    if (chunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'update_ground_profile_invalid_payload',
        message: 'Update ground profile requires chunkKey.',
      );
    }
    if (_findChunkByKey(document, chunkKey) == null) {
      return _withOperationIssue(
        document,
        code: 'update_ground_profile_missing_source',
        message:
            'Cannot update ground profile for unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        final nextProfile = GroundProfileDef(
          kind: groundProfileKindFlat,
          topY: document.runtimeGroundTopY,
        );
        if (nextProfile.kind == chunk.groundProfile.kind &&
            nextProfile.topY == chunk.groundProfile.topY) {
          return chunk;
        }
        return _bumpRevision(
          _normalizeChunkToDocumentAuthority(
            chunk.copyWith(groundProfile: nextProfile).normalized(),
            document,
          ),
        );
      },
    );
  }

  ChunkDocument _addGroundGap(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    if (chunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'add_ground_gap_invalid_payload',
        message: 'Add ground gap requires chunkKey.',
      );
    }
    if (_findChunkByKey(document, chunkKey) == null) {
      return _withOperationIssue(
        document,
        code: 'add_ground_gap_missing_source',
        message: 'Cannot add gap to unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        final existingIds = chunk.groundGaps.map((gap) => gap.gapId).toSet();
        final requestedGapId = _normalizedString(
          payload['gapId'],
          fallback: 'gap_${chunk.groundGaps.length + 1}',
        );
        final gapId = _allocateUniqueGapId(existingIds, requestedGapId);
        final gap = GroundGapDef(
          gapId: gapId,
          type: _normalizedString(payload['type'], fallback: groundGapTypePit),
          x: _intOrDefault(payload['x'], fallback: 0),
          width: _intOrDefault(
            payload['width'],
            fallback: document.runtimeGridSnap.round(),
          ),
        );
        final nextGaps = List<GroundGapDef>.from(chunk.groundGaps)..add(gap);
        return _bumpRevision(chunk.copyWith(groundGaps: nextGaps).normalized());
      },
    );
  }

  ChunkDocument _updateGroundGap(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final gapId = _normalizedString(payload['gapId']);
    if (chunkKey.isEmpty || gapId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'update_ground_gap_invalid_payload',
        message: 'Update ground gap requires chunkKey and gapId.',
        chunkKey: chunkKey,
      );
    }
    if (_findChunkByKey(document, chunkKey) == null) {
      return _withOperationIssue(
        document,
        code: 'update_ground_gap_missing_source',
        message: 'Cannot update gap for unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final target = _findChunkByKey(document, chunkKey)!;
    if (!target.groundGaps.any((gap) => gap.gapId == gapId)) {
      return _withOperationIssue(
        document,
        code: 'update_ground_gap_missing_gap',
        message: 'Cannot update unknown gapId "$gapId" in chunk "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        var changed = false;
        final nextGaps = chunk.groundGaps
            .map((gap) {
              if (gap.gapId != gapId) {
                return gap;
              }
              final nextGap = gap.copyWith(
                type: _normalizedString(payload['type'], fallback: gap.type),
                x: _intOrDefault(payload['x'], fallback: gap.x),
                width: _intOrDefault(payload['width'], fallback: gap.width),
              );
              if (nextGap.type != gap.type ||
                  nextGap.x != gap.x ||
                  nextGap.width != gap.width) {
                changed = true;
              }
              return nextGap;
            })
            .toList(growable: false);
        if (!changed) {
          return chunk;
        }
        return _bumpRevision(chunk.copyWith(groundGaps: nextGaps).normalized());
      },
    );
  }

  ChunkDocument _removeGroundGap(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final gapId = _normalizedString(payload['gapId']);
    if (chunkKey.isEmpty || gapId.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'remove_ground_gap_invalid_payload',
        message: 'Remove ground gap requires chunkKey and gapId.',
        chunkKey: chunkKey,
      );
    }
    if (_findChunkByKey(document, chunkKey) == null) {
      return _withOperationIssue(
        document,
        code: 'remove_ground_gap_missing_source',
        message: 'Cannot remove gap from unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        final nextGaps = chunk.groundGaps
            .where((gap) => gap.gapId != gapId)
            .toList(growable: false);
        if (nextGaps.length == chunk.groundGaps.length) {
          return chunk;
        }
        return _bumpRevision(chunk.copyWith(groundGaps: nextGaps).normalized());
      },
    );
  }

  ChunkDocument _addPrefabPlacement(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    if (chunkKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'add_prefab_placement_invalid_payload',
        message: 'Add prefab placement requires chunkKey.',
      );
    }
    final targetChunk = _findChunkByKey(document, chunkKey);
    if (targetChunk == null) {
      return _withOperationIssue(
        document,
        code: 'add_prefab_placement_missing_source',
        message: 'Cannot add prefab placement to unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }

    final resolvedPrefab = _resolvePlaceablePrefab(
      document,
      prefabKey: _normalizedString(payload['prefabKey']),
      prefabId: _normalizedString(payload['prefabId']),
    );
    if (resolvedPrefab == null) {
      return _withOperationIssue(
        document,
        code: 'add_prefab_placement_unknown_prefab',
        message: 'Add prefab placement requires a known active prefab.',
        chunkKey: chunkKey,
      );
    }

    final nextPlacement = PlacedPrefabDef(
      prefabId: resolvedPrefab.id,
      prefabKey: resolvedPrefab.prefabKey,
      x: _intOrDefault(payload['x'], fallback: 0),
      y: _intOrDefault(payload['y'], fallback: 0),
      zIndex: _intOrDefault(payload['zIndex'], fallback: 0),
      snapToGrid: _boolOrDefault(payload['snapToGrid'], fallback: true),
    );
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (chunk) {
        final nextPrefabs = List<PlacedPrefabDef>.from(chunk.prefabs)
          ..add(nextPlacement);
        return _bumpRevision(chunk.copyWith(prefabs: nextPrefabs).normalized());
      },
    );
  }

  ChunkDocument _movePrefabPlacement(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final selectionKey = _normalizedString(payload['selectionKey']);
    if (chunkKey.isEmpty || selectionKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'move_prefab_placement_invalid_payload',
        message: 'Move prefab placement requires chunkKey and selectionKey.',
        chunkKey: chunkKey,
      );
    }
    final chunk = _findChunkByKey(document, chunkKey);
    if (chunk == null) {
      return _withOperationIssue(
        document,
        code: 'move_prefab_placement_missing_source',
        message:
            'Cannot move prefab placement in unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final targetIndex = _findPrefabPlacementIndexBySelectionKey(
      chunk,
      selectionKey,
    );
    if (targetIndex < 0) {
      return _withOperationIssue(
        document,
        code: 'move_prefab_placement_missing_target',
        message:
            'Cannot move unknown prefab placement "$selectionKey" in "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final nextX = _intOrDefault(
      payload['x'],
      fallback: chunk.prefabs[targetIndex].x,
    );
    final nextY = _intOrDefault(
      payload['y'],
      fallback: chunk.prefabs[targetIndex].y,
    );
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (entry) {
        final current = entry.prefabs[targetIndex];
        if (current.x == nextX && current.y == nextY) {
          return entry;
        }
        final nextPrefabs = List<PlacedPrefabDef>.from(entry.prefabs);
        nextPrefabs[targetIndex] = current.copyWith(x: nextX, y: nextY);
        return _bumpRevision(entry.copyWith(prefabs: nextPrefabs).normalized());
      },
    );
  }

  ChunkDocument _replacePrefabPlacement(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final selectionKey = _normalizedString(payload['selectionKey']);
    if (chunkKey.isEmpty || selectionKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'replace_prefab_placement_invalid_payload',
        message: 'Replace prefab placement requires chunkKey and selectionKey.',
        chunkKey: chunkKey,
      );
    }
    final chunk = _findChunkByKey(document, chunkKey);
    if (chunk == null) {
      return _withOperationIssue(
        document,
        code: 'replace_prefab_placement_missing_source',
        message:
            'Cannot replace prefab placement in unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final targetIndex = _findPrefabPlacementIndexBySelectionKey(
      chunk,
      selectionKey,
    );
    if (targetIndex < 0) {
      return _withOperationIssue(
        document,
        code: 'replace_prefab_placement_missing_target',
        message:
            'Cannot replace unknown prefab placement "$selectionKey" in "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final resolvedPrefab = _resolvePlaceablePrefab(
      document,
      prefabKey: _normalizedString(payload['prefabKey']),
      prefabId: _normalizedString(payload['prefabId']),
    );
    if (resolvedPrefab == null) {
      return _withOperationIssue(
        document,
        code: 'replace_prefab_placement_unknown_prefab',
        message: 'Replace prefab placement requires a known active prefab.',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (entry) {
        final current = entry.prefabs[targetIndex];
        if (current.prefabKey == resolvedPrefab.prefabKey &&
            current.prefabId == resolvedPrefab.id) {
          return entry;
        }
        final nextPrefabs = List<PlacedPrefabDef>.from(entry.prefabs);
        nextPrefabs[targetIndex] = current.copyWith(
          prefabKey: resolvedPrefab.prefabKey,
          prefabId: resolvedPrefab.id,
        );
        return _bumpRevision(entry.copyWith(prefabs: nextPrefabs).normalized());
      },
    );
  }

  ChunkDocument _updatePrefabPlacementSettings(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final selectionKey = _normalizedString(payload['selectionKey']);
    if (chunkKey.isEmpty || selectionKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'update_prefab_placement_settings_invalid_payload',
        message:
            'Update prefab placement settings requires chunkKey and selectionKey.',
        chunkKey: chunkKey,
      );
    }
    final chunk = _findChunkByKey(document, chunkKey);
    if (chunk == null) {
      return _withOperationIssue(
        document,
        code: 'update_prefab_placement_settings_missing_source',
        message:
            'Cannot update prefab placement settings in unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final targetIndex = _findPrefabPlacementIndexBySelectionKey(
      chunk,
      selectionKey,
    );
    if (targetIndex < 0) {
      return _withOperationIssue(
        document,
        code: 'update_prefab_placement_settings_missing_target',
        message:
            'Cannot update unknown prefab placement settings for "$selectionKey" in "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final currentTarget = chunk.prefabs[targetIndex];
    final nextZIndex = _intOrDefault(
      payload['zIndex'],
      fallback: currentTarget.zIndex,
    );
    final nextSnapToGrid = _boolOrDefault(
      payload['snapToGrid'],
      fallback: currentTarget.snapToGrid,
    );
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (entry) {
        final current = entry.prefabs[targetIndex];
        if (current.snapToGrid == nextSnapToGrid &&
            current.zIndex == nextZIndex) {
          return entry;
        }
        final nextPrefabs = List<PlacedPrefabDef>.from(entry.prefabs);
        nextPrefabs[targetIndex] = current.copyWith(
          zIndex: nextZIndex,
          snapToGrid: nextSnapToGrid,
        );
        return _bumpRevision(entry.copyWith(prefabs: nextPrefabs).normalized());
      },
    );
  }

  ChunkDocument _removePrefabPlacement(
    ChunkDocument document,
    Map<String, Object?> payload,
  ) {
    document = _clearOperationIssuesIfNeeded(document);
    final chunkKey = _normalizedString(payload['chunkKey']);
    final selectionKey = _normalizedString(payload['selectionKey']);
    if (chunkKey.isEmpty || selectionKey.isEmpty) {
      return _withOperationIssue(
        document,
        code: 'remove_prefab_placement_invalid_payload',
        message: 'Remove prefab placement requires chunkKey and selectionKey.',
        chunkKey: chunkKey,
      );
    }
    final chunk = _findChunkByKey(document, chunkKey);
    if (chunk == null) {
      return _withOperationIssue(
        document,
        code: 'remove_prefab_placement_missing_source',
        message:
            'Cannot remove prefab placement from unknown chunkKey "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    final targetIndex = _findPrefabPlacementIndexBySelectionKey(
      chunk,
      selectionKey,
    );
    if (targetIndex < 0) {
      return _withOperationIssue(
        document,
        code: 'remove_prefab_placement_missing_target',
        message:
            'Cannot remove unknown prefab placement "$selectionKey" in "$chunkKey".',
        chunkKey: chunkKey,
      );
    }
    return _mapChunkByKey(
      document,
      chunkKey: chunkKey,
      mapper: (entry) {
        final nextPrefabs = List<PlacedPrefabDef>.from(entry.prefabs)
          ..removeAt(targetIndex);
        return _bumpRevision(entry.copyWith(prefabs: nextPrefabs).normalized());
      },
    );
  }

  ChunkDocument _mapChunkByKey(
    ChunkDocument document, {
    required String chunkKey,
    required LevelChunkDef Function(LevelChunkDef chunk) mapper,
  }) {
    var changed = false;
    final nextChunks = document.chunks
        .map((chunk) {
          if (chunk.chunkKey != chunkKey) {
            return chunk;
          }
          final mapped = mapper(chunk);
          if (!identical(mapped, chunk) && !_chunkEquals(mapped, chunk)) {
            changed = true;
          }
          return mapped;
        })
        .toList(growable: false);

    if (!changed) {
      return document;
    }
    return document.copyWith(chunks: nextChunks);
  }

  LevelChunkDef? _findChunkByKey(ChunkDocument document, String chunkKey) {
    for (final chunk in document.chunks) {
      if (chunk.chunkKey == chunkKey) {
        return chunk;
      }
    }
    return null;
  }

  int _findPrefabPlacementIndexBySelectionKey(
    LevelChunkDef chunk,
    String selectionKey,
  ) {
    final selections = buildChunkPlacedPrefabSelections(chunk.prefabs);
    for (var i = 0; i < selections.length; i += 1) {
      if (selections[i].selectionKey == selectionKey) {
        return i;
      }
    }
    return -1;
  }

  PrefabDef? _resolvePlaceablePrefab(
    ChunkDocument document, {
    required String prefabKey,
    required String prefabId,
  }) {
    PrefabDef? matched;
    for (final prefab in document.prefabData.prefabs) {
      final matchesKey = prefabKey.isNotEmpty && prefab.prefabKey == prefabKey;
      final matchesId = prefabId.isNotEmpty && prefab.id == prefabId;
      if (!matchesKey && !matchesId) {
        continue;
      }
      matched = prefab;
      if (matchesKey) {
        break;
      }
    }
    if (matched == null || matched.status != PrefabStatus.active) {
      return null;
    }
    return matched;
  }

  String _buildSummary(ChunkSavePlan savePlan) {
    final lines = <String>[
      '# Chunk Export',
      '',
      'changedChunks: ${savePlan.changedChunkKeys.length}',
      'changedFiles: ${savePlan.writes.length}',
      '',
      '## Files',
      ...savePlan.writes.map(
        (write) => '- ${write.relativePath} (${write.chunkId})',
      ),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(ChunkFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final before = write.beforeContent ?? '';
    final after = write.afterContent;
    final beforeLines = _splitLines(before);
    final afterLines = _splitLines(after);
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

  ChunkDocument _clearOperationIssuesIfNeeded(ChunkDocument document) {
    if (document.operationIssues.isEmpty) {
      return document;
    }
    return document.copyWith(clearOperationIssues: true);
  }

  ChunkDocument _scopeDocumentToActiveLevel(ChunkDocument document) {
    final activeLevelId = document.activeLevelId;
    if (activeLevelId == null || activeLevelId.isEmpty) {
      if (document.chunks.isEmpty && document.baselineByChunkKey.isEmpty) {
        return document;
      }
      return document.copyWith(
        chunks: const <LevelChunkDef>[],
        baselineByChunkKey: const <String, ChunkSourceBaseline>{},
      );
    }

    final scopedChunks = document.chunks
        .where((chunk) => chunk.levelId == activeLevelId)
        .toList(growable: false);
    final scopedBaselines = <String, ChunkSourceBaseline>{};
    for (final chunk in scopedChunks) {
      final baseline = document.baselineByChunkKey[chunk.chunkKey];
      if (baseline != null) {
        scopedBaselines[chunk.chunkKey] = baseline;
      }
    }

    if (scopedChunks.length == document.chunks.length &&
        scopedBaselines.length == document.baselineByChunkKey.length) {
      return document;
    }

    return document.copyWith(
      chunks: List<LevelChunkDef>.unmodifiable(scopedChunks),
      baselineByChunkKey: Map<String, ChunkSourceBaseline>.unmodifiable(
        scopedBaselines,
      ),
    );
  }

  ChunkDocument _asChunkDocument(AuthoringDocument document) {
    if (document is! ChunkDocument) {
      throw StateError(
        'ChunkDomainPlugin expected ChunkDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }

  ChunkDocument _withOperationIssue(
    ChunkDocument document, {
    required String code,
    required String message,
    String? chunkKey,
  }) {
    String? sourcePath;
    if (chunkKey != null && chunkKey.isNotEmpty) {
      sourcePath = document.baselineByChunkKey[chunkKey]?.sourcePath;
    }
    return document.copyWith(
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: code,
          message: message,
          sourcePath: sourcePath,
        ),
      ],
    );
  }
}

int _compareChunksForScene(LevelChunkDef a, LevelChunkDef b) {
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
  if (raw is num) {
    return raw.toInt();
  }
  return fallback;
}

bool _boolOrDefault(Object? raw, {required bool fallback}) {
  if (raw is bool) {
    return raw;
  }
  return fallback;
}

List<String> _parseTags(Object? raw, {required List<String> fallback}) {
  if (raw is List<Object?>) {
    final tags = <String>{};
    for (final value in raw) {
      final normalized = _normalizedString(value);
      if (normalized.isNotEmpty) {
        tags.add(normalized);
      }
    }
    return tags.toList(growable: false)..sort();
  }
  if (raw is String) {
    final tags =
        raw
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return tags;
  }
  return fallback;
}

String _allocateUniqueChunkKey(Set<String> existingKeys, String preferredSeed) {
  final base = _slugify(preferredSeed, fallback: 'chunk');
  if (!existingKeys.contains(base)) {
    return base;
  }
  var counter = 2;
  while (true) {
    final candidate = '${base}_$counter';
    if (!existingKeys.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}

String _allocateUniqueGapId(Set<String> existingGapIds, String preferredGapId) {
  final base = _slugify(preferredGapId, fallback: 'gap');
  if (!existingGapIds.contains(base)) {
    return base;
  }
  var counter = 2;
  while (true) {
    final candidate = '${base}_$counter';
    if (!existingGapIds.contains(candidate)) {
      return candidate;
    }
    counter += 1;
  }
}

String _slugify(String raw, {required String fallback}) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return fallback;
  }
  final normalized = lower.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  if (normalized.isEmpty) {
    return fallback;
  }
  return normalized;
}

LevelChunkDef _bumpRevision(LevelChunkDef chunk) {
  final nextRevision = chunk.revision <= 0 ? 1 : chunk.revision + 1;
  return chunk.copyWith(revision: nextRevision);
}

LevelChunkDef _normalizeChunkToDocumentAuthority(
  LevelChunkDef chunk,
  ChunkDocument document,
) {
  return normalizeChunkToAuthority(
    chunk,
    runtimeChunkWidth: document.runtimeChunkWidth,
    lockedChunkHeight: document.lockedChunkHeight,
    runtimeGroundTopY: document.runtimeGroundTopY,
  );
}

bool _chunkEqualsWithoutRevision(LevelChunkDef a, LevelChunkDef b) {
  return _chunkEquals(a, b, ignoreRevision: true);
}

bool _chunkEquals(
  LevelChunkDef a,
  LevelChunkDef b, {
  bool ignoreRevision = false,
}) {
  final left = a.normalized();
  final right = b.normalized();
  if (left.chunkKey != right.chunkKey ||
      left.id != right.id ||
      left.schemaVersion != right.schemaVersion ||
      left.levelId != right.levelId ||
      left.tileSize != right.tileSize ||
      left.width != right.width ||
      left.height != right.height ||
      left.difficulty != right.difficulty ||
      left.status != right.status) {
    return false;
  }
  if (!ignoreRevision && left.revision != right.revision) {
    return false;
  }
  if (!_stringListEquals(left.tags, right.tags)) {
    return false;
  }
  if (!_tileLayerListEquals(left.tileLayers, right.tileLayers)) {
    return false;
  }
  if (!_placedPrefabListEquals(left.prefabs, right.prefabs)) {
    return false;
  }
  if (!_placedMarkerListEquals(left.markers, right.markers)) {
    return false;
  }
  if (left.groundProfile.kind != right.groundProfile.kind ||
      left.groundProfile.topY != right.groundProfile.topY) {
    return false;
  }
  if (!_groundGapListEquals(left.groundGaps, right.groundGaps)) {
    return false;
  }
  return true;
}

bool _stringListEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

bool _tileLayerListEquals(List<TileLayerDef> a, List<TileLayerDef> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    final left = a[i];
    final right = b[i];
    if (left.id != right.id ||
        left.kind != right.kind ||
        left.visible != right.visible) {
      return false;
    }
  }
  return true;
}

bool _placedPrefabListEquals(List<PlacedPrefabDef> a, List<PlacedPrefabDef> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    final left = a[i];
    final right = b[i];
    if (left.prefabId != right.prefabId ||
        left.prefabKey != right.prefabKey ||
        left.x != right.x ||
        left.y != right.y ||
        left.zIndex != right.zIndex ||
        left.snapToGrid != right.snapToGrid) {
      return false;
    }
  }
  return true;
}

bool _placedMarkerListEquals(List<PlacedMarkerDef> a, List<PlacedMarkerDef> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    final left = a[i];
    final right = b[i];
    if (left.markerId != right.markerId ||
        left.x != right.x ||
        left.y != right.y) {
      return false;
    }
  }
  return true;
}

bool _groundGapListEquals(List<GroundGapDef> a, List<GroundGapDef> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i += 1) {
    final left = a[i];
    final right = b[i];
    if (left.gapId != right.gapId ||
        left.type != right.type ||
        left.x != right.x ||
        left.width != right.width) {
      return false;
    }
  }
  return true;
}
