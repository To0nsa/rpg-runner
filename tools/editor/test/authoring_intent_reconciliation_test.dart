import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/domain/authoring_intent_reconciliation.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

import 'test_support/level_parallax_fixture.dart';

void main() {
  for (final redo in [false, true]) {
    test(
      'history after review becomes the current recovery intent: redo=$redo',
      () async {
        final session = await createLevelParallaxTestSession(
          LevelDomainPlugin(),
        );
        session.applyCommand(
          AuthoringCommand(
            kind: 'update_level',
            payload: const {'levelId': 'field', 'displayName': 'Edited field'},
          ),
        );
        await session.reapplyIntent(reviewOnly: true);
        session.undo();
        if (redo) session.redo();
        await session.reapplyIntent();
        expect(
          findLevelDefById(
            (session.document! as LevelDefsDocument).levels,
            'field',
          )!.displayName,
          redo ? 'Edited field' : 'Field',
        );
        expect(session.pendingChanges.hasChanges, redo);
      },
    );
  }

  test(
    'successful targeted handoff discards the resolved origin recovery state',
    () async {
      final fixture = await createLevelParallaxTestSession(LevelDomainPlugin());
      final session = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [LevelDomainPlugin(), ParallaxDomainPlugin()],
        ),
        initialPluginId: LevelDomainPlugin.pluginId,
        initialWorkspacePath: fixture.workspacePath,
      );
      addTearDown(session.dispose);
      await session.loadWorkspace();
      session.applyCommand(
        AuthoringCommand(
          kind: 'update_level',
          payload: const {'levelId': 'field', 'displayName': 'Edited field'},
        ),
      );
      final before = session.document! as LevelDefsDocument;
      _writeLevels(
        session,
        before.levels.map(
          (level) => level.copyWith(revision: level.revision + 1),
        ),
      );
      await session.exportDirectWrite();
      expect(session.requiresSourceReconciliation, isTrue);
      await session.reapplyIntent(reviewOnly: true);
      expect(session.recoveryCopy, isNotNull);
      final loaded = await session.loadWorkspaceForPlugin(
        pluginId: ParallaxDomainPlugin.pluginId,
        loadDocument: (plugin, workspace) => plugin.loadFromRepo(workspace),
      );
      expect(loaded, isTrue);
      expect(session.document, isA<ParallaxDefsDocument>());
      expect(session.requiresSourceReconciliation, isFalse);
      expect(session.recoveryCopy, isNull);
      expect(session.recoveryError, isNull);
    },
  );

  test('review preserves live presentation and advances only reconciled source generation', () async {
    final session = await createLevelParallaxTestSession(LevelDomainPlugin());
    final generation = session.sourceGeneration;
    session.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: const {'levelId': 'field', 'displayName': 'Edited field'},
      ),
    );
    expect(session.sourceGeneration, generation);
    await session.reapplyIntent(reviewOnly: true);
    session.applyPresentationCommand(
      AuthoringCommand(
        kind: 'set_active_level',
        payload: const {'levelId': 'forest'},
      ),
    );
    expect(session.sourceGeneration, generation);
    await session.reapplyIntent();
    expect((session.document! as LevelDefsDocument).activeLevelId, 'forest');
    expect(
      findLevelDefById(
        (session.document! as LevelDefsDocument).levels,
        'field',
      )!.displayName,
      'Edited field',
    );
    expect(session.sourceGeneration, generation + 1);
  });

  test('recovery preserves pending copied background while loading fresh shared layers', () async {
    final session = await createLevelParallaxTestSession(LevelDomainPlugin());
    final baseline = session.document! as LevelDefsDocument;
    final sourceTheme = findParallaxThemeById(
      baseline.parallaxDocument!.themes,
      'field',
    )!;
    session.applyCommand(
      AuthoringCommand(
        kind: 'create_level',
        payload: const {
          'displayName': 'Cave',
          'themeMode': levelThemeModeCopy,
          'sourceVisualThemeId': 'field',
        },
      ),
    );
    final original = session.document! as LevelDefsDocument;
    final intendedThemeId = findLevelDefById(
      original.levels,
      'cave',
    )!.visualThemeId;
    final freshThemes = baseline.parallaxDocument!.themes.map(
      (theme) => theme.parallaxThemeId == 'field'
          ? theme.copyWith(
              revision: 4,
              layers: [theme.layers.single.copyWith(opacity: 0.3)],
            )
          : theme,
    );
    File(p.join(session.workspacePath, parallaxDefsSourcePath))
        .writeAsStringSync(renderCanonicalParallaxDefsJson(freshThemes));
    _writeLevels(
      session,
      baseline.levels.map(
        (level) => level.levelId == 'forest'
            ? level.copyWith(displayName: 'Fresh forest', revision: 5)
            : level,
      ),
    );
    await session.reapplyIntent();
    expect(session.recoveryError, isNull);
    expect(session.recoveryCopy, isNull);
    final recovered = session.document! as LevelDefsDocument;
    expect(
      findParallaxThemeById(
        recovered.parallaxDocument!.themes,
        intendedThemeId,
      )!.layers.map((layer) => layer.toJson()),
      sourceTheme.layers.map((layer) => layer.toJson()),
    );
    expect(
      findParallaxThemeById(
        recovered.parallaxDocument!.themes,
        'field',
      )!.layers.single.opacity,
      0.3,
    );
    expect(
      findLevelDefById(recovered.levels, 'forest')!.displayName,
      'Fresh forest',
    );
    await session.exportDirectWrite();
    expect(session.exportError, isNull);
  });

  test('a pending copied theme collision requires saved choice and never overwrites disk layers', () async {
    final session = await createLevelParallaxTestSession(LevelDomainPlugin());
    final baseline = session.document! as LevelDefsDocument;
    session.applyCommand(
      AuthoringCommand(
        kind: 'copy_assign_theme',
        payload: const {'levelId': 'field', 'sourceVisualThemeId': 'field'},
      ),
    );
    final original = session.document;
    File(p.join(session.workspacePath, parallaxDefsSourcePath))
        .writeAsStringSync(
          renderCanonicalParallaxDefsJson([
            ...baseline.parallaxDocument!.themes,
            const ParallaxThemeDef(
              parallaxThemeId: 'field_2',
              revision: 8,
              layers: [],
            ),
          ]),
        );
    final plan = await session.reapplyIntent();
    const path = 'Background field_2 / identity already created';
    expect(plan!.unresolvedPaths, contains(path));
    expect(
      plan.conflicts
          .singleWhere((conflict) => conflict.path == path)
          .canUseIntended,
      isFalse,
    );
    expect(session.document, same(original));
    await session.reapplyIntent(
      resolutions: {path: AuthoringConflictChoice.intended},
    );
    expect(session.document, same(original));
    await session.reapplyIntent(
      resolutions: {path: AuthoringConflictChoice.saved},
    );
    expect(session.recoveryCopy, isNull);
    final current = session.document! as LevelDefsDocument;
    final persisted = findParallaxThemeById(
      current.parallaxDocument!.themes,
      'field_2',
    )!;
    expect(persisted.revision, 8);
    expect(persisted.layers, isEmpty);
  });

  test('source drift retains edits and reapply preserves nonoverlapping disk changes', () async {
    final session = await createLevelParallaxTestSession(LevelDomainPlugin());
    final baseline = session.document! as LevelDefsDocument;
    session.applyCommand(_rename('My field'));
    _writeLevels(
      session,
      baseline.levels.map(
        (level) => level.levelId == 'field'
            ? level.copyWith(groundTopY: 210, revision: 6)
            : level,
      ),
    );
    final result = await session.exportDirectWrite();
    expect(result!.outcome, ExportOutcome.sourceDrift);
    expect(session.requiresSourceReconciliation, isTrue);
    expect(await session.exportDirectWrite(), isNull);
    final preview = await session.reapplyIntent(reviewOnly: true);
    expect(preview!.conflicts, isEmpty);
    expect(_field(session).displayName, 'My field');
    await session.reapplyIntent();
    expect(session.recoveryError, isNull);
    expect(session.recoveryCopy, isNull);
    expect(_field(session).displayName, 'My field');
    expect(_field(session).groundTopY, 210);
    expect(_field(session).revision, 7);
    expect(session.pendingChanges.hasChanges, isTrue);
    await session.exportDirectWrite();
    expect(session.exportError, isNull);
    expect(_field(session).groundTopY, 210);
  });

  test(
    'conflicting field needs a choice and uses current saved revisions',
    () async {
      final session = await createLevelParallaxTestSession(LevelDomainPlugin());
      final baseline = session.document! as LevelDefsDocument;
      session.applyCommand(_rename('My field'));
      final origin = session.document;
      _writeLevels(
        session,
        baseline.levels.map(
          (level) => level.levelId == 'field'
              ? level.copyWith(displayName: 'External field', revision: 8)
              : level,
        ),
      );
      final plan = await session.reapplyIntent();
      expect(plan!.unresolvedPaths, {'Level field/displayName'});
      expect(session.document, same(origin));
      await session.reapplyIntent(
        resolutions: {
          'Level field/displayName': AuthoringConflictChoice.intended,
        },
      );
      expect(session.recoveryCopy, isNull);
      expect(_field(session).displayName, 'My field');
      expect(_field(session).revision, 9);
    },
  );

  test('saved choice discards only the conflicted intent', () async {
    final session = await createLevelParallaxTestSession(LevelDomainPlugin());
    final baseline = session.document! as LevelDefsDocument;
    session.applyCommand(_rename('My field'));
    session.applyCommand(
      AuthoringCommand(
        kind: 'update_level',
        payload: {'levelId': 'field', 'noEnemyChunks': 5},
      ),
    );
    _writeLevels(
      session,
      baseline.levels.map(
        (level) => level.levelId == 'field'
            ? level.copyWith(displayName: 'External field', revision: 3)
            : level,
      ),
    );
    await session.reapplyIntent(
      resolutions: {'Level field/displayName': AuthoringConflictChoice.saved},
    );
    expect(_field(session).displayName, 'External field');
    expect(_field(session).noEnemyChunks, 5);
    expect(session.recoveryCopy, isNull);
  });

  test(
    'reapply rereads disk after review instead of replacing a newer edit',
    () async {
      final session = await createLevelParallaxTestSession(LevelDomainPlugin());
      final baseline = session.document! as LevelDefsDocument;
      session.applyCommand(_rename('My field'));
      expect(
        (await session.reapplyIntent(reviewOnly: true))!.conflicts,
        isEmpty,
      );
      _writeLevels(
        session,
        baseline.levels.map(
          (level) => level.levelId == 'field'
              ? level.copyWith(
                  displayName: 'Changed during review',
                  revision: 3,
                )
              : level,
        ),
      );
      final plan = await session.reapplyIntent();
      expect(plan!.unresolvedPaths, {'Level field/displayName'});
      expect(session.recoveryCopy, isNotNull);
      expect(_field(session).displayName, 'My field');
    },
  );

  test(
    'new identity collision is never reallocated or overwritten by reapply',
    () async {
      final session = await createLevelParallaxTestSession(LevelDomainPlugin());
      session.applyCommand(
        AuthoringCommand(
          kind: 'create_level',
          payload: {
            'levelId': 'cave',
            'visualThemeId': 'field',
            'themeMode': 'existing',
          },
        ),
      );
      final intended = session.document! as LevelDefsDocument;
      _writeLevels(
        session,
        intended.levels.map(
          (level) => level.levelId == 'cave'
              ? level.copyWith(displayName: 'External cave')
              : level,
        ),
      );
      final plan = await session.reapplyIntent();
      expect(plan!.conflicts.single.canUseIntended, isFalse);
      expect(session.recoveryCopy, isNotNull);
      expect(
        findLevelDefById(
          (session.document! as LevelDefsDocument).levels,
          'cave',
        )!.displayName,
        'Cave',
      );
    },
  );

  test(
    'Parallax reapply preserves repaired assets and unrelated layer values',
    () async {
      final session = await createLevelParallaxTestSession(
        ParallaxDomainPlugin(),
      );
      final baseline = session.document! as ParallaxDefsDocument;
      session.applyCommand(
        AuthoringCommand(
          kind: 'update_layer',
          payload: {'layerKey': 'field_bg', 'opacity': 0.6},
        ),
      );
      final themes = baseline.themes.map(
        (theme) => theme.parallaxThemeId == 'field'
            ? theme.copyWith(
                revision: 4,
                layers: [theme.layers.single.copyWith(yOffset: 12)],
              )
            : theme,
      );
      File(p.join(session.workspacePath, parallaxDefsSourcePath))
          .writeAsStringSync(renderCanonicalParallaxDefsJson(themes));
      await session.reapplyIntent();
      expect(session.recoveryError, isNull);
      final layer = (session.document! as ParallaxDefsDocument)
          .themes
          .first
          .layers
          .single;
      expect(layer.opacity, 0.6);
      expect(layer.yOffset, 12);
      expect(
        (session.document! as ParallaxDefsDocument).themes.first.revision,
        5,
      );
    },
  );
}

AuthoringCommand _rename(String value) => AuthoringCommand(
  kind: 'update_level',
  payload: {'levelId': 'field', 'displayName': value},
);
LevelDef _field(EditorSessionController session) =>
    findLevelDefById((session.document! as LevelDefsDocument).levels, 'field')!;
void _writeLevels(EditorSessionController session, Iterable<LevelDef> levels) =>
    File(p.join(session.workspacePath, levelDefsSourcePath))
        .writeAsStringSync(renderCanonicalLevelDefsJson(levels));
