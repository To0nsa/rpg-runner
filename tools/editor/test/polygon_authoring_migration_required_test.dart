import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/app/pages/chunkCreator/chunk_creator_page.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/polygon_authoring_migration_required.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('legacy prefab source is a fail-closed migration document', () async {
    final fixture = _LegacyFixture.create();
    addTearDown(fixture.dispose);
    const plugin = PrefabDomainPlugin();

    final document = await plugin.loadFromRepo(fixture.workspace);

    _expectMigrationDocument(
      plugin: plugin,
      workspace: fixture.workspace,
      document: document,
      domain: PolygonAuthoringMigrationDomain.prefabs,
      reason: PolygonAuthoringMigrationReason.legacySource,
    );
    expect(
      plugin.applyEdit(
        document,
        AuthoringCommand(kind: PrefabDomainPlugin.replacePrefabDataCommandKind),
      ),
      same(document),
    );
    await expectLater(
      plugin.exportToRepo(fixture.workspace, document: document),
      throwsA(_migrationStateError()),
    );
    expect(fixture.prefabFile.readAsStringSync(), fixture.prefabBytes);
  });

  test('legacy chunk source is a fail-closed migration document', () async {
    final fixture = _LegacyFixture.create();
    addTearDown(fixture.dispose);
    final plugin = ChunkDomainPlugin();

    final document = await plugin.loadFromRepo(fixture.workspace);

    _expectMigrationDocument(
      plugin: plugin,
      workspace: fixture.workspace,
      document: document,
      domain: PolygonAuthoringMigrationDomain.chunks,
      reason: PolygonAuthoringMigrationReason.legacySource,
    );
    expect(
      plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: 'update_ground_profile',
          payload: const <String, Object?>{'chunkKey': 'legacy_chunk'},
        ),
      ),
      same(document),
    );
    await expectLater(
      plugin.exportToRepo(fixture.workspace, document: document),
      throwsA(_migrationStateError()),
    );
    expect(fixture.chunkFile.readAsStringSync(), fixture.chunkBytes);
  });

  test('missing source is distinct from a legacy generation', () async {
    final root = Directory.systemTemp.createTempSync('polygon_source_missing_');
    addTearDown(() => root.deleteSync(recursive: true));
    final workspace = EditorWorkspace(rootPath: root.path);

    expect(
      const PrefabStore().detectSourceGeneration(root.path),
      PrefabSourceGeneration.missing,
    );
    expect(
      const ChunkStore().detectSourceGeneration(workspace),
      ChunkSourceGeneration.missing,
    );
    final prefab =
        await const PrefabDomainPlugin().loadFromRepo(workspace)
            as PolygonAuthoringMigrationRequiredDocument;
    final chunk =
        await ChunkDomainPlugin().loadFromRepo(workspace)
            as PolygonAuthoringMigrationRequiredDocument;
    expect(prefab.reason, PolygonAuthoringMigrationReason.sourceMissing);
    expect(chunk.reason, PolygonAuthoringMigrationReason.sourceMissing);
  });

  testWidgets('normal prefab route never exposes legacy controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _LegacyFixture.create();
    addTearDown(fixture.dispose);
    final controller = _controller(
      plugin: const PrefabDomainPlugin(),
      workspacePath: fixture.root.path,
    );

    await tester.pumpWidget(
      MaterialApp(home: PrefabCreatorPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('polygon_authoring_migration_required'),
      ),
      findsOneWidget,
    );
    expect(find.text('Prefab Creator requires polygon source'), findsOneWidget);
    expect(find.text('Obstacle Prefabs'), findsNothing);
    expect(find.text('Apply To Files'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('polygon_migration_recheck_source')),
    );
    await tester.pumpAndSettle();
    expect(
      controller.document,
      isA<PolygonAuthoringMigrationRequiredDocument>(),
    );
  });

  testWidgets('normal chunk route never exposes ground-gap controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _LegacyFixture.create();
    addTearDown(fixture.dispose);
    final controller = _controller(
      plugin: ChunkDomainPlugin(),
      workspacePath: fixture.root.path,
    );

    await tester.pumpWidget(
      MaterialApp(home: ChunkCreatorPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('polygon_authoring_migration_required'),
      ),
      findsOneWidget,
    );
    expect(find.text('Chunk Creator requires polygon source'), findsOneWidget);
    expect(find.text('Apply To Files'), findsNothing);
    expect(find.textContaining('Ground Gaps'), findsNothing);
  });
}

void _expectMigrationDocument({
  required AuthoringDomainPlugin plugin,
  required EditorWorkspace workspace,
  required AuthoringDocument document,
  required PolygonAuthoringMigrationDomain domain,
  required PolygonAuthoringMigrationReason reason,
}) {
  expect(document, isA<PolygonAuthoringMigrationRequiredDocument>());
  final migration = document as PolygonAuthoringMigrationRequiredDocument;
  expect(migration.domain, domain);
  expect(migration.reason, reason);
  expect(
    plugin.buildEditableScene(document),
    isA<PolygonAuthoringMigrationRequiredScene>().having(
      (scene) => scene.domain,
      'domain',
      domain,
    ),
  );
  expect(
    plugin.validate(document).single,
    isA<ValidationIssue>()
        .having(
          (issue) => issue.code,
          'code',
          'polygon_authoring_migration_required',
        )
        .having(
          (issue) => issue.severity,
          'severity',
          ValidationSeverity.error,
        ),
  );
  expect(
    plugin.describePendingChanges(workspace, document: document),
    same(PendingChanges.empty),
  );
}

Matcher _migrationStateError() => isA<StateError>().having(
  (error) => error.message,
  'message',
  contains('polygon_authoring_migration_required'),
);

EditorSessionController _controller({
  required AuthoringDomainPlugin plugin,
  required String workspacePath,
}) => EditorSessionController(
  pluginRegistry: AuthoringPluginRegistry(
    plugins: <AuthoringDomainPlugin>[plugin],
  ),
  initialPluginId: plugin.id,
  initialWorkspacePath: workspacePath,
);

final class _LegacyFixture {
  _LegacyFixture._({
    required this.root,
    required this.prefabFile,
    required this.chunkFile,
    required this.prefabBytes,
    required this.chunkBytes,
  });

  final Directory root;
  final File prefabFile;
  final File chunkFile;
  final String prefabBytes;
  final String chunkBytes;

  EditorWorkspace get workspace => EditorWorkspace(rootPath: root.path);

  static _LegacyFixture create() {
    final root = Directory.systemTemp.createTempSync(
      'polygon_migration_required_',
    );
    const prefabBytes = '{"schemaVersion":2}\n';
    const chunkBytes = '{"schemaVersion":1}\n';
    final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath))
      ..createSync(recursive: true);
    prefabFile.writeAsStringSync(prefabBytes);
    final chunkFile = File(
      p.join(root.path, ChunkStore.chunksDirectoryPath, 'legacy.json'),
    )..createSync(recursive: true);
    chunkFile.writeAsStringSync(chunkBytes);
    return _LegacyFixture._(
      root: root,
      prefabFile: prefabFile,
      chunkFile: chunkFile,
      prefabBytes: prefabBytes,
      chunkBytes: chunkBytes,
    );
  }

  void dispose() => root.deleteSync(recursive: true);
}
