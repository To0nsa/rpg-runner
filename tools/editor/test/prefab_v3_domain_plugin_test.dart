import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_catalog_commit.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_lifecycle_commit.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_metadata_commit.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  const plugin = PrefabDomainPlugin();

  test(
    'current command commits through owner policy and builds pending diff',
    () {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final after = <TerrainSourceShapeDef>[_rectangle(right: 10)];
      final document = _document(before);

      expect(plugin.validate(document), isEmpty);
      expect(plugin.buildEditableScene(document), isA<PrefabV3Scene>());
      final edited = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(before: before, after: after),
          },
        ),
      );

      expect(edited, isA<PrefabV3Document>());
      final next = edited as PrefabV3Document;
      expect(next, isNot(same(document)));
      expect(document.data.prefabs.single.revision, 4);
      expect(next.data.prefabs.single.revision, 5);
      expect(next.data.prefabs.single.collisionShapes, after);
      expect(next.changedPrefabKeys, <String>['target']);

      final pending = plugin.describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: next,
      );
      expect(pending.hasChanges, isTrue);
      expect(pending.changedItemIds, <String>['target']);
      expect(pending.fileDiffs, hasLength(1));
      expect(
        pending.fileDiffs.single.relativePath,
        contains('prefab_defs.json'),
      );
      expect(pending.fileDiffs.single.unifiedDiff, contains('collisionShapes'));
    },
  );

  test(
    'invalid topology, stale, malformed, and no-op commands keep identity',
    () {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final document = _document(before);
      final invalid = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_selfIntersectingShape()],
            ),
          },
        ),
      );
      final stale = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: <TerrainSourceShapeDef>[_rectangle(left: -6, right: 8)],
              after: before,
            ),
          },
        ),
      );
      final malformed = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: const <String, Object?>{'prefabKey': 'target'},
        ),
      );
      final noOp = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(before: before, after: before),
          },
        ),
      );

      expect(invalid, same(document));
      expect(stale, same(document));
      expect(malformed, same(document));
      expect(noOp, same(document));
    },
  );

  test(
    'current export is a no-op when clean and rejects missing source',
    () async {
      final root = Directory.systemTemp.createTempSync('prefab_v3_plugin_');
      try {
        final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
        final clean = _document(before);
        final workspace = EditorWorkspace(rootPath: root.path);
        final cleanResult = await plugin.exportToRepo(
          workspace,
          document: clean,
        );
        expect(cleanResult.applied, isFalse);
        expect(
          cleanResult.artifacts.single.content,
          contains('changedFiles: 0'),
        );

        final changed = plugin.applyEdit(
          clean,
          AuthoringCommand(
            kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
            payload: <String, Object?>{
              'prefabKey': 'target',
              'commit': _commit(
                before: before,
                after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
              ),
            },
          ),
        );
        await expectLater(
          plugin.exportToRepo(workspace, document: changed),
          throwsA(
            isA<PrefabV3SaveException>().having(
              (error) => error.code,
              'code',
              'prefab_v3_save_source_drift',
            ),
          ),
        );
        expect(root.listSync(recursive: true), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('current validation reports unresolved visual owner bounds', () {
    final source = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final unresolved = source.copyWith(
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{},
    );

    final issues = plugin.validate(unresolved);

    expect(issues, hasLength(1));
    expect(issues.single.severity, ValidationSeverity.error);
    expect(issues.single.code, 'prefab_polygon_visual_bounds_unresolved');
  });

  test('current validation preserves polygon warning ownership', () {
    final issues = plugin.validate(_document(_capacityShapes(17)));

    final warning = issues.singleWhere(
      (issue) => issue.code == 'prefab_shape_soft_target_exceeded',
    );
    expect(warning.severity, ValidationSeverity.warning);
    expect(warning.ownerKey, 'target');
    expect(warning.sourcePath, contains('prefab_defs.json:target'));
  });

  test('current validation covers retained tile catalog invariants', () {
    final source = _catalogDocument();
    final module = source.tileData.platformModules.single;
    final invalid = source.copyWith(
      tileData: PrefabTileFileData(
        tileSlices: source.tileData.tileSlices,
        platformModules: <TileModuleDef>[
          module.copyWith(
            cells: const <TileModuleCellDef>[
              TileModuleCellDef(sliceId: 'missing_tile', gridX: 0, gridY: 0),
            ],
          ),
        ],
      ),
      atlasImageSizes: const <String, Size>{
        'assets/images/level/test.png': Size(8, 8),
      },
    );

    final codes = plugin.validate(invalid).map((issue) => issue.code).toSet();

    expect(codes, contains('prefab_v3_tile_slice_out_of_bounds'));
    expect(codes, contains('prefab_v3_module_tile_slice_missing'));
  });

  test(
    'every current semantic candidate and export crosses full validation',
    () async {
      final beforeShapes = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final valid = _document(beforeShapes);
      final invalidTileData = PrefabTileFileData(
        tileSlices: const <AtlasSliceDef>[],
        platformModules: const <TileModuleDef>[
          TileModuleDef(
            id: 'unused',
            tileSize: 16,
            cells: <TileModuleCellDef>[],
          ),
        ],
      );
      final invalid = valid.copyWith(
        tileData: invalidTileData,
        tileBaselineContents: PrefabTileFileCodec.encode(invalidTileData),
      );
      expect(
        plugin.validate(invalid).map((issue) => issue.code),
        contains('prefab_v3_module_cells_missing'),
      );

      final polygonEdit = plugin.applyEdit(
        invalid,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: beforeShapes,
              after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
            ),
          },
        ),
      );
      final owner = invalid.data.prefabs.single;
      final metadataEdit = plugin.applyEdit(
        invalid,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
          payload: <String, Object?>{
            'prefabKey': owner.prefabKey,
            'commit': PrefabV3MetadataCommit(
              before: PrefabV3MetadataSnapshot.fromPrefab(owner),
              after: PrefabV3MetadataSnapshot(
                status: PrefabStatus.deprecated,
                kind: owner.kind,
                visualSource: owner.visualSource,
                anchorXPx: owner.anchorXPx,
                anchorYPx: owner.anchorYPx,
                tags: owner.tags,
              ),
            ),
          },
        ),
      );
      final lifecycleEdit = plugin.applyEdit(
        invalid,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
          payload: <String, Object?>{
            'commit': PrefabV3LifecycleCommit(
              before: PrefabV3LifecycleSnapshot.fromDocument(invalid),
              operation: const PrefabV3RenameOperation(
                prefabKey: 'target',
                nextId: 'renamed_target',
              ),
            ),
          },
        ),
      );

      expect(polygonEdit, same(invalid));
      expect(metadataEdit, same(invalid));
      expect(lifecycleEdit, same(invalid));

      final root = Directory.systemTemp.createTempSync(
        'prefab_v3_validation_gate_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      await expectLater(
        plugin.exportToRepo(
          EditorWorkspace(rootPath: root.path),
          document: invalid,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Cannot export prefab-v3 while validation has'),
          ),
        ),
      );
      expect(root.listSync(recursive: true), isEmpty);
    },
  );

  test('typed metadata changes only owner metadata and revision once', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final before = document.data.prefabs.single;
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
        payload: <String, Object?>{
          'prefabKey': before.prefabKey,
          'commit': PrefabV3MetadataCommit(
            before: PrefabV3MetadataSnapshot.fromPrefab(before),
            after: PrefabV3MetadataSnapshot(
              status: PrefabStatus.deprecated,
              kind: before.kind,
              visualSource: before.visualSource,
              anchorXPx: 4,
              anchorYPx: 6,
              tags: const <String>['boss', 'test'],
            ),
          ),
        },
      ),
    ) as PrefabV3Document;

    final after = edited.data.prefabs.single;
    expect(after.prefabKey, before.prefabKey);
    expect(after.id, before.id);
    expect(after.revision, before.revision + 1);
    expect(after.status, PrefabStatus.deprecated);
    expect(after.anchorXPx, 4);
    expect(after.anchorYPx, 6);
    expect(after.tags, <String>['boss', 'test']);
    expect(after.collisionShapes, before.collisionShapes);
    expect(edited.changedPrefabKeys, <String>['target']);
    expect(plugin.validate(edited), isEmpty);
  });

  test('stale invalid and no-op metadata commands preserve identity', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final current = document.data.prefabs.single;
    final before = PrefabV3MetadataSnapshot.fromPrefab(current);

    AuthoringDocument apply(PrefabV3MetadataCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
        payload: <String, Object?>{
          'prefabKey': current.prefabKey,
          'commit': commit,
        },
      ),
    );

    final stale = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: current.visualSource,
      anchorXPx: 4,
      anchorYPx: current.anchorYPx,
      tags: current.tags,
    );
    final invalidSource = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: const PrefabVisualSource.atlasSlice('missing'),
      anchorXPx: current.anchorXPx,
      anchorYPx: current.anchorYPx,
      tags: current.tags,
    );
    final noncanonicalTags = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: current.visualSource,
      anchorXPx: current.anchorXPx,
      anchorYPx: current.anchorYPx,
      tags: const <String>['test', 'boss'],
    );

    expect(
      apply(PrefabV3MetadataCommit(before: stale, after: invalidSource)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: invalidSource)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: noncanonicalTags)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: before)),
      same(document),
    );
  });

  test(
    'typed lifecycle owns allocation create duplicate rename and delete',
    () {
      final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);

      PrefabV3Document apply(
        PrefabV3Document source,
        PrefabV3LifecycleOperation operation,
      ) => plugin.applyEdit(
        source,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
          payload: <String, Object?>{
            'commit': PrefabV3LifecycleCommit(
              before: PrefabV3LifecycleSnapshot.fromDocument(source),
              operation: operation,
            ),
          },
        ),
      ) as PrefabV3Document;

      final created = apply(
        document,
        PrefabV3CreateOperation(
          id: 'New Decoration',
          kind: PrefabKind.decoration,
          visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
          anchorXPx: 5,
          anchorYPx: 5,
        ),
      );
      final createdOwner = created.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'new_decoration',
      );
      expect(createdOwner.id, 'New Decoration');
      expect(createdOwner.revision, 1);
      expect(createdOwner.status, PrefabStatus.active);
      expect(createdOwner.collisionShapes, isEmpty);

      final duplicated = apply(
        created,
        const PrefabV3DuplicateOperation(sourcePrefabKey: 'target'),
      );
      final duplicate = duplicated.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target_copy',
      );
      final duplicateSource = created.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target',
      );
      expect(duplicate.id, 'target_copy');
      expect(duplicate.revision, 1);
      expect(duplicate.collisionShapes, duplicateSource.collisionShapes);

      final renamed = apply(
        duplicated,
        const PrefabV3RenameOperation(
          prefabKey: 'target_copy',
          nextId: 'renamed_target',
        ),
      );
      final renamedOwner = renamed.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target_copy',
      );
      expect(renamedOwner.id, 'renamed_target');
      expect(renamedOwner.revision, 2);

      final deleted = apply(
        renamed,
        const PrefabV3DeleteOperation(prefabKey: 'new_decoration'),
      );
      expect(
        deleted.data.prefabs.any(
          (prefab) => prefab.prefabKey == 'new_decoration',
        ),
        isFalse,
      );
      expect(deleted.changedPrefabKeys, <String>[
        'new_decoration',
        'target_copy',
      ]);
      expect(
        plugin
            .describePendingChanges(
              EditorWorkspace(rootPath: Directory.current.path),
              document: deleted,
            )
            .hasChanges,
        isTrue,
      );
    },
  );

  test('stale invalid colliding and missing lifecycle edits keep identity', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final before = PrefabV3LifecycleSnapshot.fromDocument(document);

    AuthoringDocument apply(PrefabV3LifecycleCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
        payload: <String, Object?>{'commit': commit},
      ),
    );

    final staleDocument = document.copyWith(
      data: document.data.copyWith(
        prefabs: <PrefabV3Def>[
          document.data.prefabs.single.copyWith(revision: 5),
        ],
      ),
    );
    final stale = PrefabV3LifecycleSnapshot.fromDocument(staleDocument);
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: stale,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: 'renamed',
          ),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: ' target ',
          ),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3DeleteOperation(prefabKey: 'missing'),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: 'target',
          ),
        ),
      ),
      same(document),
    );
  });

  test('typed slice mutations recompute bounds and protect references', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);

    AuthoringDocument apply(
      PrefabV3Document source,
      PrefabV3CatalogOperation operation,
    ) => plugin.applyEdit(
      source,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(source),
            operation: operation,
          ),
        },
      ),
    );

    final resized = apply(
      document,
      const PrefabV3UpsertSliceOperation(
        kind: AtlasSliceKind.prefab,
        slice: AtlasSliceDef(
          id: 'slice_a',
          sourceImagePath: 'assets/images/level/test.png',
          x: 0,
          y: 0,
          width: 12,
          height: 10,
        ),
      ),
    ) as PrefabV3Document;
    expect(resized.visualBoundsByPrefabKey['target']?.widthPx, 12);
    expect(resized.data.prefabs.single.revision, 4);

    final blockedDelete = apply(
      resized,
      const PrefabV3DeleteSliceOperation(
        kind: AtlasSliceKind.prefab,
        sliceId: 'slice_a',
      ),
    );
    expect(blockedDelete, same(resized));

    final deleted = apply(
      resized,
      const PrefabV3DeleteSliceOperation(
        kind: AtlasSliceKind.prefab,
        sliceId: 'slice_a',
        cascadeReferences: true,
      ),
    ) as PrefabV3Document;
    expect(deleted.data.slices, isEmpty);
    expect(deleted.data.prefabs, isEmpty);
    expect(deleted.changedPrefabKeys, <String>['target']);
  });

  test('new prefab slice atomically creates its requested owner', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);

    AuthoringDocument apply(PrefabV3UpsertSliceOperation operation) =>
        plugin.applyEdit(
          document,
          AuthoringCommand(
            kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
            payload: <String, Object?>{
              'commit': PrefabV3CatalogCommit(
                before: PrefabV3CatalogSnapshot.fromDocument(document),
                operation: operation,
              ),
            },
          ),
        );

    final created = apply(
      const PrefabV3UpsertSliceOperation(
        kind: AtlasSliceKind.prefab,
        slice: AtlasSliceDef(
          id: 'level_stone_block_01',
          sourceImagePath: 'assets/images/level/test.png',
          x: 2,
          y: 3,
          width: 7,
          height: 9,
          tags: <String>['stone', 'test'],
        ),
        createPrefabKind: PrefabKind.obstacle,
      ),
    ) as PrefabV3Document;

    final prefab = created.data.prefabs.singleWhere(
      (candidate) => candidate.id == 'level_stone_block_01',
    );
    expect(prefab.prefabKey, 'level_stone_block_01');
    expect(prefab.revision, 1);
    expect(prefab.status, PrefabStatus.active);
    expect(prefab.kind, PrefabKind.obstacle);
    expect(prefab.sliceId, 'level_stone_block_01');
    expect((prefab.anchorXPx, prefab.anchorYPx), (3, 4));
    expect(prefab.collisionShapes, isEmpty);
    expect(prefab.tags, <String>['stone', 'test']);
    expect(created.visualBoundsByPrefabKey['level_stone_block_01'], isNotNull);
    expect(created.changedPrefabKeys, <String>['level_stone_block_01']);

    expect(
      apply(
        const PrefabV3UpsertSliceOperation(
          kind: AtlasSliceKind.prefab,
          slice: AtlasSliceDef(
            id: 'slice_a',
            sourceImagePath: 'assets/images/level/test.png',
            x: 0,
            y: 0,
            width: 10,
            height: 10,
          ),
          createPrefabKind: PrefabKind.decoration,
        ),
      ),
      same(document),
    );
    expect(
      apply(
        const PrefabV3UpsertSliceOperation(
          kind: AtlasSliceKind.prefab,
          slice: AtlasSliceDef(
            id: 'target',
            sourceImagePath: 'assets/images/level/test.png',
            x: 0,
            y: 0,
            width: 4,
            height: 4,
          ),
          createPrefabKind: PrefabKind.decoration,
        ),
      ),
      same(document),
    );
    expect(
      apply(
        const PrefabV3UpsertSliceOperation(
          kind: AtlasSliceKind.tile,
          slice: AtlasSliceDef(
            id: 'tile_with_prefab',
            sourceImagePath: 'assets/images/level/test.png',
            x: 0,
            y: 0,
            width: 4,
            height: 4,
          ),
          createPrefabKind: PrefabKind.obstacle,
        ),
      ),
      same(document),
    );
  });

  test('new prefab slices enforce the collection naming convention', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    const policy = PrefabV3CatalogCommitPolicy();

    for (final id in <String>[
      'Level Stone 01',
      'forest_stone_01',
      'level_stone_1',
      'level_01',
    ]) {
      final result = policy.apply(
        document: document,
        commit: PrefabV3CatalogCommit(
          before: PrefabV3CatalogSnapshot.fromDocument(document),
          operation: PrefabV3UpsertSliceOperation(
            kind: AtlasSliceKind.prefab,
            slice: AtlasSliceDef(
              id: id,
              sourceImagePath: 'assets/images/level/test.png',
              x: 0,
              y: 0,
              width: 4,
              height: 4,
            ),
          ),
        ),
      );

      expect(result.accepted, isFalse, reason: id);
      expect(result.changed, isFalse, reason: id);
      expect(result.document, same(document), reason: id);
      expect(
        result.issues.single.code,
        'prefab_v3_slice_id_convention_invalid',
        reason: id,
      );
    }
  });

  test('typed module lifecycle propagates references and revisions once', () {
    final document = _catalogDocument();

    PrefabV3Document apply(
      PrefabV3Document source,
      PrefabV3CatalogOperation operation,
    ) => plugin.applyEdit(
      source,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(source),
            operation: operation,
          ),
        },
      ),
    ) as PrefabV3Document;

    final updated = apply(
      document,
      PrefabV3UpdateModuleOperation(
        moduleId: 'module_a',
        status: TileModuleStatus.deprecated,
        tileSize: 16,
        cells: const <TileModuleCellDef>[
          TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
          TileModuleCellDef(sliceId: 'tile_a', gridX: 1, gridY: 0),
        ],
      ),
    );
    expect(updated.tileData.platformModules.single.revision, 3);
    expect(updated.data.prefabs.single.revision, 8);
    expect(updated.data.prefabs.single.status, PrefabStatus.deprecated);
    expect(updated.visualBoundsByPrefabKey['platform']?.widthPx, 32);

    final renamed = apply(
      updated,
      const PrefabV3RenameModuleOperation(
        moduleId: 'module_a',
        nextId: 'module_b',
      ),
    );
    final renamedModule = renamed.tileData.platformModules.single;
    final referencingPrefab = renamed.data.prefabs.single;
    expect(renamedModule.id, 'module_b');
    expect(renamedModule.revision, 4);
    expect(referencingPrefab.moduleId, 'module_b');
    expect(referencingPrefab.revision, 9);
    expect(renamed.changedPrefabKeys, <String>['platform']);

    final duplicated = apply(
      renamed,
      const PrefabV3DuplicateModuleOperation(sourceModuleId: 'module_b'),
    );
    expect(
      duplicated.tileData.platformModules
          .singleWhere((module) => module.id == 'module_b_copy')
          .revision,
      1,
    );
    final duplicatedPrefab = duplicated.data.prefabs.singleWhere(
      (prefab) => prefab.moduleId == 'module_b_copy',
    );
    expect(duplicatedPrefab.id, 'module_b_copy_platform');
    expect(duplicatedPrefab.status, PrefabStatus.active);
    expect(duplicatedPrefab.revision, 1);
    expect(duplicatedPrefab.collisionShapes, referencingPrefab.collisionShapes);

    final created = apply(
      duplicated,
      PrefabV3CreateModuleOperation(
        id: 'module_c',
        status: TileModuleStatus.active,
        tileSize: 16,
        cells: const <TileModuleCellDef>[
          TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
        ],
      ),
    );
    expect(
      created.tileData.platformModules
          .singleWhere((module) => module.id == 'module_c')
          .revision,
      1,
    );
    final createdPrefab = created.data.prefabs.singleWhere(
      (prefab) => prefab.moduleId == 'module_c',
    );
    expect(createdPrefab.id, 'module_c_platform');
    expect(createdPrefab.status, PrefabStatus.active);
    expect(createdPrefab.anchorXPx, 8);
    expect(createdPrefab.anchorYPx, 8);
    expect(createdPrefab.collisionShapes, isEmpty);

    final deleted = apply(
      created,
      PrefabV3DeleteModuleOperation(
        moduleId: 'module_b_copy',
        pairedPrefabKey: duplicatedPrefab.prefabKey,
      ),
    );
    expect(
      deleted.tileData.platformModules.any(
        (module) => module.id == 'module_b_copy',
      ),
      isFalse,
    );
    expect(
      deleted.data.prefabs.any(
        (prefab) => prefab.prefabKey == duplicatedPrefab.prefabKey,
      ),
      isFalse,
    );

    final pending = plugin.describePendingChanges(
      EditorWorkspace(rootPath: Directory.current.path),
      document: deleted,
    );
    expect(pending.fileDiffs, hasLength(2));
    expect(
      pending.fileDiffs.map((diff) => diff.relativePath),
      containsAll(<String>[
        'assets/authoring/level/prefab_defs.json',
        'assets/authoring/level/tile_defs.json',
      ]),
    );
  });

  test('module pairing preserves ambiguous custom prefab variants', () {
    final original = _catalogDocument();
    final sourcePrefab = original.data.prefabs.single;
    final variant = sourcePrefab.copyWith(
      prefabKey: 'platform_variant',
      id: 'platform_variant',
      revision: 3,
    );
    final document = original.copyWith(
      data: original.data.copyWith(
        prefabs: <PrefabV3Def>[sourcePrefab, variant],
      ),
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
        'platform': PrefabV3VisualBounds(widthPx: 32, heightPx: 16),
        'platform_variant': PrefabV3VisualBounds(widthPx: 32, heightPx: 16),
      },
    );

    PrefabV3Document apply(
      PrefabV3Document source,
      PrefabV3CatalogOperation operation,
    ) => plugin.applyEdit(
      source,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(source),
            operation: operation,
          ),
        },
      ),
    ) as PrefabV3Document;

    final deprecated = apply(
      document,
      PrefabV3UpdateModuleOperation(
        moduleId: 'module_a',
        status: TileModuleStatus.deprecated,
        tileSize: 16,
        cells: original.tileData.platformModules.single.cells,
      ),
    );
    expect(
      deprecated.data.prefabs.map((prefab) => prefab.status),
      everyElement(PrefabStatus.active),
    );
    expect(deprecated.data.prefabs.map((prefab) => prefab.revision), <int>[
      7,
      3,
    ]);

    final renamed = apply(
      deprecated,
      const PrefabV3RenameModuleOperation(
        moduleId: 'module_a',
        nextId: 'module_shared',
      ),
    );
    expect(renamed.data.prefabs.map((prefab) => prefab.id), <String>[
      'platform',
      'platform_variant',
    ]);
    expect(
      renamed.data.prefabs.map((prefab) => prefab.moduleId),
      everyElement('module_shared'),
    );

    final duplicated = apply(
      renamed,
      const PrefabV3DuplicateModuleOperation(sourceModuleId: 'module_shared'),
    );
    final pairedDuplicate = duplicated.data.prefabs.singleWhere(
      (prefab) => prefab.moduleId == 'module_shared_copy',
    );
    expect(pairedDuplicate.id, 'module_shared_copy_platform');
    expect(pairedDuplicate.collisionShapes, isEmpty);
  });

  test('explicit collision setup pairs retained deprecated modules', () {
    final original = _catalogDocument();
    final document = original.copyWith(
      data: original.data.copyWith(prefabs: const <PrefabV3Def>[]),
      tileData: original.tileData.copyWith(
        platformModules: <TileModuleDef>[
          original.tileData.platformModules.single.copyWith(
            status: TileModuleStatus.deprecated,
          ),
        ],
      ),
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{},
    );
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: const PrefabV3EnsurePlatformPrefabOperation(
              moduleId: 'module_a',
            ),
          ),
        },
      ),
    ) as PrefabV3Document;

    final prefab = edited.data.prefabs.single;
    expect(prefab.id, 'module_a_platform');
    expect(prefab.status, PrefabStatus.deprecated);
    expect(prefab.visualSource.type, PrefabVisualSourceType.platformModule);
    expect(prefab.moduleId, 'module_a');
    expect(prefab.collisionShapes, isEmpty);
  });

  test('catalog commits reject stale noncanonical and referenced deletes', () {
    final document = _catalogDocument();
    final before = PrefabV3CatalogSnapshot.fromDocument(document);

    AuthoringDocument apply(PrefabV3CatalogCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{'commit': commit},
      ),
    );

    final staleDocument = document.copyWith(
      tileData: document.tileData.copyWith(
        platformModules: <TileModuleDef>[
          document.tileData.platformModules.single.copyWith(revision: 3),
        ],
      ),
    );
    expect(
      apply(
        PrefabV3CatalogCommit(
          before: PrefabV3CatalogSnapshot.fromDocument(staleDocument),
          operation: const PrefabV3DeleteModuleOperation(moduleId: 'module_a'),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3CatalogCommit(
          before: before,
          operation: const PrefabV3DeleteModuleOperation(moduleId: 'module_a'),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3CatalogCommit(
          before: before,
          operation: PrefabV3UpdateModuleOperation(
            moduleId: 'module_a',
            status: TileModuleStatus.active,
            tileSize: 16,
            cells: const <TileModuleCellDef>[
              TileModuleCellDef(sliceId: 'tile_a', gridX: 1, gridY: 0),
              TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
            ],
          ),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3CatalogCommit(
          before: before,
          operation: const PrefabV3UpsertSliceOperation(
            kind: AtlasSliceKind.tile,
            slice: AtlasSliceDef(
              id: 'tile_b',
              sourceImagePath: 'assets/images/level/missing.png',
              x: 0,
              y: 0,
              width: 16,
              height: 16,
            ),
          ),
        ),
      ),
      same(document),
    );
  });

  test('tile-slice cascade bumps each affected module exactly once', () {
    final document = _catalogDocument();
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: const PrefabV3DeleteSliceOperation(
              kind: AtlasSliceKind.tile,
              sliceId: 'tile_a',
              cascadeReferences: true,
            ),
          ),
        },
      ),
    ) as PrefabV3Document;

    expect(edited.tileData.tileSlices.single.id, 'tile_b');
    expect(edited.tileData.platformModules.single.revision, 3);
    expect(
      edited.tileData.platformModules.single.cells.single.sliceId,
      'tile_b',
    );
    expect(edited.data.prefabs.single.revision, 7);
  });

  test('paired platform mutation rejects absent source baselines', () async {
    final root = Directory.systemTemp.createTempSync('prefab_v3_catalog_');
    addTearDown(() => root.deleteSync(recursive: true));
    final document = _catalogDocument();
    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3CatalogCommandKind,
        payload: <String, Object?>{
          'commit': PrefabV3CatalogCommit(
            before: PrefabV3CatalogSnapshot.fromDocument(document),
            operation: PrefabV3CreateModuleOperation(
              id: 'module_c',
              status: TileModuleStatus.active,
              tileSize: 16,
              cells: const <TileModuleCellDef>[
                TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
              ],
            ),
          ),
        },
      ),
    );
    final pending = plugin.describePendingChanges(
      EditorWorkspace(rootPath: root.path),
      document: edited,
    );
    expect(pending.fileDiffs, hasLength(2));
    expect(
      pending.fileDiffs.map((diff) => diff.relativePath),
      containsAll(<String>[
        'assets/authoring/level/prefab_defs.json',
        'assets/authoring/level/tile_defs.json',
      ]),
    );

    await expectLater(
      plugin.exportToRepo(
        EditorWorkspace(rootPath: root.path),
        document: edited,
      ),
      throwsA(
        isA<PrefabV3SaveException>().having(
          (error) => error.code,
          'code',
          'prefab_v3_save_source_drift',
        ),
      ),
    );
    expect(root.listSync(recursive: true), isEmpty);
  });

  test('polygon commits reject newly overlapping downstream placements', () {
    final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
    final chunk = _chunk(
      placements: const <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: 'target', prefabKey: 'target', x: 10, y: 10),
      ],
      directShapes: <TerrainSourceShapeDef>[
        _namedRectangle('ground', left: 28, top: 12, right: 40, bottom: 28),
      ],
    );
    final document = _document(
      before,
      downstreamChunks: <PrefabV3DownstreamChunk>[_downstreamChunk(chunk)],
    );

    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
        payload: <String, Object?>{
          'prefabKey': 'target',
          'commit': _commit(
            before: before,
            after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
          ),
        },
      ),
    );

    expect(edited, same(document));
  });

  test('polygon commits reject transformed downstream bounds failures', () {
    final before = <TerrainSourceShapeDef>[
      _namedRectangle('collision_001', left: 0, top: 0, right: 8, bottom: 8),
    ];
    final chunk = _chunk(
      width: 10,
      height: 20,
      placements: const <PlacedPrefabDef>[
        PlacedPrefabDef(
          prefabId: 'target',
          prefabKey: 'target',
          x: 4,
          y: 4,
          scale: 1.5,
        ),
      ],
    );
    final document = _document(
      before,
      downstreamChunks: <PrefabV3DownstreamChunk>[_downstreamChunk(chunk)],
    );

    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
        payload: <String, Object?>{
          'prefabKey': 'target',
          'commit': _commit(
            before: before,
            after: <TerrainSourceShapeDef>[
              _namedRectangle(
                'collision_001',
                left: 0,
                top: 0,
                right: 10,
                bottom: 8,
              ),
            ],
          ),
        },
      ),
    );

    expect(edited, same(document));
  });

  test(
    'pre-existing downstream errors do not block an unrelated valid edit',
    () {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final chunk = _chunk(
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'target',
            prefabKey: 'target',
            x: 10,
            y: 10,
          ),
        ],
        directShapes: <TerrainSourceShapeDef>[
          _namedRectangle('ground_a', left: 40, top: 40, right: 60, bottom: 60),
          _namedRectangle('ground_b', left: 50, top: 50, right: 70, bottom: 70),
        ],
      );
      final document = _document(
        before,
        downstreamChunks: <PrefabV3DownstreamChunk>[_downstreamChunk(chunk)],
      );

      final edited = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
            ),
          },
        ),
      );

      expect(edited, isNot(same(document)));
    },
  );

  test('unreferenced Prefab edits do not acquire Chunk write authority', () {
    final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
    final document = _document(
      before,
      downstreamChunks: <PrefabV3DownstreamChunk>[_downstreamChunk(_chunk())],
    );

    final edited = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
        payload: <String, Object?>{
          'prefabKey': 'target',
          'commit': _commit(
            before: before,
            after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
          ),
        },
      ),
    );

    expect(edited, isNot(same(document)));
    expect((edited as PrefabV3Document).changedPrefabKeys, <String>['target']);
  });

  test(
    'export rejects affected Chunk source drift before writing Prefabs',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'prefab_downstream_drift_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final chunk = _chunk(
        placements: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'target',
            prefabKey: 'target',
            x: 20,
            y: 20,
          ),
        ],
      );
      final source = _downstreamChunk(chunk);
      final document = _document(
        before,
        downstreamImpacts: <PrefabV3DownstreamImpact>[
          PrefabV3DownstreamImpact(
            prefabKey: 'target',
            referencingChunkKeys: <String>['forest_test'],
            placementCount: 1,
          ),
        ],
        downstreamChunks: <PrefabV3DownstreamChunk>[source],
      );
      final edited = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
            ),
          },
        ),
      );
      expect(edited, isNot(same(document)));

      final chunkFile = File('${root.path}/${source.sourcePath}')
        ..createSync(recursive: true)
        ..writeAsStringSync('${source.baselineContents}\n');
      expect(chunkFile.existsSync(), isTrue);

      await expectLater(
        plugin.exportToRepo(
          EditorWorkspace(rootPath: root.path),
          document: edited,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('changed after Prefab review'),
          ),
        ),
      );
      expect(
        File('${root.path}/${PrefabStore.prefabDefsPath}').existsSync(),
        isFalse,
      );
    },
  );

  test('export independently rechecks introduced downstream errors', () async {
    final root = Directory.systemTemp.createTempSync(
      'prefab_downstream_export_review_',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
    final chunk = _chunk(
      placements: const <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: 'target', prefabKey: 'target', x: 10, y: 10),
      ],
      directShapes: <TerrainSourceShapeDef>[
        _namedRectangle('ground', left: 28, top: 12, right: 40, bottom: 28),
      ],
    );
    final source = _downstreamChunk(chunk);
    final original = _document(
      before,
      downstreamImpacts: <PrefabV3DownstreamImpact>[
        PrefabV3DownstreamImpact(
          prefabKey: 'target',
          referencingChunkKeys: <String>['forest_test'],
          placementCount: 1,
        ),
      ],
      downstreamChunks: <PrefabV3DownstreamChunk>[source],
    );
    final candidateOwner = original.data.prefabs.single.copyWith(
      revision: original.data.prefabs.single.revision + 1,
      collisionShapes: <TerrainSourceShapeDef>[_rectangle(right: 10)],
    );
    final candidate = original.copyWith(
      data: original.data.copyWith(prefabs: <PrefabV3Def>[candidateOwner]),
      changedPrefabKeys: const <String>['target'],
    );
    for (final entry in <String, String>{
      PrefabStore.prefabDefsPath: original.prefabBaselineContents!,
      PrefabStore.tileDefsPath: original.tileBaselineContents!,
      source.sourcePath: source.baselineContents,
    }.entries) {
      File('${root.path}/${entry.key}')
        ..createSync(recursive: true)
        ..writeAsStringSync(entry.value);
    }

    await expectLater(
      plugin.exportToRepo(
        EditorWorkspace(rootPath: root.path),
        document: candidate,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('invalidate Chunk forest_test'),
        ),
      ),
    );
    expect(
      File('${root.path}/${PrefabStore.prefabDefsPath}').readAsStringSync(),
      original.prefabBaselineContents,
    );
  });
}

