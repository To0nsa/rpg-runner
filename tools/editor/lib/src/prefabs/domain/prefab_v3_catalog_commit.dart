import 'package:meta/meta.dart';

import '../models/models.dart';
import '../store/prefab_determinism.dart';
import '../store/prefab_tile_file_codec.dart';
import '../store/prefab_v3_file_codec.dart';
import '../validation/prefab_validation.dart';
import 'prefab_domain_models.dart';
import 'prefab_platform_pairing.dart';
import 'prefab_slice_id_convention.dart';
import 'prefab_visual_bounds_resolver.dart';
import 'prefab_v3_catalog_validation.dart';

/// Complete canonical source token for stale-checked catalog mutations.
@immutable
final class PrefabV3CatalogSnapshot {
  const PrefabV3CatalogSnapshot._({
    required this.prefabContents,
    required this.tileContents,
  });

  factory PrefabV3CatalogSnapshot.fromDocument(PrefabV3Document document) =>
      PrefabV3CatalogSnapshot._(
        prefabContents: PrefabV3FileCodec.encode(document.data),
        tileContents: PrefabTileFileCodec.encode(document.tileData),
      );

  final String prefabContents;
  final String tileContents;

  @override
  bool operator ==(Object other) =>
      other is PrefabV3CatalogSnapshot &&
      prefabContents == other.prefabContents &&
      tileContents == other.tileContents;

  @override
  int get hashCode => Object.hash(prefabContents, tileContents);
}

@immutable
sealed class PrefabV3CatalogOperation {
  const PrefabV3CatalogOperation();
}

/// Creates or replaces one prefab-atlas or tile-atlas slice by stable ID.
///
/// [createPrefabKind] is valid only for a new prefab slice and atomically adds
/// a collisionless Decoration or Obstacle owner using the slice ID and tags.
@immutable
final class PrefabV3UpsertSliceOperation extends PrefabV3CatalogOperation {
  const PrefabV3UpsertSliceOperation({
    required this.kind,
    required this.slice,
    this.createPrefabKind,
  });

  final AtlasSliceKind kind;
  final AtlasSliceDef slice;
  final PrefabKind? createPrefabKind;
}

/// Removes one slice, optionally deleting its direct catalog references.
///
/// Cascading a prefab slice deletes referencing prefab owners. Cascading a
/// tile slice removes referencing module cells and bumps each changed module
/// once. The complete candidate must still retain resolvable visual bounds.
@immutable
final class PrefabV3DeleteSliceOperation extends PrefabV3CatalogOperation {
  const PrefabV3DeleteSliceOperation({
    required this.kind,
    required this.sliceId,
    this.cascadeReferences = false,
  });

  final AtlasSliceKind kind;
  final String sliceId;
  final bool cascadeReferences;
}

/// Creates one module at revision 1.
///
/// A bounded module also receives a collisionless paired platform prefab in
/// the same commit. Empty drafts remain module-only until they gain visual
/// geometry or are explicitly opened for collision.
@immutable
final class PrefabV3CreateModuleOperation extends PrefabV3CatalogOperation {
  PrefabV3CreateModuleOperation({
    required this.id,
    required this.status,
    required this.tileSize,
    required Iterable<TileModuleCellDef> cells,
  }) : cells = List<TileModuleCellDef>.unmodifiable(cells);

  final String id;
  final TileModuleStatus status;
  final int tileSize;
  final List<TileModuleCellDef> cells;
}

/// Replaces revision-owned fields of one existing module.
///
/// Status changes synchronize the unambiguous paired prefab. Editing an
/// unpaired bounded module creates that prefab in the same commit.
@immutable
final class PrefabV3UpdateModuleOperation extends PrefabV3CatalogOperation {
  PrefabV3UpdateModuleOperation({
    required this.moduleId,
    required this.status,
    required this.tileSize,
    required Iterable<TileModuleCellDef> cells,
  }) : cells = List<TileModuleCellDef>.unmodifiable(cells);

  final String moduleId;
  final TileModuleStatus status;
  final int tileSize;
  final List<TileModuleCellDef> cells;
}

