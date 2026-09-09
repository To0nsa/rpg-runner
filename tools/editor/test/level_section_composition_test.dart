import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/track/chunk_pattern_tier.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_content_projection.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_store.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/level_parallax_fixture.dart';

void main() {
  test(
    'section difficulty and order survive commands, save, reload and undo',
    () async {
      final plugin = LevelDomainPlugin();
      final session = await createLevelParallaxTestSession(plugin);
      final sections = [
        _section('opening', 'default', ChunkPatternTier.early),
        _section('grove_easy', 'grove', ChunkPatternTier.easy),
        _section('ruins_normal', 'ruins', ChunkPatternTier.normal),
      ];
      _compose(session, sections);
      expect((session.document! as LevelDefsDocument).operationIssues, isEmpty);
      expect(_sections(session).map((s) => s.difficulty), [
        ChunkPatternTier.early,
        ChunkPatternTier.easy,
        ChunkPatternTier.normal,
      ]);
      final revised = [
        sections[0],
        sections[2],
        sections[1].copyWith(difficulty: ChunkPatternTier.hard),
      ];
      _compose(session, revised);
      session.undo();
      expect(
        _sections(session).map((s) => s.toJson()),
        sections.map((s) => s.toJson()),
      );
      session.redo();
      await session.exportDirectWrite();
      expect(session.exportError, isNull);
      final saved = session.document! as LevelDefsDocument;
      final reloaded = await const LevelStore().load(
        EditorWorkspace(rootPath: saved.workspaceRootPath),
      );
      expect(
        findLevelDefById(reloaded.levels, 'field')!.assembly!.toJson(),
        LevelAssemblyDef(loopSegments: false, segments: revised).toJson(),
      );
      session.undo();
      expect(_sections(session).map((s) => s.difficulty), [
        ChunkPatternTier.early,
        ChunkPatternTier.easy,
        ChunkPatternTier.normal,
      ]);

      final automatic = revised[1].copyWith(clearDifficulty: true);
      expect(automatic.toJson().containsKey('difficulty'), isFalse);
      for (final invalid in ['extreme', 2, null]) {
        final rejected = plugin.applyEdit(
          saved,
          AuthoringCommand(
            kind: 'update_level',
            payload: {
              'levelId': 'field',
              'assembly': {
                'loopSegments': false,
                'segments': [
                  {...sections.first.toJson(), 'difficulty': invalid},
                ],
              },
            },
          ),
        ) as LevelDefsDocument;
        expect(rejected.operationIssues, isNotEmpty);
        expect(rejected.levels, same(saved.levels));
        expect(
          () => const LevelStore().parseCanonicalSource(
            renderCanonicalLevelDefsJson(saved.levels).replaceFirst(
              '"difficulty": "early"',
              '"difficulty": ${jsonEncode(invalid)}',
            ),
          ),
          throwsStateError,
        );
      }
    },
  );

  test(
    'capacity counts only unique active chunks in the requested group and tier',
    () async {
      final plugin = LevelDomainPlugin();
      final session = await createLevelParallaxTestSession(plugin);
      final root = (session.document! as LevelDefsDocument).workspaceRootPath;
      for (final (key, tier, group, status) in [
        ('easy_a', 'easy', 'grove', 'active'),
        ('easy_b', 'easy', 'grove', 'active'),
        ('old_easy', 'easy', 'grove', 'deprecated'),
        ('hard', 'hard', 'grove', 'active'),
        ('other', 'easy', 'ruins', 'active'),
      ]) {
        final file = File(
          p.join(root, 'assets/authoring/level/chunks/$key.json'),
        );
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(
          jsonEncode({
            'chunkKey': key,
            'levelId': 'field',
            'assemblyGroupId': group,
            'difficulty': tier,
            'status': status,
          }),
        );
      }
      await session.loadWorkspace();
      _compose(session, [_section('grove', 'grove', ChunkPatternTier.easy)]);
      final issues = plugin
          .validate(session.document!)
          .where((i) => i.code == 'insufficient_section_chunks')
          .toList();
      expect(issues, hasLength(1));
      expect(
        issues.single.message,
        contains('only has 2 matching active chunks'),
      );
      expect(issues.single.blocks(AuthoringOperation.play), isTrue);
      expect(issues.single.blocks(AuthoringOperation.save), isFalse);
      expect(issues.single.fieldKey, 'difficulty');
      _compose(session, [
        _section(
          'grove',
          'grove',
          ChunkPatternTier.easy,
        ).copyWith(minChunkCount: 2, maxChunkCount: 2),
      ]);
      expect(
        plugin
            .validate(session.document!)
            .where((i) => i.code == 'insufficient_section_chunks'),
        isEmpty,
      );
      _compose(session, [
        _section(
          'grove',
          'grove',
          ChunkPatternTier.normal,
        ).copyWith(requireDistinctChunks: false),
      ]);
      expect(
        plugin
            .validate(session.document!)
            .where((i) => i.code == 'insufficient_section_chunks'),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'compose by selecting difficulty, duplicating and moving sections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = (await tester.runAsync(
        () => createLevelParallaxTestSession(LevelDomainPlugin()),
      ))!;
      _compose(session, [
        _section('grove_easy', 'grove', ChunkPatternTier.easy),
      ]);
      await tester.runAsync(session.exportDirectWrite);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelCreatorPage(
              controller: session,
              viewStore: null,
              contentLoader: (_) async => LevelContentProjection(
                document: ChunkV2Document(
                  chunks: const [],
                  sourcePathByChunkKey: const {},
                  baselineContentsByChunkKey: const {},
                  prefabData: PrefabV3FileData(
                    slices: const [],
                    prefabs: const [],
                  ),
                  tileData: PrefabTileFileData(
                    tileSlices: const [],
                    platformModules: const [],
                  ),
                  visualBoundsByPrefabKey: const {},
                  levels: (session.document! as LevelDefsDocument).levels,
                  parallaxThemes: const [],
                  availableLevelIds: const ['field', 'forest'],
                  activeLevelId: 'field',
                ),
              ),
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        if (find
            .byKey(const ValueKey('level_workspace_tabs'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('level_workspace_tabs')),
          matching: find.text('Flow'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('level_section_grove_easy')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chunks 1–3'), findsOneWidget);
      await tester.tap(find.text('Duplicate section'));
      await tester.pumpAndSettle();
      expect(_sections(session), hasLength(2));
      expect(_sections(session).map((s) => s.segmentId).toSet(), hasLength(2));
      final difficulty = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Section difficulty',
      );
      await tester.tap(difficulty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('normal').last);
      await tester.pumpAndSettle();
      expect(_sections(session).last.difficulty, ChunkPatternTier.normal);
      expect(_sections(session).last.requireDistinctChunks, isTrue);
      await tester.tap(find.text('Move earlier'));
      await tester.pumpAndSettle();
      expect(_sections(session).map((s) => s.difficulty), [
        ChunkPatternTier.normal,
        ChunkPatternTier.easy,
      ]);
      expect(find.textContaining('Chunks 4–6'), findsOneWidget);
      session.undo();
      await tester.pumpAndSettle();
      expect(_sections(session).map((s) => s.difficulty), [
        ChunkPatternTier.easy,
        ChunkPatternTier.normal,
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

LevelAssemblySegmentDef _section(
  String id,
  String group,
  ChunkPatternTier difficulty,
) => LevelAssemblySegmentDef(
  segmentId: id,
  groupId: group,
  difficulty: difficulty,
  minChunkCount: 3,
  maxChunkCount: 3,
  requireDistinctChunks: true,
);

void _compose(
  EditorSessionController session,
  List<LevelAssemblySegmentDef> sections,
) => session.applyCommand(
  AuthoringCommand(
    kind: 'update_level',
    payload: {
      'levelId': 'field',
      'chunkThemeGroups': ['default', 'grove', 'ruins'],
      'assembly': LevelAssemblyDef(
        loopSegments: false,
        segments: sections,
      ).toJson(),
    },
  ),
);

List<LevelAssemblySegmentDef> _sections(EditorSessionController session) =>
    findLevelDefById(
      (session.document! as LevelDefsDocument).levels,
      'field',
    )!.assembly!.segments;