PrefabV3Document _document(
  Iterable<TerrainSourceShapeDef> shapes, {
  Iterable<PrefabV3DownstreamImpact> downstreamImpacts =
      const <PrefabV3DownstreamImpact>[],
  Iterable<PrefabV3DownstreamChunk> downstreamChunks =
      const <PrefabV3DownstreamChunk>[],
}) {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'slice_a',
        sourceImagePath: 'assets/images/level/test.png',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
    ],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'target',
        id: 'target',
        revision: 4,
        status: PrefabStatus.active,
        kind: PrefabKind.obstacle,
        visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
        anchorXPx: 5,
        anchorYPx: 5,
        collisionShapes: shapes,
        tags: const <String>['test'],
      ),
    ],
  );
  return PrefabV3Document(
    data: data,
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'target': PrefabV3VisualBounds(widthPx: 10, heightPx: 10),
    },
    atlasImagePaths: const <String>[],
    atlasImageSizes: const <String, Size>{
      'assets/images/level/test.png': Size(20, 20),
    },
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: PrefabTileFileCodec.encode(
      PrefabTileFileData(
        tileSlices: const <AtlasSliceDef>[],
        platformModules: const <TileModuleDef>[],
      ),
    ),
    downstreamImpacts: downstreamImpacts,
    downstreamChunks: downstreamChunks,
  );
}

