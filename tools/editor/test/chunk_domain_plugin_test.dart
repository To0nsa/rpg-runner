import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';

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
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final renamed =
        plugin.applyEdit(
              document,
              const AuthoringCommand(
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
              const AuthoringCommand(
                kind: 'deprecate_chunk',
                payload: <String, Object?>{'chunkKey': 'chunk_a'},
              ),
            )
            as ChunkDocument;
    expect(deprecated.chunks.single.status, chunkStatusDeprecated);
    expect(deprecated.chunks.single.revision, 4);
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
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[base],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final duplicated =
        plugin.applyEdit(
              document,
              const AuthoringCommand(
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
              const AuthoringCommand(
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
              const AuthoringCommand(
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
        height: 160,
        entrySocket: 'in',
        exitSocket: 'out',
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      );
      const other = LevelChunkDef(
        chunkKey: 'chunk_b',
        id: 'chunk_b',
        revision: 1,
        schemaVersion: 1,
        levelId: 'field',
        tileSize: 16,
        width: 600,
        height: 160,
        entrySocket: 'in',
        exitSocket: 'out',
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[base, other],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
      );

      final next =
          plugin.applyEdit(
                document,
                const AuthoringCommand(
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

  test('metadata and ground edits bump revision deterministically', () {
    final plugin = ChunkDomainPlugin();
    const base = LevelChunkDef(
      chunkKey: 'chunk_a',
      id: 'chunk_a',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      tags: <String>['base'],
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[base],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final afterMetadata =
        plugin.applyEdit(
              document,
              const AuthoringCommand(
                kind: 'update_chunk_metadata',
                payload: <String, Object?>{
                  'chunkKey': 'chunk_a',
                  'tags': 'base, updated',
                },
              ),
            )
            as ChunkDocument;
    expect(afterMetadata.chunks.single.revision, 2);
    expect(afterMetadata.chunks.single.tags, <String>['base', 'updated']);

    final noOpMetadata =
        plugin.applyEdit(
              afterMetadata,
              const AuthoringCommand(
                kind: 'update_chunk_metadata',
                payload: <String, Object?>{
                  'chunkKey': 'chunk_a',
                  'tags': 'base, updated',
                },
              ),
            )
            as ChunkDocument;
    expect(noOpMetadata.chunks.single.revision, 2);

    final afterGround =
        plugin.applyEdit(
              noOpMetadata,
              const AuthoringCommand(
                kind: 'update_ground_profile',
                payload: <String, Object?>{'chunkKey': 'chunk_a', 'topY': 16},
              ),
            )
            as ChunkDocument;
    expect(afterGround.chunks.single.revision, 3);
    expect(afterGround.chunks.single.groundProfile.topY, 16);
  });

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
        height: 160,
        entrySocket: 'in',
        exitSocket: 'out',
        difficulty: chunkDifficultyNormal,
        groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      );
      const document = ChunkDocument(
        chunks: <LevelChunkDef>[chunk],
        baselineByChunkKey: <String, ChunkSourceBaseline>{},
        availableLevelIds: <String>['field'],
        activeLevelId: 'field',
        levelOptionSource: 'test',
        runtimeGridSnap: 16.0,
        runtimeChunkWidth: 600.0,
      );

      final noOpRename = plugin.applyEdit(
        document,
        const AuthoringCommand(
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
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
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
      const AuthoringCommand(
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
      height: 160,
      entrySocket: 'in',
      exitSocket: 'out',
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 0),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_1', type: groundGapTypePit, x: 16, width: 32),
      ],
    );
    const document = ChunkDocument(
      chunks: <LevelChunkDef>[chunk],
      baselineByChunkKey: <String, ChunkSourceBaseline>{},
      availableLevelIds: <String>['field'],
      activeLevelId: 'field',
      levelOptionSource: 'test',
      runtimeGridSnap: 16.0,
      runtimeChunkWidth: 600.0,
    );

    final next =
        plugin.applyEdit(
              document,
              const AuthoringCommand(
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
}
