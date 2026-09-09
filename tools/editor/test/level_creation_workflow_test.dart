import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';

import 'test_support/level_parallax_fixture.dart';

void main() {
  test('friendly New allocates stable identities and fixed defaults with copied background', () async {
    final plugin = LevelDomainPlugin();
    final session = await createLevelParallaxTestSession(plugin);
    final before = session.document! as LevelDefsDocument;
    final tuned = plugin.applyEdit(
      before,
      AuthoringCommand(
        kind: 'update_level',
        payload: const {
          'levelId': 'field',
          'cameraCenterY': 120,
          'earlyPatternChunks': 12,
        },
      ),
    ) as LevelDefsDocument;
    var next = plugin.applyEdit(
      tuned,
      AuthoringCommand(
        kind: 'create_level',
        payload: const {
          'displayName': 'Crystal Gardens',
          'themeMode': levelThemeModeCopy,
          'sourceVisualThemeId': 'field',
        },
      ),
    ) as LevelDefsDocument;
    expect(next.operationIssues, isEmpty);
    final created = findLevelDefById(next.levels, next.activeLevelId)!;
    expect(created.levelId, 'crystal_gardens');
    expect(created.visualThemeId, 'crystal_gardens');
    expect(created.displayName, 'Crystal Gardens');
    expect(created.cameraCenterY, 135);
    expect(created.groundTopY, 224);
    expect(created.earlyPatternChunks, 3);
    expect(created.easyPatternChunks, 0);
    expect(created.normalPatternChunks, 0);
    expect(created.noEnemyChunks, 3);
    expect(created.assembly, isNull);
    expect(created.includeInBuild, isFalse);
    expect(created.enumOrdinal, 30);
    final copiedTheme = findParallaxThemeById(
      next.parallaxDocument!.themes,
      created.visualThemeId,
    )!;
    final sourceTheme = findParallaxThemeById(
      before.parallaxDocument!.themes,
      'field',
    )!;
    expect(copiedTheme.revision, 1);
    expect(
      copiedTheme.layers.map((layer) => layer.toJson()),
      sourceTheme.layers.map((layer) => layer.toJson()),
    );
    expect(next.sessionCreatedParallaxThemeIds, contains('crystal_gardens'));
    next = plugin.applyEdit(
      next,
      AuthoringCommand(
        kind: 'create_level',
        payload: const {
          'displayName': 'Crystal Gardens',
          'themeMode': levelThemeModeCreate,
        },
      ),
    ) as LevelDefsDocument;
    expect(next.activeLevelId, 'crystal_gardens_2');
    expect(
      findLevelDefById(next.levels, next.activeLevelId)!.visualThemeId,
      'crystal_gardens_2',
    );
  });

  test('Copy settings resets sections; explicit design copy preserves incomplete rules', () async {
    final plugin = LevelDomainPlugin();
    final session = await createLevelParallaxTestSession(plugin);
    final loaded = session.document! as LevelDefsDocument;
    final source = findLevelDefById(loaded.levels, 'field')!.copyWith(
      earlyPatternChunks: 8,
      chunkThemeGroups: ['default', 'woods'],
      assembly: const LevelAssemblyDef(
        loopSegments: true,
        segments: [
          LevelAssemblySegmentDef(
            segmentId: 'opening',
            groupId: 'woods',
            minChunkCount: 2,
            maxChunkCount: 4,
            requireDistinctChunks: true,
          ),
        ],
      ),
    );
    final before = loaded.copyWith(
      levels: [
        for (final level in loaded.levels)
          if (level.levelId == 'field') source else level,
      ],
    );
    final basic = plugin.applyEdit(
      before,
      AuthoringCommand(
        kind: 'duplicate_level',
        payload: const {
          'levelId': 'field',
          'displayName': 'Copy settings',
          'themeMode': levelThemeModeCopy,
        },
      ),
    ) as LevelDefsDocument;
    expect(basic.operationIssues, isEmpty);
    final copied = findLevelDefById(basic.levels, 'copy_settings')!;
    expect(copied.earlyPatternChunks, 8);
    expect(copied.assembly, isNull);
    expect(copied.chunkThemeGroups, ['default']);
    expect(copied.includeInBuild, isFalse);
    expect(basic.authoredChunkCountsByLevelId[copied.levelId] ?? 0, 0);
    final design = plugin.applyEdit(
      before,
      AuthoringCommand(
        kind: 'duplicate_level',
        payload: const {
          'levelId': 'field',
          'displayName': 'Copy design',
          'copySectionDesign': true,
        },
      ),
    ) as LevelDefsDocument;
    expect(design.operationIssues, isEmpty);
    final fullCopy = findLevelDefById(design.levels, 'copy_design')!;
    expect(fullCopy.assembly!.toJson(), source.assembly!.toJson());
    expect(fullCopy.chunkThemeGroups, source.chunkThemeGroups);
    expect(fullCopy.includeInBuild, isFalse);
    expect(
      plugin
          .validate(design)
          .where((issue) => issue.ownerKey == 'copy_design')
          .any((issue) => issue.blocks(AuthoringOperation.save)),
      isFalse,
    );
  });

  test('independent appearance copy is one undoable compound edit and saves both sources', () async {
    final plugin = LevelDomainPlugin();
    final session = await createLevelParallaxTestSession(plugin);
    final before = session.document! as LevelDefsDocument;
    session.applyCommand(
      AuthoringCommand(
        kind: 'copy_assign_theme',
        payload: const {'levelId': 'field', 'sourceVisualThemeId': 'field'},
      ),
    );
    final copied = session.document! as LevelDefsDocument;
    expect(copied.operationIssues, isEmpty);
    expect(findLevelDefById(copied.levels, 'field')!.visualThemeId, 'field_2');
    expect(
      findParallaxThemeById(copied.parallaxDocument!.themes, 'field')!.toJson(),
      findParallaxThemeById(before.parallaxDocument!.themes, 'field')!.toJson(),
    );
    expect(session.pendingChanges.fileDiffs, hasLength(2));
    session.undo();
    expect(
      findLevelDefById(
        (session.document! as LevelDefsDocument).levels,
        'field',
      )!.visualThemeId,
      'field',
    );
    session.redo();
    await session.exportDirectWrite();
    expect(session.exportError, isNull);
    expect(session.pendingChanges.hasChanges, isFalse);
    final saved = session.document! as LevelDefsDocument;
    expect(
      findParallaxThemeById(saved.parallaxDocument!.themes, 'field_2')!.layers,
      hasLength(1),
    );
  });

  test(
    'unknown copy source and explicit identity collisions reject atomically',
    () async {
      final plugin = LevelDomainPlugin();
      final session = await createLevelParallaxTestSession(plugin);
      final before = session.document! as LevelDefsDocument;
      for (final payload in <Map<String, Object?>>[
        {
          'displayName': 'Missing source',
          'themeMode': levelThemeModeCopy,
          'sourceVisualThemeId': 'absent',
        },
        {
          'displayName': 'Collision',
          'levelId': 'field',
          'themeMode': levelThemeModeCreate,
        },
        {
          'displayName': 'Collision',
          'themeMode': levelThemeModeCopy,
          'sourceVisualThemeId': 'field',
          'visualThemeId': 'field',
        },
      ]) {
        final rejected = plugin.applyEdit(
          before,
          AuthoringCommand(kind: 'create_level', payload: payload),
        ) as LevelDefsDocument;
        expect(rejected.operationIssues, isNotEmpty);
        expect(rejected.levels, same(before.levels));
        expect(rejected.parallaxDocument, same(before.parallaxDocument));
      }
    },
  );
}