PrefabV3Document _catalogDocument() {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'platform',
        id: 'platform',
        revision: 7,
        status: PrefabStatus.active,
        kind: PrefabKind.platform,
        visualSource: const PrefabVisualSource.platformModule('module_a'),
        anchorXPx: 8,
        anchorYPx: 8,
        collisionShapes: <TerrainSourceShapeDef>[
          _rectangle(
            right: 8,
            collisionMode: TerrainSourceCollisionMode.oneWay,
          ),
        ],
        tags: const <String>[],
      ),
    ],
  );
  final tileData = PrefabTileFileData(
    tileSlices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'tile_a',
        sourceImagePath: 'assets/images/level/test.png',
        x: 0,
        y: 0,
        width: 16,
        height: 16,
      ),
      AtlasSliceDef(
        id: 'tile_b',
        sourceImagePath: 'assets/images/level/test.png',
        x: 16,
        y: 0,
        width: 16,
        height: 16,
      ),
    ],
    platformModules: const <TileModuleDef>[
      TileModuleDef(
        id: 'module_a',
        revision: 2,
        status: TileModuleStatus.active,
        tileSize: 16,
        cells: <TileModuleCellDef>[
          TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
          TileModuleCellDef(sliceId: 'tile_b', gridX: 1, gridY: 0),
        ],
      ),
    ],
  );
  return PrefabV3Document(
    data: data,
    tileData: tileData,
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'platform': PrefabV3VisualBounds(widthPx: 16, heightPx: 16),
    },
    atlasImagePaths: const <String>['assets/images/level/test.png'],
    atlasImageSizes: const <String, Size>{
      'assets/images/level/test.png': Size(64, 32),
    },
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: PrefabTileFileCodec.encode(tileData),
  );
}

