import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('rename preserves chunkKey and revision, deprecate bumps revision', () {
    final plugin = ChunkDomainPlugin();
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 3,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default', 'cemetery'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
    );

    final renamed =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'rename_chunk',
                payload: <String, Object?>{
                  'chunkKey': 'chunk_a',
                  'id': 'chunk_a_renamed',
                },
              ),
            )
            as ChunkDocument;

    expect(renamed.chunks, hasLength(1));
    expect(renamed.chunks.single.chunkKey, 'chunk_a');
    expect(renamed.chunks.single.id, 'chunk_a_renamed');
    expect(renamed.chunks.single.revision, 3);

    final deprecated =
        plugin.applyEdit(
              renamed,
              AuthoringCommand(
                kind: 'deprecate_chunk',
                payload: <String, Object?>{'chunkKey': 'chunk_a'},
              ),
            )
            as ChunkDocument;
    expect(deprecated.chunks.single.status, chunkStatusDeprecated);
    expect(deprecated.chunks.single.revision, 4);
  });

  test('delete removes chunk and reports missing source for unknown key', () {
    final plugin = ChunkDomainPlugin();
    const chunkA = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
    );
    const chunkB = LevelChunkDef(
      chunkKey: 'chunk_b',
      id: 'chunk_b',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunkA, chunkB],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
    );

    final afterDelete =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'delete_chunk',
                payload: <String, Object?>{'chunkKey': 'chunk_a'},
              ),
            )
            as ChunkDocument;
    expect(afterDelete.chunks, hasLength(1));
    expect(afterDelete.chunks.single.chunkKey, 'chunk_b');

    final missing =
        plugin.applyEdit(
              afterDelete,
              AuthoringCommand(
                kind: 'delete_chunk',
                payload: <String, Object?>{'chunkKey': 'chunk_missing'},
              ),
            )
            as ChunkDocument;
    expect(
      missing.operationIssues.map((issue) => issue.code),
      contains('delete_chunk_missing_source'),
    );
  });

  test('duplicate allocates new key and create fails on ID collision', () {
    final plugin = ChunkDomainPlugin();
    const base = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 5,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[base],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default', 'cemetery'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
    );

    final duplicated =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'duplicate_chunk',
                payload: <String, Object?>{'chunkKey': 'chunk_a'},
              ),
            )
            as ChunkDocument;
    expect(duplicated.chunks, hasLength(2));
    final duplicate = duplicated.chunks.firstWhere(
      (chunk) => chunk.chunkKey != 'chunk_a',
    );
    expect(duplicate.revision, 1);
    expect(duplicate.id, isNot('chunk_a'));

    final collisionCreate =
        plugin.applyEdit(
              duplicated,
              AuthoringCommand(
                kind: 'create_chunk',
                payload: <String, Object?>{'id': 'chunk_a'},
              ),
            )
            as ChunkDocument;
    expect(collisionCreate.chunks, hasLength(2));
    expect(
      plugin
          .validate(collisionCreate)
          .map((issue) => issue.code)
          .contains('create_chunk_id_collision'),
      isTrue,
    );

    final created =
        plugin.applyEdit(
              duplicated,
              AuthoringCommand(
                kind: 'create_chunk',
                payload: <String, Object?>{'id': 'chunk_b'},
              ),
            )
            as ChunkDocument;
    expect(created.chunks, hasLength(3));
    final createdChunk = created.chunks.firstWhere(
      (chunk) => chunk.id == 'chunk_b',
    );
    expect(createdChunk.chunkKey, isNot('chunk_a'));
    expect(createdChunk.revision, 1);
    expect(createdChunk.height, 270);
    expect(createdChunk.groundProfile.topY, 224);
  });

  test(
    'duplicate fails on explicit target ID collision with operation issue',
    () {
      final plugin = ChunkDomainPlugin();
      const base = LevelChunkDef(
        chunkKey: 'chunk_a',
        id: 'chunk_a',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );
      const other = LevelChunkDef(
        chunkKey: 'chunk_b',
        id: 'chunk_b',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[base, other],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        assemblyGroupOptionsByLevelId: <String, List<String>>{
          'field': <String>['default', 'cemetery'],
        },
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
        runtimeGroundTopY: 224,
      );

      final next =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: 'duplicate_chunk',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'id': 'chunk_b',
                  },
                ),
              )
              as ChunkDocument;
      expect(next.chunks, hasLength(2));
      expect(
        plugin
            .validate(next)
            .map((issue) => issue.code)
            .contains('duplicate_chunk_id_collision'),
        isTrue,
      );
    },
  );

  test(
    'metadata, ground, and ground band edits bump revision deterministically',
    () {
      final plugin = ChunkDomainPlugin();
      const base = LevelChunkDef(
        chunkKey: 'chunk_a',
        id: 'chunk_a',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        assemblyGroupId: defaultChunkAssemblyGroupId,
        tags: <String>['base'],
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[base],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        assemblyGroupOptionsByLevelId: <String, List<String>>{
          'field': <String>['default', 'cemetery'],
        },
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
        runtimeGroundTopY: 224,
      );

      final afterMetadata =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: 'update_chunk_metadata',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'assemblyGroupId': 'cemetery',
                    'tags': 'base, updated',
                  },
                ),
              )
              as ChunkDocument;
      expect(afterMetadata.chunks.single.revision, 2);
      expect(afterMetadata.chunks.single.assemblyGroupId, 'cemetery');
      expect(afterMetadata.chunks.single.tags, <String>['base', 'updated']);

      final noOpMetadata =
          plugin.applyEdit(
                afterMetadata,
                AuthoringCommand(
                  kind: 'update_chunk_metadata',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'assemblyGroupId': 'cemetery',
                    'tags': 'base, updated',
                  },
                ),
              )
              as ChunkDocument;
      expect(noOpMetadata.chunks.single.revision, 2);

      final afterGround =
          plugin.applyEdit(
                noOpMetadata,
                AuthoringCommand(
                  kind: 'update_ground_profile',
                  payload: <String, Object?>{'chunkKey': 'chunk_a', 'topY': 16},
                ),
              )
              as ChunkDocument;
      expect(afterGround.chunks.single.revision, 2);
      expect(afterGround.chunks.single.groundProfile.topY, 224);

      final afterGroundBand =
          plugin.applyEdit(
                afterGround,
                AuthoringCommand(
                  kind: 'update_ground_band_z_index',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'groundBandZIndex': 1,
                  },
                ),
              )
              as ChunkDocument;
      expect(afterGroundBand.chunks.single.revision, 3);
      expect(afterGroundBand.chunks.single.groundBandZIndex, 1);

      final noOpGroundBand =
          plugin.applyEdit(
                afterGroundBand,
                AuthoringCommand(
                  kind: 'update_ground_band_z_index',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'groundBandZIndex': 1,
                  },
                ),
              )
              as ChunkDocument;
      expect(noOpGroundBand.chunks.single.revision, 3);
    },
  );

  test(
    'no-op commands keep document identity when no operation issues exist',
    () {
      final plugin = ChunkDomainPlugin();
      const chunk = LevelChunkDef(
        chunkKey: 'chunk_a',
        id: 'chunk_a',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[chunk],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        assemblyGroupOptionsByLevelId: <String, List<String>>{
          'field': <String>['default', 'cemetery'],
        },
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
        runtimeGroundTopY: 224,
      );

      final noOpRename = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: 'rename_chunk',
          payload: <String, Object?>{'chunkKey': 'chunk_a', 'id': 'chunk_a'},
        ),
      );
      expect(identical(noOpRename, document), isTrue);
    },
  );

  test('valid no-op clears stale operation issues', () {
    final plugin = ChunkDomainPlugin();
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default', 'cemetery'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
      operationIssues: <ValidationIssue>[
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'rename_chunk_invalid_payload',
          message: 'stale',
        ),
      ],
    );

    final cleared = plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: 'rename_chunk',
        payload: <String, Object?>{'chunkKey': 'chunk_a', 'id': 'chunk_a'},
      ),
    );

    expect(identical(cleared, document), isFalse);
    expect((cleared as ChunkDocument).operationIssues, isEmpty);
  });

  test('update ground gap reports missing gap id', () {
    final plugin = ChunkDomainPlugin();
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: groundGapTypePit, x: 16, width: 32),
      ],
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      assemblyGroupOptionsByLevelId: <String, List<String>>{
        'field': <String>['default', 'cemetery'],
      },
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
      runtimeGroundTopY: 224,
    );

    final next =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: 'update_ground_gap',
                payload: <String, Object?>{
                  'chunkKey': 'chunk_a',
                  'gapId': 'gap_missing',
                  'width': 48,
                },
              ),
            )
            as ChunkDocument;

    final codes = plugin.validate(next).map((issue) => issue.code).toSet();
    expect(codes, contains('update_ground_gap_missing_gap'));
  });

  test(
    'prefab placement commands add move replace and remove deterministically',
    () {
      final plugin = ChunkDomainPlugin();
      const chunk = LevelChunkDef(
        chunkKey: 'chunk_a',
        id: 'chunk_a',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      );
      final document = ChunkDocument(
        chunks: const <LevelChunkDef>[chunk],
        baselineByChunkKey: const <String, ChunkSourceBaseline>{},
        availableLevelIds: const <String>['field'],
        assemblyGroupOptionsByLevelId: const <String, List<String>>{
          'field': <String>['default', 'cemetery'],
        },
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
        runtimeGroundTopY: 224,
        prefabData: PrefabData(
          prefabs: <PrefabDef>[
            PrefabDef(
              prefabKey: 'crate_a',
              id: 'crate_a',
              revision: 1,
              status: PrefabStatus.active,
              kind: PrefabKind.obstacle,
              visualSource: const PrefabVisualSource.atlasSlice('crate_slice'),
              anchorXPx: 16,
              anchorYPx: 16,
              colliders: const <PrefabColliderDef>[
                PrefabColliderDef(
                  offsetX: 0,
                  offsetY: 0,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
            PrefabDef(
              prefabKey: 'crate_b',
              id: 'crate_b',
              revision: 1,
              status: PrefabStatus.active,
              kind: PrefabKind.obstacle,
              visualSource: const PrefabVisualSource.atlasSlice('crate_slice'),
              anchorXPx: 16,
              anchorYPx: 16,
              colliders: const <PrefabColliderDef>[
                PrefabColliderDef(
                  offsetX: 0,
                  offsetY: 0,
                  width: 16,
                  height: 16,
                ),
              ],
            ),
          ],
        ),
      );

      final added =
          plugin.applyEdit(
                document,
                AuthoringCommand(
                  kind: 'add_prefab_placement',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'prefabKey': 'crate_a',
                    'x': 32,
                    'y': 0,
                    'zIndex': 2,
                    'snapToGrid': false,
                    'scale': 1.4,
                  },
                ),
              )
              as ChunkDocument;
      expect(added.chunks.single.prefabs, hasLength(1));
      expect(added.chunks.single.prefabs.single.zIndex, 2);
      expect(added.chunks.single.prefabs.single.snapToGrid, isFalse);
      expect(added.chunks.single.prefabs.single.scale, 1.4);
      expect(added.chunks.single.revision, 2);

      final selectionKey = buildChunkPlacedPrefabSelections(
        added.chunks.single.prefabs,
      ).single.selectionKey;

      final moved =
          plugin.applyEdit(
                added,
                AuthoringCommand(
                  kind: 'move_prefab_placement',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'selectionKey': selectionKey,
                    'x': 64,
                    'y': 16,
                  },
                ),
              )
              as ChunkDocument;
      expect(moved.chunks.single.prefabs.single.x, 64);
      expect(moved.chunks.single.prefabs.single.y, 16);
      expect(moved.chunks.single.revision, 3);

      final movedSelectionKey = buildChunkPlacedPrefabSelections(
        moved.chunks.single.prefabs,
      ).single.selectionKey;
      final replaced =
          plugin.applyEdit(
                moved,
                AuthoringCommand(
                  kind: 'replace_prefab_placement',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'selectionKey': movedSelectionKey,
                    'prefabKey': 'crate_b',
                  },
                ),
              )
              as ChunkDocument;
      expect(replaced.chunks.single.prefabs.single.prefabKey, 'crate_b');
      expect(replaced.chunks.single.prefabs.single.prefabId, 'crate_b');
      expect(replaced.chunks.single.prefabs.single.zIndex, 2);
      expect(replaced.chunks.single.prefabs.single.snapToGrid, isFalse);
      expect(replaced.chunks.single.prefabs.single.scale, 1.4);
      expect(replaced.chunks.single.revision, 4);

      final updatedSnapSelectionKey = buildChunkPlacedPrefabSelections(
        replaced.chunks.single.prefabs,
      ).single.selectionKey;
      final snapUpdated =
          plugin.applyEdit(
                replaced,
                AuthoringCommand(
                  kind: 'update_prefab_placement_settings',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'selectionKey': updatedSnapSelectionKey,
                    'zIndex': 5,
                    'snapToGrid': true,
                    'scale': 0.7,
                  },
                ),
              )
              as ChunkDocument;
      expect(snapUpdated.chunks.single.prefabs.single.zIndex, 5);
      expect(snapUpdated.chunks.single.prefabs.single.snapToGrid, isTrue);
      expect(snapUpdated.chunks.single.prefabs.single.scale, 0.7);
      expect(snapUpdated.chunks.single.revision, 5);

      final replacedSelectionKey = buildChunkPlacedPrefabSelections(
        snapUpdated.chunks.single.prefabs,
      ).single.selectionKey;
      final removed =
          plugin.applyEdit(
                snapUpdated,
                AuthoringCommand(
                  kind: 'remove_prefab_placement',
                  payload: <String, Object?>{
                    'chunkKey': 'chunk_a',
                    'selectionKey': replacedSelectionKey,
                  },
                ),
              )
              as ChunkDocument;
      expect(removed.chunks.single.prefabs, isEmpty);
      expect(removed.chunks.single.revision, 6);
    },
  );
}