/// Copies one module under a deterministic ID and revision 1.
///
/// The duplicate receives a paired platform prefab. Collision and metadata are
/// copied only when the source module has an unambiguous paired owner.
@immutable
final class PrefabV3DuplicateModuleOperation extends PrefabV3CatalogOperation {
  const PrefabV3DuplicateModuleOperation({
    required this.sourceModuleId,
    this.targetId,
  });

  final String sourceModuleId;
  final String? targetId;
}

/// Creates the missing collision owner for one retained platform module.
@immutable
final class PrefabV3EnsurePlatformPrefabOperation
    extends PrefabV3CatalogOperation {
  const PrefabV3EnsurePlatformPrefabOperation({required this.moduleId});

  final String moduleId;
}

/// Renames one module and rewrites every referencing prefab exactly once.
@immutable
final class PrefabV3RenameModuleOperation extends PrefabV3CatalogOperation {
  const PrefabV3RenameModuleOperation({
    required this.moduleId,
    required this.nextId,
  });

  final String moduleId;
  final String nextId;
}

/// Removes one unreferenced platform module or its explicit sole paired owner.
@immutable
final class PrefabV3DeleteModuleOperation extends PrefabV3CatalogOperation {
  const PrefabV3DeleteModuleOperation({
    required this.moduleId,
    this.pairedPrefabKey,
  });

  final String moduleId;
  final String? pairedPrefabKey;
}

/// One immutable stale-checked mutation of retained prefab visual catalogs.
@immutable
final class PrefabV3CatalogCommit {
  const PrefabV3CatalogCommit({required this.before, required this.operation});

  final PrefabV3CatalogSnapshot before;
  final PrefabV3CatalogOperation operation;
}

/// Outcome of one prefab-v3 catalog mutation.
final class PrefabV3CatalogCommitResult {
  PrefabV3CatalogCommitResult({
    required this.document,
    required this.accepted,
    required this.changed,
    Iterable<PrefabValidationIssue> issues = const <PrefabValidationIssue>[],
  }) : issues = List<PrefabValidationIssue>.unmodifiable(issues);

  final PrefabV3Document document;
  final bool accepted;
  final bool changed;
  final List<PrefabValidationIssue> issues;
}

/// Deterministic slice/module ownership, reference, and revision policy.
final class PrefabV3CatalogCommitPolicy {
  const PrefabV3CatalogCommitPolicy();