TerrainPolygonInteractionCommit _commit({
  required Iterable<TerrainSourceShapeDef> before,
  required Iterable<TerrainSourceShapeDef> after,
}) => TerrainPolygonInteractionCommit(
  beforeShapes: before,
  afterShapes: after,
  beforeSelection: null,
  afterSelection: null,
);

TerrainSourceShapeDef _rectangle({
  int left = -8,
  required int right,
  TerrainSourceCollisionMode collisionMode = TerrainSourceCollisionMode.solid,
}) => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  collisionMode: collisionMode,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: 8),
  ],
);

TerrainSourceShapeDef _namedRectangle(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: bottom),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: bottom),
  ],
);

ChunkV2FileData _chunk({
  int width = 100,
  int height = 100,
  Iterable<PlacedPrefabDef> placements = const <PlacedPrefabDef>[],
  Iterable<TerrainSourceShapeDef> directShapes =
      const <TerrainSourceShapeDef>[],
}) => ChunkV2FileData(
  chunkKey: 'forest_test',
  id: 'forest_test',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: width,
  height: height,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>[],
  tileLayers: const <TileLayerDef>[],
  prefabs: placements,
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: directShapes,
);

PrefabV3DownstreamChunk _downstreamChunk(ChunkV2FileData chunk) =>
    PrefabV3DownstreamChunk(
      data: chunk,
      sourcePath: 'assets/authoring/level/chunks/${chunk.chunkKey}.json',
      baselineContents: ChunkV2FileCodec.encode(chunk),
    );

TerrainSourceShapeDef _selfIntersectingShape() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

List<TerrainSourceShapeDef> _capacityShapes(int count) =>
    <TerrainSourceShapeDef>[
      for (var index = 0; index < count; index += 1)
        TerrainSourceShapeDef(
          shapeId: 'collision_${index.toString().padLeft(3, '0')}',
          vertices: <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(
              xHalfPixels: -10 + (index % 5) * 4,
              yHalfPixels: -10 + (index ~/ 5) * 4,
            ),
            TerrainSourceVertexDef(
              xHalfPixels: -6 + (index % 5) * 4,
              yHalfPixels: -10 + (index ~/ 5) * 4,
            ),
            TerrainSourceVertexDef(
              xHalfPixels: -6 + (index % 5) * 4,
              yHalfPixels: -6 + (index ~/ 5) * 4,
            ),
            TerrainSourceVertexDef(
              xHalfPixels: -10 + (index % 5) * 4,
              yHalfPixels: -6 + (index ~/ 5) * 4,
            ),
          ],
        ),
    ];
