import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_store.dart';
import 'package:runner_editor/src/levels/level_theme_save_coordinator.dart';
import 'package:runner_editor/src/levels/level_validation.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'persisted ordinals cannot be changed by a Level edit command',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final rejected = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'enumOrdinal': 1,
          },
        ),
      ) as LevelDefsDocument;
      expect(rejected.levels, same(loaded.levels));
      expect(
        rejected.operationIssues.single.code,
        'update_level_persisted_ordinal',
      );
    },
  );

  test(
    'build inclusion is saved independently without clearing incomplete rules',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final original = loaded.levels.single;
      final excluded = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'includeInBuild': false,
          },
        ),
      ) as LevelDefsDocument;
      expect(excluded.levels.single.includeInBuild, isFalse);
      expect(
        excluded.levels.single.assembly!.toJson(),
        original.assembly!.toJson(),
      );
      expect(excluded.levels.single.enumOrdinal, original.enumOrdinal);
      expect(excluded.levels.single.status, original.status);
      final capacity = plugin
          .validate(excluded)
          .where((issue) => issue.code == 'insufficient_distinct_group_chunks');
      expect(capacity, hasLength(2));
      for (final issue in capacity) {
        expect(issue.blocks(AuthoringOperation.save), isFalse);
        expect(issue.blocks(AuthoringOperation.build), isFalse);
        expect(issue.blocks(AuthoringOperation.play), isTrue);
      }
      expect(
        (await plugin.exportToRepo(
          fixture.workspace,
          document: excluded,
        )).applied,
        isTrue,
      );
      final reopened =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final resumed = plugin.applyEdit(
        reopened,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'includeInBuild': true,
          },
        ),
      ) as LevelDefsDocument;
      expect(
        (await plugin.exportToRepo(
          fixture.workspace,
          document: resumed,
        )).applied,
        isTrue,
      );
      expect(
        resumed.levels.single.assembly!.toJson(),
        original.assembly!.toJson(),
      );
      expect(
        plugin
            .validate(resumed)
            .where((issue) => issue.blocks(AuthoringOperation.build)),
        hasLength(2),
      );
    },
  );

  test(
    'current Level parser and inclusion command reject implicit coercion',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final raw = renderCanonicalLevelDefsJson(loaded.levels);
      for (final invalid in <String>[
        raw.replaceFirst('"schemaVersion": 2', '"schemaVersion": 1'),
        raw.replaceFirst('      "includeInBuild": true,\n', ''),
        raw.replaceFirst('"includeInBuild": true', '"includeInBuild": "true"'),
      ]) {
        expect(
          () => const LevelStore().parseCanonicalSource(invalid),
          throwsStateError,
        );
      }
      final rejected = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'includeInBuild': 'true',
          },
        ),
      ) as LevelDefsDocument;
      expect(rejected.levels, same(loaded.levels));
      expect(
        rejected.operationIssues.single.code,
        'update_level_invalid_build_inclusion',
      );
    },
  );

  test('operation admission preserves strict error defaults and nonblocking warnings', () {
    for (final severity in ValidationSeverity.values) {
      final issue = ValidationIssue(
        severity: severity,
        code: 'fixture_issue',
        message: 'Fixture issue.',
      );
      for (final operation in AuthoringOperation.values) {
        expect(issue.blocks(operation), severity == ValidationSeverity.error);
      }
    }
  });

  test(
    'insufficient section capacity stays visible and blocks runtime only',
    () async {
      final fixture = await _createFixture();
      final loaded = await LevelDomainPlugin().loadFromRepo(
        fixture.workspace,
      ) as LevelDefsDocument;
      final issues = validateLevelDocument(loaded);
      expect(issues, hasLength(2));
      for (final issue in issues) {
        expect(issue.code, 'insufficient_distinct_group_chunks');
        expect(issue.ownerKey, 'field');
        expect(issue.severity, ValidationSeverity.error);
        expect(issue.blocks(AuthoringOperation.save), isFalse);
        expect(issue.blocks(AuthoringOperation.play), isTrue);
        expect(issue.blocks(AuthoringOperation.build), isTrue);
      }
    },
  );

  test(
    'Level findings expose stable owners for settings and section navigation',
    () async {
      final fixture = await _createFixture();
      final loaded = await LevelDomainPlugin().loadFromRepo(
        fixture.workspace,
      ) as LevelDefsDocument;
      final invalid = loaded.copyWith(
        levels: <LevelDef>[
          loaded.levels.single.copyWith(
            displayName: '',
            earlyPatternChunks: -1,
            groundTopY: double.nan,
            visualThemeId: 'missing_theme',
            assembly: const LevelAssemblyDef(
              segments: <LevelAssemblySegmentDef>[
                LevelAssemblySegmentDef(
                  segmentId: 'broken_section',
                  groupId: 'missing_group',
                  minChunkCount: 4,
                  maxChunkCount: 2,
                  requireDistinctChunks: true,
                ),
              ],
            ),
          ),
        ],
      );

      final issues = validateLevelDocument(invalid);

      expect(
        issues.map((issue) => issue.code),
        containsAll(<String>[
          'missing_display_name',
          'invalid_earlyPatternChunks',
          'invalid_ground_top_y',
          'missing_parallax_theme',
          'unknown_assembly_group_id',
          'invalid_chunk_count_range',
        ]),
      );
      for (final issue in issues) {
        expect(issue.ownerKey, 'field', reason: issue.code);
        expect(issue.sourcePath, levelDefsSourcePath);
        expect(issue.blocks(AuthoringOperation.save), isTrue);
      }
    },
  );

  test(
    'incomplete copied sections save and reload with their rules intact',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final copy = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'duplicate_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'nextLevelId': 'experiment',
            'copySectionDesign': true,
          },
        ),
      ) as LevelDefsDocument;
      final copiedLevel = findLevelDefById(copy.levels, 'experiment')!;
      expect(copiedLevel.includeInBuild, isFalse);
      expect(copiedLevel.assembly!.segments, hasLength(2));
      final sectionFindings = plugin
          .validate(copy)
          .where(
            (issue) =>
                issue.ownerKey == 'experiment' &&
                issue.code == 'insufficient_distinct_group_chunks',
          );
      expect(
        sectionFindings.map((issue) => issue.elementId),
        unorderedEquals(
          copiedLevel.assembly!.segments.map((section) => section.segmentId),
        ),
      );
      expect(
        sectionFindings.map((issue) => issue.fieldKey),
        everyElement('requireDistinctChunks'),
      );
      expect(
        plugin.validate(copy).map((issue) => issue.code),
        contains('insufficient_distinct_group_chunks'),
      );

      final result = await plugin.exportToRepo(
        fixture.workspace,
        document: copy,
      );

      expect(result.applied, isTrue);
      final reloaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final saved = findLevelDefById(reloaded.levels, 'experiment')!;
      expect(saved.assembly!.toJson(), copiedLevel.assembly!.toJson());
      expect(saved.chunkThemeGroups, copiedLevel.chunkThemeGroups);
      expect(saved.levelId, copiedLevel.levelId);
      expect(saved.enumOrdinal, copiedLevel.enumOrdinal);
      expect(
        plugin
            .describePendingChanges(fixture.workspace, document: reloaded)
            .hasChanges,
        isFalse,
      );
    },
  );

  test(
    'compound theme command and two-source save admit incomplete sections',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final candidate = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'create_and_assign_theme',
          payload: const <String, Object?>{
            'levelId': 'field',
            'visualThemeId': 'replacement',
          },
        ),
      ) as LevelDefsDocument;

      expect(candidate.operationIssues, isEmpty);
      expect(candidate.levels.single.visualThemeId, 'replacement');
      expect(
        findParallaxThemeById(
          candidate.parallaxDocument!.themes,
          'replacement',
        ),
        isNotNull,
      );
      final plan = const LevelThemeSaveCoordinator().buildSavePlan(
        fixture.workspace,
        document: candidate,
      );
      expect(plan.writes, hasLength(2));

      final result = await plugin.exportToRepo(
        fixture.workspace,
        document: candidate,
      );

      expect(result.applied, isTrue);
      final reloaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      expect(reloaded.levels.single.visualThemeId, 'replacement');
      expect(
        reloaded.levels.single.assembly!.toJson(),
        loaded.levels.single.assembly!.toJson(),
      );
      expect(
        findParallaxThemeById(reloaded.parallaxDocument!.themes, 'replacement'),
        isNotNull,
      );
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test(
    'coordinator preflight and installed verification admit incomplete design',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final candidate = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'displayName': 'A design to finish',
          },
        ),
      ) as LevelDefsDocument;
      const coordinator = LevelThemeSaveCoordinator();
      final plan = coordinator.buildSavePlan(
        fixture.workspace,
        document: candidate,
      );

      final result = coordinator.apply(
        fixture.workspace,
        document: candidate,
        savePlan: plan,
      );

      expect(result.cleanupRequired, isFalse);
      final reloaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      expect(reloaded.levels.single.displayName, 'A design to finish');
      expect(
        reloaded.levels.single.assembly!.toJson(),
        candidate.levels.single.assembly!.toJson(),
      );
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test(
    'structural errors still reject plugin and direct coordinator writes',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final level = loaded.levels.single;
      final firstSection = level.assembly!.segments.first;
      final invalidCandidates = <(String, LevelDefsDocument)>[
        (
          'persisted_level_removed',
          loaded.copyWith(levels: const <LevelDef>[]),
        ),
        (
          'persisted_level_ordinal_changed',
          loaded.copyWith(levels: <LevelDef>[level.copyWith(enumOrdinal: 5)]),
        ),
        (
          'new_level_ordinal_not_appended',
          loaded.copyWith(
            levels: <LevelDef>[
              level.copyWith(levelId: 'experiment', enumOrdinal: 5),
              level,
            ],
          ),
        ),
        (
          'unknown_assembly_group_id',
          loaded.copyWith(
            levels: <LevelDef>[
              level.copyWith(
                assembly: LevelAssemblyDef(
                  segments: <LevelAssemblySegmentDef>[
                    firstSection.copyWith(groupId: 'unknown'),
                  ],
                ),
              ),
            ],
          ),
        ),
        (
          'invalid_chunk_count_range',
          loaded.copyWith(
            levels: <LevelDef>[
              level.copyWith(
                assembly: LevelAssemblyDef(
                  segments: <LevelAssemblySegmentDef>[
                    firstSection.copyWith(minChunkCount: 4, maxChunkCount: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
        (
          'duplicate_segment_id',
          loaded.copyWith(
            levels: <LevelDef>[
              level.copyWith(
                assembly: LevelAssemblyDef(
                  segments: <LevelAssemblySegmentDef>[
                    firstSection,
                    firstSection,
                  ],
                ),
              ),
            ],
          ),
        ),
        (
          'missing_parallax_theme',
          loaded.copyWith(
            levels: <LevelDef>[level.copyWith(visualThemeId: 'missing')],
          ),
        ),
        (
          'invalid_revision',
          loaded.copyWith(
            parallaxDocument: loaded.parallaxDocument!.copyWith(
              themes: <ParallaxThemeDef>[
                loaded.parallaxDocument!.themes.single.copyWith(revision: 0),
              ],
            ),
          ),
        ),
      ];
      const coordinator = LevelThemeSaveCoordinator();
      final originalSources = fixture.sourceContents;
      for (final (code, candidate) in invalidCandidates) {
        final issue = plugin
            .validate(candidate)
            .firstWhere((issue) => issue.code == code);
        expect(issue.blocks(AuthoringOperation.save), isTrue, reason: code);
        await expectLater(
          plugin.exportToRepo(fixture.workspace, document: candidate),
          throwsStateError,
          reason: code,
        );
        final plan = coordinator.buildSavePlan(
          fixture.workspace,
          document: candidate,
        );
        expect(
          () => coordinator.apply(
            fixture.workspace,
            document: candidate,
            savePlan: plan,
          ),
          throwsStateError,
          reason: code,
        );
        expect(fixture.sourceContents, originalSources, reason: code);
        expect(fixture.transactionFiles, isEmpty, reason: code);
      }
    },
  );

  test(
    'incomplete design still rejects dependency source drift before writes',
    () async {
      final fixture = await _createFixture();
      final plugin = LevelDomainPlugin();
      final loaded =
          await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
      final candidate = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'update_level',
          payload: const <String, Object?>{
            'levelId': 'field',
            'displayName': 'Pending',
          },
        ),
      );
      final parallaxFile = File(
        p.join(fixture.root.path, parallaxDefsSourcePath),
      );
      parallaxFile.writeAsStringSync('${parallaxFile.readAsStringSync()}\n');
      final driftedSources = fixture.sourceContents;

      await expectLater(
        plugin.exportToRepo(fixture.workspace, document: candidate),
        throwsA(isA<LevelThemeSaveException>()),
      );

      expect(fixture.sourceContents, driftedSources);
      expect(fixture.transactionFiles, isEmpty);
    },
  );

  test('Level presentation preserves valid selection without changing restored content', () async {
    final fixture = await _createFixture();
    final plugin = LevelDomainPlugin();
    final original =
        await plugin.loadFromRepo(fixture.workspace) as LevelDefsDocument;
    final withCopy = plugin.applyEdit(
      original,
      AuthoringCommand(
        kind: 'duplicate_level',
        payload: const <String, Object?>{
          'levelId': 'field',
          'nextLevelId': 'experiment',
        },
      ),
    ) as LevelDefsDocument;
    final selection = AuthoringCommand(
      kind: 'set_active_level',
      payload: const <String, Object?>{'levelId': 'field'},
    );
    expect(plugin.isPresentationCommand(selection), isTrue);
    expect(
      plugin.isPresentationCommand(AuthoringCommand(kind: 'update_level')),
      isFalse,
    );
    final selected = plugin.applyEdit(withCopy, selection);

    final retained = plugin.retainPresentation(
      current: selected,
      restored: withCopy,
    ) as LevelDefsDocument;

    expect(retained.activeLevelId, 'field');
    expect(retained.parallaxDocument!.activeLevelId, 'field');
    expect(retained.levels, same(withCopy.levels));
    expect(retained.baseline, same(withCopy.baseline));
    expect(
      retained.parallaxDocument!.themes,
      same(withCopy.parallaxDocument!.themes),
    );
    expect(
      retained.parallaxDocument!.baseline,
      same(withCopy.parallaxDocument!.baseline),
    );
    final afterCreationUndo = plugin.retainPresentation(
      current: withCopy,
      restored: original,
    ) as LevelDefsDocument;
    expect(afterCreationUndo.activeLevelId, 'field');
    expect(afterCreationUndo.levels, same(original.levels));
  });
}

final class _Fixture {
  const _Fixture(this.root);

  final Directory root;

  EditorWorkspace get workspace => EditorWorkspace(rootPath: root.path);

  Map<String, String> get sourceContents => <String, String>{
    for (final sourcePath in <String>[
      levelDefsSourcePath,
      parallaxDefsSourcePath,
    ])
      sourcePath: File(p.join(root.path, sourcePath)).readAsStringSync(),
  };

  Iterable<File> get transactionFiles => root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => p.basename(file.path).contains('.authoring-'));
}

Future<_Fixture> _createFixture() async {
  final root = await Directory.systemTemp.createTemp('level_save_admission_');
  addTearDown(() => root.deleteSync(recursive: true));
  void write(String sourcePath, String contents) {
    final file = File(p.join(root.path, sourcePath));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);
  }

  write(
    levelDefsSourcePath,
    renderCanonicalLevelDefsJson(const <LevelDef>[
      LevelDef(
        levelId: 'field',
        revision: 1,
        displayName: 'Field',
        visualThemeId: 'field',
        chunkThemeGroups: <String>['default', 'ruins', 'woods'],
        cameraCenterY: 135,
        groundTopY: 224,
        earlyPatternChunks: 3,
        easyPatternChunks: 0,
        normalPatternChunks: 0,
        noEnemyChunks: 3,
        enumOrdinal: 10,
        includeInBuild: true,
        status: levelStatusActive,
        assembly: LevelAssemblyDef(
          segments: <LevelAssemblySegmentDef>[
            LevelAssemblySegmentDef(
              segmentId: 'woods_section',
              groupId: 'woods',
              minChunkCount: 2,
              maxChunkCount: 3,
              requireDistinctChunks: true,
            ),
            LevelAssemblySegmentDef(
              segmentId: 'ruins_section',
              groupId: 'ruins',
              minChunkCount: 1,
              maxChunkCount: 2,
              requireDistinctChunks: true,
            ),
          ],
        ),
      ),
    ]),
  );
  write(
    parallaxDefsSourcePath,
    renderCanonicalParallaxDefsJson(const <ParallaxThemeDef>[
      ParallaxThemeDef(
        parallaxThemeId: 'field',
        revision: 1,
        layers: <ParallaxLayerDef>[],
      ),
    ]),
  );
  write(
    'assets/authoring/level/chunks/woods_one.json',
    jsonEncode(<String, Object?>{
      'schemaVersion': 2,
      'chunkKey': 'woods_one',
      'id': 'woods_one',
      'revision': 1,
      'status': 'active',
      'levelId': 'field',
      'tileSize': 16,
      'width': 600,
      'height': 270,
      'difficulty': 'early',
      'assemblyGroupId': 'woods',
      'tags': <String>[],
      'tileLayers': <Object?>[],
      'prefabs': <Object?>[],
      'markers': <Object?>[],
      'collisionShapes': <Object?>[],
    }),
  );
  return _Fixture(root);
}