  PrefabV3CatalogCommitResult apply({
    required PrefabV3Document document,
    required PrefabV3CatalogCommit commit,
  }) {
    if (PrefabV3CatalogSnapshot.fromDocument(document) != commit.before) {
      return _rejected(
        document,
        code: 'prefab_v3_catalog_commit_stale',
        message:
            'Prefab visual catalogs changed after this edit began; reload '
            'the current source set before committing.',
      );
    }

    final candidate = switch (commit.operation) {
      final PrefabV3UpsertSliceOperation operation => _upsertSlice(
        document,
        operation,
      ),
      final PrefabV3DeleteSliceOperation operation => _deleteSlice(
        document,
        operation,
      ),
      final PrefabV3CreateModuleOperation operation => _createModule(
        document,
        operation,
      ),
      final PrefabV3UpdateModuleOperation operation => _updateModule(
        document,
        operation,
      ),
      final PrefabV3DuplicateModuleOperation operation => _duplicateModule(
        document,
        operation,
      ),
      final PrefabV3EnsurePlatformPrefabOperation operation =>
        _ensurePlatformPrefab(document, operation),
      final PrefabV3RenameModuleOperation operation => _renameModule(
        document,
        operation,
      ),
      final PrefabV3DeleteModuleOperation operation => _deleteModule(
        document,
        operation,
      ),
    };
    if (identical(candidate, document)) {
      return PrefabV3CatalogCommitResult(
        document: document,
        accepted: true,
        changed: false,
      );
    }
    if (candidate is _CatalogRejection) {
      return _rejected(
        document,
        code: candidate.code,
        message: candidate.message,
      );
    }

    final next = candidate as PrefabV3Document;
    final issues = validatePrefabV3CatalogDocument(next);
    if (issues.any(
      (issue) => issue.severity == PrefabValidationSeverity.error,
    )) {
      return PrefabV3CatalogCommitResult(
        document: document,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }
    return PrefabV3CatalogCommitResult(
      document: next,
      accepted: true,
      changed: true,
      issues: issues,
    );
  }

  Object _upsertSlice(
    PrefabV3Document document,
    PrefabV3UpsertSliceOperation operation,
  ) {
    final sliceIssue = _sliceIssue(document, operation.slice);
    if (sliceIssue != null) return sliceIssue;
    final createPrefabKind = operation.createPrefabKind;
    if (createPrefabKind != null &&
        (operation.kind != AtlasSliceKind.prefab ||
            (createPrefabKind != PrefabKind.decoration &&
                createPrefabKind != PrefabKind.obstacle))) {
      return const _CatalogRejection(
        code: 'prefab_v3_slice_prefab_kind_invalid',
        message:
            'Automatic prefab creation requires a new Prefab Slice and a '
            'Decoration or Obstacle kind.',
      );
    }
    final current = operation.kind == AtlasSliceKind.prefab
        ? document.data.slices
        : document.tileData.tileSlices;
    final previous = current
        .where((slice) => slice.id == operation.slice.id)
        .firstOrNull;
    if (previous != null && createPrefabKind != null) {
      return _CatalogRejection(
        code: 'prefab_v3_slice_prefab_existing_slice',
        message:
            'Automatic prefab creation is only available for a new slice; '
            '${operation.slice.id} already exists.',
      );
    }
    if (createPrefabKind != null &&
        document.data.prefabs.any(
          (prefab) =>
              prefab.id.toLowerCase() == operation.slice.id.toLowerCase(),
        )) {
      return _CatalogRejection(
        code: 'prefab_v3_slice_prefab_id_collision',
        message: 'Prefab id "${operation.slice.id}" is already owned.',
      );
    }
    if (operation.kind == AtlasSliceKind.prefab && previous == null) {
      final namingIssue = PrefabSliceIdConvention.validate(
        id: operation.slice.id,
        sourceImagePath: operation.slice.sourceImagePath,
      );
      if (namingIssue != null) {
        return _CatalogRejection(
          code: 'prefab_v3_slice_id_convention_invalid',
          message: namingIssue,
        );
      }
    }
    if (previous != null && _slicesEqual(previous, operation.slice)) {
      return document;
    }
    final slices = PrefabDeterminism.sortSlicesByIdThenSourceRect(
      current.where((slice) => slice.id != operation.slice.id).followedBy(
        <AtlasSliceDef>[operation.slice],
      ),
    );
    return switch (operation.kind) {
      AtlasSliceKind.prefab =>
        createPrefabKind == null
            ? _withCatalog(
                document,
                data: document.data.copyWith(slices: slices),
              )
            : _withGeneratedSlicePrefab(
                document,
                slice: operation.slice,
                slices: slices,
                kind: createPrefabKind,
              ),
      AtlasSliceKind.tile => _withCatalog(
        document,
        tileData: document.tileData.copyWith(tileSlices: slices),
      ),
    };
  }

  PrefabV3Document _withGeneratedSlicePrefab(
    PrefabV3Document document, {
    required AtlasSliceDef slice,
    required List<AtlasSliceDef> slices,
    required PrefabKind kind,
  }) {
    final key = PrefabDeterminism.allocatePrefabKey(
      id: slice.id,
      usedPrefabKeys: document.data.prefabs
          .map((prefab) => prefab.prefabKey)
          .toSet(),
    );
    final prefab = PrefabV3Def(
      prefabKey: key,
      id: slice.id,
      revision: 1,
      status: PrefabStatus.active,
      kind: kind,
      visualSource: PrefabVisualSource.atlasSlice(slice.id),
      anchorXPx: slice.width ~/ 2,
      anchorYPx: slice.height ~/ 2,
      collisionShapes: const [],
      tags: slice.tags,
    );
    return _withCatalog(
      document,
      data: document.data.copyWith(
        slices: slices,
        prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(<PrefabV3Def>[
          ...document.data.prefabs,
          prefab,
        ]),
      ),
      changedPrefabKeys: <String>[key],
    );
  }

  Object _deleteSlice(
    PrefabV3Document document,
    PrefabV3DeleteSliceOperation operation,
  ) {
    final current = operation.kind == AtlasSliceKind.prefab
        ? document.data.slices
        : document.tileData.tileSlices;
    if (!current.any((slice) => slice.id == operation.sliceId)) {
      return _CatalogRejection(
        code: 'prefab_v3_slice_missing',
        message: 'Cannot delete unknown slice ${operation.sliceId}.',
      );
    }

    if (operation.kind == AtlasSliceKind.prefab) {
      final referencing = document.data.prefabs
          .where(
            (prefab) =>
                prefab.usesAtlasSlice && prefab.sliceId == operation.sliceId,
          )
          .toList(growable: false);
      if (referencing.isNotEmpty && !operation.cascadeReferences) {
        return _CatalogRejection(
          code: 'prefab_v3_slice_referenced',
          message:
              'Prefab slice ${operation.sliceId} is referenced by '
              '${referencing.length} '
              '${referencing.length == 1 ? 'prefab' : 'prefabs'}.',
        );
      }
      final removedKeys = referencing.map((prefab) => prefab.prefabKey);
      return _withCatalog(
        document,
        data: document.data.copyWith(
          slices: document.data.slices.where(
            (slice) => slice.id != operation.sliceId,
          ),
          prefabs: document.data.prefabs.where(
            (prefab) => !removedKeys.contains(prefab.prefabKey),
          ),
        ),
        changedPrefabKeys: removedKeys,
      );
    }

    final referencingModules = document.tileData.platformModules
        .where(
          (module) =>
              module.cells.any((cell) => cell.sliceId == operation.sliceId),
        )
        .toList(growable: false);
    if (referencingModules.isNotEmpty && !operation.cascadeReferences) {
      return _CatalogRejection(
        code: 'prefab_v3_tile_slice_referenced',
        message:
            'Tile slice ${operation.sliceId} is referenced by '
            '${referencingModules.length} platform module(s).',
      );
    }
    final modules = document.tileData.platformModules.map((module) {
      final cells = module.cells
          .where((cell) => cell.sliceId != operation.sliceId)
          .toList(growable: false);
      return cells.length == module.cells.length
          ? module
          : module.copyWith(revision: module.revision + 1, cells: cells);
    });
    return _withCatalog(
      document,
      tileData: document.tileData.copyWith(
        tileSlices: document.tileData.tileSlices.where(
          (slice) => slice.id != operation.sliceId,
        ),
        platformModules: PrefabDeterminism.sortModulesByStatusIdRevision(
          modules,
        ),
      ),
    );
  }

  Object _createModule(
    PrefabV3Document document,
    PrefabV3CreateModuleOperation operation,
  ) {
    final idIssue = _moduleIdIssue(document, operation.id);
    if (idIssue != null) return idIssue;
    final structureIssue = _moduleStructureIssue(
      document,
      id: operation.id,
      status: operation.status,
      tileSize: operation.tileSize,
      cells: operation.cells,
    );
    if (structureIssue != null) return structureIssue;
    final module = TileModuleDef(
      id: operation.id,
      revision: 1,
      status: operation.status,
      tileSize: operation.tileSize,
      cells: operation.cells,
    );
    final next = _withCatalog(
      document,
      tileData: document.tileData.copyWith(
        platformModules: PrefabDeterminism.sortModulesByStatusIdRevision(
          <TileModuleDef>[...document.tileData.platformModules, module],
        ),
      ),
    );
    return _ensurePairedOwner(next, module);
  }

  Object _updateModule(
    PrefabV3Document document,
    PrefabV3UpdateModuleOperation operation,
  ) {
    final index = document.tileData.platformModules.indexWhere(
      (module) => module.id == operation.moduleId,
    );
    if (index < 0) {
      return _CatalogRejection(
        code: 'prefab_v3_module_missing',
        message: 'Cannot update unknown module ${operation.moduleId}.',
      );
    }
    final structureIssue = _moduleStructureIssue(
      document,
      id: operation.moduleId,
      status: operation.status,
      tileSize: operation.tileSize,
      cells: operation.cells,
    );
    if (structureIssue != null) return structureIssue;
    final current = document.tileData.platformModules[index];
    if (current.status == operation.status &&
        current.tileSize == operation.tileSize &&
        _cellListsEqual(current.cells, operation.cells)) {
      return document;
    }
    final modules = document.tileData.platformModules.toList(growable: false);
    modules[index] = current.copyWith(
      revision: current.revision + 1,
      status: operation.status,
      tileSize: operation.tileSize,
      cells: operation.cells,
    );
    final next = _withCatalog(
      document,
      tileData: document.tileData.copyWith(
        platformModules: PrefabDeterminism.sortModulesByStatusIdRevision(
          modules,
        ),
      ),
    );
    return _synchronizePairedOwner(next, modules[index]);
  }

  Object _duplicateModule(
    PrefabV3Document document,
    PrefabV3DuplicateModuleOperation operation,
  ) {
    final source = document.tileData.platformModules
        .where((module) => module.id == operation.sourceModuleId)
        .firstOrNull;
    if (source == null) {
      return _CatalogRejection(
        code: 'prefab_v3_module_duplicate_source_missing',
        message: 'Cannot duplicate unknown module ${operation.sourceModuleId}.',
      );
    }
    final usedIds = document.tileData.platformModules
        .map((module) => module.id)
        .toSet();
    final targetId =
        operation.targetId ??
        PrefabDeterminism.allocateDuplicateModuleId(
          sourceId: source.id,
          usedModuleIds: usedIds,
        );
    final idIssue = _moduleIdIssue(document, targetId);
    if (idIssue != null) return idIssue;
    final duplicate = source.copyWith(
      id: targetId,
      revision: 1,
      status: TileModuleStatus.active,
    );
    final next = _withCatalog(
      document,
      tileData: document.tileData.copyWith(
        platformModules: PrefabDeterminism.sortModulesByStatusIdRevision(
          <TileModuleDef>[...document.tileData.platformModules, duplicate],
        ),
      ),
    );
    return _ensurePairedOwner(
      next,
      duplicate,
      copyFrom: PrefabPlatformPairing.pairedOwner(document.data, source.id),
    );
  }

  Object _ensurePlatformPrefab(
    PrefabV3Document document,
    PrefabV3EnsurePlatformPrefabOperation operation,
  ) {
    final module = document.tileData.platformModules
        .where((candidate) => candidate.id == operation.moduleId)
        .firstOrNull;
    if (module == null) {
      return _CatalogRejection(
        code: 'prefab_v3_module_missing',
        message:
            'Cannot configure collision for unknown platform ${operation.moduleId}.',
      );
    }
    return _ensurePairedOwner(document, module);
  }

  Object _renameModule(
    PrefabV3Document document,
    PrefabV3RenameModuleOperation operation,
  ) {
    final index = document.tileData.platformModules.indexWhere(
      (module) => module.id == operation.moduleId,
    );
    if (index < 0) {
      return _CatalogRejection(
        code: 'prefab_v3_module_rename_source_missing',
        message: 'Cannot rename unknown module ${operation.moduleId}.',
      );
    }
    if (operation.moduleId == operation.nextId) return document;
    final idIssue = _moduleIdIssue(
      document,
      operation.nextId,
      exceptModuleId: operation.moduleId,
    );
    if (idIssue != null) return idIssue;

    final current = document.tileData.platformModules[index];
    final modules = document.tileData.platformModules.toList(growable: false);
    modules[index] = current.copyWith(
      id: operation.nextId,
      revision: current.revision + 1,
    );
    final paired = PrefabPlatformPairing.pairedOwner(
      document.data,
      operation.moduleId,
    );
    final oldDefaultId = PrefabPlatformPairing.defaultPrefabId(
      operation.moduleId,
    );
    final nextDefaultId = PrefabPlatformPairing.defaultPrefabId(
      operation.nextId,
    );
    final canRenamePairedOwner =
        paired != null &&
        paired.id == oldDefaultId &&
        !document.data.prefabs.any(
          (prefab) =>
              prefab.prefabKey != paired.prefabKey &&
              prefab.id.toLowerCase() == nextDefaultId.toLowerCase(),
        );
    final changedKeys = <String>[];
    final prefabs = document.data.prefabs.map((prefab) {
      if (!prefab.usesPlatformModule || prefab.moduleId != operation.moduleId) {
        return prefab;
      }
      changedKeys.add(prefab.prefabKey);
      return prefab.copyWith(
        id: canRenamePairedOwner && prefab.prefabKey == paired.prefabKey
            ? nextDefaultId
            : prefab.id,
        revision: prefab.revision + 1,
        visualSource: PrefabVisualSource.platformModule(operation.nextId),
      );
    });
    return _withCatalog(
      document,
      data: document.data.copyWith(
        prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(prefabs),
      ),
      tileData: document.tileData.copyWith(
        platformModules: PrefabDeterminism.sortModulesByStatusIdRevision(
          modules,
        ),
      ),
      changedPrefabKeys: changedKeys,
    );
  }

  Object _deleteModule(
    PrefabV3Document document,
    PrefabV3DeleteModuleOperation operation,
  ) {
    if (!document.tileData.platformModules.any(
      (module) => module.id == operation.moduleId,
    )) {
      return _CatalogRejection(
        code: 'prefab_v3_module_missing',
        message: 'Cannot delete unknown module ${operation.moduleId}.',
      );
    }
    final references = PrefabPlatformPairing.ownersForModule(
      document.data,
      operation.moduleId,
    );
    final pairedPrefabKey = operation.pairedPrefabKey;
    if (references.isNotEmpty &&
        (references.length != 1 ||
            pairedPrefabKey == null ||
            references.single.prefabKey != pairedPrefabKey)) {
      return _CatalogRejection(
        code: 'prefab_v3_module_referenced',
        message:
            'Cannot delete module ${operation.moduleId}: ${references.length} '
            '${references.length == 1 ? 'prefab still references' : 'prefabs still reference'} '
            'it.',
      );
    }
    final removedKeys = references.map((prefab) => prefab.prefabKey).toSet();
    return _withCatalog(
      document,
      data: removedKeys.isEmpty
          ? document.data
          : document.data.copyWith(
              prefabs: document.data.prefabs.where(
                (prefab) => !removedKeys.contains(prefab.prefabKey),
              ),
            ),
      tileData: document.tileData.copyWith(
        platformModules: document.tileData.platformModules.where(
          (module) => module.id != operation.moduleId,
        ),
      ),
      changedPrefabKeys: removedKeys,
    );
  }

  PrefabV3Document _synchronizePairedOwner(
    PrefabV3Document document,
    TileModuleDef module,
  ) {
    final paired = PrefabPlatformPairing.pairedOwner(document.data, module.id);
    if (paired == null) {
      return _ensurePairedOwner(document, module);
    }
    final status = PrefabPlatformPairing.prefabStatus(module.status);
    if (paired.status == status) return document;
    final prefabs = document.data.prefabs.map(
      (prefab) => prefab.prefabKey == paired.prefabKey
          ? prefab.copyWith(status: status, revision: prefab.revision + 1)
          : prefab,
    );
    return _withCatalog(
      document,
      data: document.data.copyWith(
        prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(prefabs),
      ),
      changedPrefabKeys: <String>[paired.prefabKey],
    );
  }

  PrefabV3Document _ensurePairedOwner(
    PrefabV3Document document,
    TileModuleDef module, {
    PrefabV3Def? copyFrom,
  }) {
    final paired = PrefabPlatformPairing.pairedOwner(document.data, module.id);
    if (paired != null) return _synchronizePairedOwner(document, module);
    if (PrefabPlatformPairing.ownersForModule(
      document.data,
      module.id,
    ).isNotEmpty) {
      return document;
    }
    final bounds = PrefabVisualBoundsResolver.resolvePlatformModule(
      module,
      tileSlicesById: <String, AtlasSliceDef>{
        for (final slice in document.tileData.tileSlices) slice.id: slice,
      },
    );
    if (bounds == null) {
      return document;
    }
    final id = PrefabPlatformPairing.allocatePrefabId(
      moduleId: module.id,
      usedPrefabIds: document.data.prefabs.map((prefab) => prefab.id),
    );
    final key = PrefabDeterminism.allocatePrefabKey(
      id: id,
      usedPrefabKeys: document.data.prefabs
          .map((prefab) => prefab.prefabKey)
          .toSet(),
    );
    final prefab = copyFrom == null
        ? PrefabV3Def(
            prefabKey: key,
            id: id,
            revision: 1,
            status: PrefabPlatformPairing.prefabStatus(module.status),
            kind: PrefabKind.platform,
            visualSource: PrefabVisualSource.platformModule(module.id),
            anchorXPx: bounds.widthPx ~/ 2,
            anchorYPx: bounds.heightPx ~/ 2,
            collisionShapes: const [],
            tags: const [],
          )
        : copyFrom.copyWith(
            prefabKey: key,
            id: id,
            revision: 1,
            status: PrefabPlatformPairing.prefabStatus(module.status),
            visualSource: PrefabVisualSource.platformModule(module.id),
          );
    return _withCatalog(
      document,
      data: document.data.copyWith(
        prefabs: PrefabDeterminism.sortPrefabV3ByIdThenKey(<PrefabV3Def>[
          ...document.data.prefabs,
          prefab,
        ]),
      ),
      changedPrefabKeys: <String>[key],
    );
  }

  PrefabV3Document _withCatalog(
    PrefabV3Document document, {
    PrefabV3FileData? data,
    PrefabTileFileData? tileData,
    Iterable<String> changedPrefabKeys = const <String>[],
  }) {
    final nextData = data ?? document.data;
    final nextTileData = tileData ?? document.tileData;
    return document.copyWith(
      data: nextData,
      tileData: nextTileData,
      visualBoundsByPrefabKey: PrefabVisualBoundsResolver.resolveAll(
        prefabData: nextData,
        tileData: nextTileData,
      ),
      changedPrefabKeys: <String>{
        ...document.changedPrefabKeys,
        ...changedPrefabKeys,
      },
    );
  }
}

_CatalogRejection? _sliceIssue(PrefabV3Document document, AtlasSliceDef slice) {
  if (slice.id.isEmpty || slice.id != slice.id.trim()) {
    return const _CatalogRejection(
      code: 'prefab_v3_slice_id_invalid',
      message: 'Slice id must be non-empty with no surrounding whitespace.',
    );
  }
  if (slice.sourceImagePath.isEmpty ||
      slice.sourceImagePath != slice.sourceImagePath.trim()) {
    return _CatalogRejection(
      code: 'prefab_v3_slice_source_invalid',
      message: 'Slice ${slice.id} must reference a non-empty atlas path.',
    );
  }
  if (slice.x < 0 || slice.y < 0 || slice.width <= 0 || slice.height <= 0) {
    return _CatalogRejection(
      code: 'prefab_v3_slice_bounds_invalid',
      message:
          'Slice ${slice.id} must have a non-negative origin and positive '
          'dimensions.',
    );
  }
  if (!_stringListsEqual(
    slice.tags,
    PrefabDeterminism.normalizeTags(slice.tags),
  )) {
    return _CatalogRejection(
      code: 'prefab_v3_slice_tags_noncanonical',
      message:
          'Slice ${slice.id} tags must be trimmed, non-empty, unique, and '
          'ordered lexically.',
    );
  }
  final sourcePath = slice.sourceImagePath.replaceAll('\\', '/');
  final atlasSize = document.atlasImageSizes[sourcePath];
  if (atlasSize == null) {
    return _CatalogRejection(
      code: 'prefab_v3_slice_atlas_missing',
      message:
          'Slice ${slice.id} references unavailable atlas '
          '${slice.sourceImagePath}.',
    );
  }
  if (slice.x + slice.width > atlasSize.width.toInt() ||
      slice.y + slice.height > atlasSize.height.toInt()) {
    return _CatalogRejection(
      code: 'prefab_v3_slice_out_of_bounds',
      message:
          'Slice ${slice.id} exceeds atlas bounds '
          '${atlasSize.width.toInt()}x${atlasSize.height.toInt()}.',
    );
  }
  return null;
}

_CatalogRejection? _moduleIdIssue(
  PrefabV3Document document,
  String id, {
  String? exceptModuleId,
}) {
  if (id.isEmpty || id != id.trim()) {
    return const _CatalogRejection(
      code: 'prefab_v3_module_id_invalid',
      message: 'Module id must be non-empty with no surrounding whitespace.',
    );
  }
  final normalized = id.toLowerCase();
  if (document.tileData.platformModules.any(
    (module) =>
        module.id != exceptModuleId && module.id.toLowerCase() == normalized,
  )) {
    return _CatalogRejection(
      code: 'prefab_v3_module_id_collision',
      message: 'Module id "$id" is already owned.',
    );
  }
  return null;
}

_CatalogRejection? _moduleStructureIssue(
  PrefabV3Document document, {
  required String id,
  required TileModuleStatus status,
  required int tileSize,
  required List<TileModuleCellDef> cells,
}) {
  if (status == TileModuleStatus.unknown || tileSize <= 0) {
    return _CatalogRejection(
      code: 'prefab_v3_module_metadata_invalid',
      message: 'Module $id requires a supported status and positive tileSize.',
    );
  }
  final canonical = PrefabDeterminism.sortModuleCellsByGridPosition(cells);
  if (!_cellListsEqual(cells, canonical)) {
    return _CatalogRejection(
      code: 'prefab_v3_module_cells_noncanonical',
      message: 'Module $id cells must be ordered by canonical grid position.',
    );
  }
  final tileSliceIds = document.tileData.tileSlices
      .map((slice) => slice.id)
      .toSet();
  final positions = <(int, int)>{};
  for (final cell in cells) {
    if (!tileSliceIds.contains(cell.sliceId)) {
      return _CatalogRejection(
        code: 'prefab_v3_module_tile_slice_missing',
        message: 'Module $id references missing tile slice ${cell.sliceId}.',
      );
    }
    if (!positions.add((cell.gridX, cell.gridY))) {
      return _CatalogRejection(
        code: 'prefab_v3_module_cell_duplicate',
        message:
            'Module $id contains duplicate grid position '
            '(${cell.gridX},${cell.gridY}).',
      );
    }
  }
  return null;
}

PrefabV3CatalogCommitResult _rejected(
  PrefabV3Document document, {
  required String code,
  required String message,
}) => PrefabV3CatalogCommitResult(
  document: document,
  accepted: false,
  changed: false,
  issues: <PrefabValidationIssue>[
    PrefabValidationIssue(code: code, message: message),
  ],
);

bool _slicesEqual(AtlasSliceDef left, AtlasSliceDef right) =>
    left.id == right.id &&
    left.sourceImagePath == right.sourceImagePath &&
    left.x == right.x &&
    left.y == right.y &&
    left.width == right.width &&
    left.height == right.height &&
    _stringListsEqual(left.tags, right.tags);

bool _cellListsEqual(
  List<TileModuleCellDef> left,
  List<TileModuleCellDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.sliceId != b.sliceId || a.gridX != b.gridX || a.gridY != b.gridY) {
      return false;
    }
  }
  return true;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _CatalogRejection {
  const _CatalogRejection({required this.code, required this.message});

  final String code;
  final String message;
}
