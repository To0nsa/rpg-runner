import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/playtest/chunk_playtest_preparation.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  late String workspaceRoot;
  late ChunkV2Document repositoryDocument;

  setUpAll(() async {
    workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    repositoryDocument = await ChunkDomainPlugin().loadV2FromRepo(
      EditorWorkspace(rootPath: workspaceRoot),
    );
  });

  test('canonical repository snapshot prepares a real admitted scenario', () {
    final input = captureChunkPlaytestPreparationInput(
      document: repositoryDocument,
      selectedChunkKey: 'forest_early_00',
    );
    final result = prepareChunkPlaytest(input);

    expect(result.issues, isEmpty);
    expect(result.scenario, isNotNull);
    expect(result.scenario!.seed, chunkPlaytestDefaultSeed);
    expect(result.scenario!.draftPattern.chunkKey, 'forest_early_00');
    expect(result.scenario!.draftTerrain.chunkKey, 'forest_early_00');
    expect(result.scenario!.levelDefinition.id.name, 'forest');
    expect(result.scenario!.visualThemeId, 'forest');
  });

  test(
    'accepted in-memory prefab edit is compiled without touching baseline',
    () {
      final source = repositoryDocument.chunks.singleWhere(
        (chunk) => chunk.chunkKey == 'forest_early_00',
      );
      final editedPrefabs = source.prefabs.toList(growable: false);
      editedPrefabs[3] = editedPrefabs[3].copyWith(x: editedPrefabs[3].x + 1);
      final editedChunk = source.copyWith(
        revision: source.revision + 1,
        prefabs: editedPrefabs,
      );
      final editedDocument = repositoryDocument.copyWith(
        chunks: [
          for (final chunk in repositoryDocument.chunks)
            if (chunk.chunkKey == editedChunk.chunkKey) editedChunk else chunk,
        ],
        changedChunkKeys: <String>[editedChunk.chunkKey],
      );

      final baseline = prepareChunkPlaytest(
        captureChunkPlaytestPreparationInput(
          document: repositoryDocument,
          selectedChunkKey: source.chunkKey,
        ),
      );
      final editedInput = captureChunkPlaytestPreparationInput(
        document: editedDocument,
        selectedChunkKey: editedChunk.chunkKey,
      );
      final edited = prepareChunkPlaytest(editedInput);

      expect(
        editedInput.chunkContents,
        contains('"revision": ${source.revision + 1}'),
      );
      expect(edited.scenario, isNotNull);
      expect(
        edited.scenario!.draftPattern.visualSprites.map((sprite) => sprite.x),
        isNot(
          orderedEquals(
            baseline.scenario!.draftPattern.visualSprites.map(
              (sprite) => sprite.x,
            ),
          ),
        ),
      );
      expect(
        repositoryDocument.baselineContentsByChunkKey[source.chunkKey],
        isNot(contains('"revision": ${source.revision + 1}')),
      );
    },
  );

  test('capture fails closed for missing owner, level, and source path', () {
    expect(
      () => captureChunkPlaytestPreparationInput(
        document: repositoryDocument,
        selectedChunkKey: 'missing',
      ),
      throwsA(
        isA<ChunkPlaytestPreparationException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_owner_missing',
        ),
      ),
    );

    final selected = repositoryDocument.chunks.singleWhere(
      (chunk) => chunk.chunkKey == 'forest_early_00',
    );
    expect(
      () => captureChunkPlaytestPreparationInput(
        document: repositoryDocument.copyWith(levels: const []),
        selectedChunkKey: selected.chunkKey,
      ),
      throwsA(
        isA<ChunkPlaytestPreparationException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_level_missing',
        ),
      ),
    );
    expect(
      () => captureChunkPlaytestPreparationInput(
        document: repositoryDocument.copyWith(
          sourcePathByChunkKey: <String, String>{
            ...repositoryDocument.sourcePathByChunkKey,
          }..remove(selected.chunkKey),
        ),
        selectedChunkKey: selected.chunkKey,
      ),
      throwsA(
        isA<ChunkPlaytestPreparationException>().having(
          (error) => error.code,
          'code',
          'chunk_playtest_source_path_missing',
        ),
      ),
    );
  });

  test('pipeline and generated-level blockers return no partial scenario', () {
    final valid = captureChunkPlaytestPreparationInput(
      document: repositoryDocument,
      selectedChunkKey: 'forest_early_00',
    );
    final malformed = prepareChunkPlaytest(
      ChunkPlaytestPreparationInput(
        selectedChunkKey: valid.selectedChunkKey,
        levelId: valid.levelId,
        visualThemeId: valid.visualThemeId,
        prefabSourcePath: valid.prefabSourcePath,
        prefabContents: valid.prefabContents,
        tileSourcePath: valid.tileSourcePath,
        tileContents: valid.tileContents,
        chunkSourcePath: valid.chunkSourcePath,
        chunkContents: '{}',
      ),
    );
    expect(malformed.scenario, isNull);
    expect(malformed.issues, isNotEmpty);

    final unsupported = prepareChunkPlaytest(
      ChunkPlaytestPreparationInput(
        selectedChunkKey: valid.selectedChunkKey,
        levelId: 'future_level',
        visualThemeId: valid.visualThemeId,
        prefabSourcePath: valid.prefabSourcePath,
        prefabContents: valid.prefabContents,
        tileSourcePath: valid.tileSourcePath,
        tileContents: valid.tileContents,
        chunkSourcePath: valid.chunkSourcePath,
        chunkContents: valid.chunkContents,
      ),
    );
    expect(unsupported.scenario, isNull);
    expect(unsupported.issues.single.code, 'chunk_playtest_level_unsupported');
  });

  test(
    'background preparation returns the same deterministic scenario',
    () async {
      final input = captureChunkPlaytestPreparationInput(
        document: repositoryDocument,
        selectedChunkKey: 'forest_early_00',
      );

      final result = await prepareChunkPlaytestInBackground(input);

      expect(result.scenario, isNotNull);
      expect(result.scenario!.seed, chunkPlaytestDefaultSeed);
      expect(result.scenario!.path.chunkKeys, isNotEmpty);
    },
  );
}
