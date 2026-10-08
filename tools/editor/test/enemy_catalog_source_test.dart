import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

import 'test_support/entity_test_support.dart';

void main() {
  const catalogPath = 'packages/runner_core/lib/enemies/enemy_catalog.dart';
  const unocoPath = 'packages/runner_core/lib/enemies/catalog/unoco_enemy.dart';
  late Directory root;
  late EditorWorkspace workspace;
  late EntityDomainPlugin plugin;

  setUp(() {
    root = Directory.systemTemp.createTempSync('enemy_catalog_sources_');
    writeEntityColliderFixture(root.path);
    copyRepositoryEnemySources(root.path);
    workspace = EditorWorkspace(rootPath: root.path);
    plugin = EntityDomainPlugin();
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('every registered enemy resolves its own writable definition', () async {
    final document = await plugin.loadFromRepo(workspace) as EntityDocument;
    expect(
      document.loadIssues.where(
        (issue) => issue.severity == ValidationSeverity.error,
      ),
      isEmpty,
    );
    final enemies = document.entries.where(
      (entry) => entry.entityType == EntityType.enemy,
    );
    expect(enemies, hasLength(EnemyId.values.length));
    expect(
      enemies.map((entry) => entry.sourcePath).toSet(),
      hasLength(EnemyId.values.length),
    );
    for (final id in EnemyId.values) {
      final entry = enemies.singleWhere(
        (entry) => entry.id == 'enemy.${id.name}',
      );
      final actual = const EnemyCatalog().get(id);
      expect(entry.halfX, actual.collider.halfX, reason: id.name);
      expect(entry.halfY, actual.collider.halfY, reason: id.name);
      expect(entry.offsetX, actual.collider.offsetX, reason: id.name);
      expect(entry.offsetY, actual.collider.offsetY, reason: id.name);
      expect(entry.referenceVisual, isNotNull, reason: id.name);
      expect(
        entry.referenceVisual!.renderScale,
        actual.renderScale,
        reason: id.name,
      );
      expect(
        entry.referenceVisual!.anchorXPx,
        actual.renderAnim.anchorPoint.x,
        reason: id.name,
      );
      expect(
        entry.referenceVisual!.anchorYPx,
        actual.renderAnim.anchorPoint.y,
        reason: id.name,
      );
      expect(
        entry.colliderBindings.halfX.sourceBinding.sourcePath,
        entry.sourcePath,
      );
      expect(
        entry.sourcePath.replaceAll('\\', '/'),
        startsWith('packages/runner_core/lib/enemies/catalog/'),
      );
    }
  });

  test('editing Unoco writes and backs up only its definition', () async {
    final document = await plugin.loadFromRepo(workspace) as EntityDocument;
    final unoco = document.entries.singleWhere(
      (entry) => entry.id == 'enemy.unocoDemon',
    );
    final sources = <String, String>{
      for (final file in Directory(
        workspace.resolve('packages/runner_core/lib/enemies'),
      ).listSync(recursive: true).whereType<File>())
        file.path: file.readAsStringSync(),
    };
    final edited = plugin.applyEdit(
      document,
      buildEntityUpdateCommand(
        unoco,
        halfX: 8.5,
        anchorXPx: 30,
        anchorYPx: 37,
        renderScale: .6,
        castOriginOffset: 21,
      ),
    );
    expect(
      plugin
          .validate(edited)
          .where((issue) => issue.severity == ValidationSeverity.error),
      isEmpty,
    );
    final result = await plugin.exportToRepo(workspace, document: edited);
    expect(result.applied, isTrue);
    final next = await plugin.loadFromRepo(workspace) as EntityDocument;
    final updated = next.entries.singleWhere((entry) => entry.id == unoco.id);
    expect(updated.halfX, 8.5);
    expect(updated.referenceVisual!.anchorXPx, 30);
    expect(updated.referenceVisual!.anchorYPx, 37);
    expect(updated.referenceVisual!.renderScale, .6);
    expect(updated.castOriginOffset, 21);
    for (final source in sources.entries) {
      if (p.equals(source.key, workspace.resolve(unocoPath))) {
        expect(File('${source.key}.bak').readAsStringSync(), source.value);
      } else {
        expect(
          File(source.key).readAsStringSync(),
          source.value,
          reason: source.key,
        );
        expect(
          File('${source.key}.bak').existsSync(),
          isFalse,
          reason: source.key,
        );
      }
    }
  });

  test(
    'definition drift rejects a pending edit without writing the registry',
    () async {
      final document = await plugin.loadFromRepo(workspace) as EntityDocument;
      final unoco = document.entries.singleWhere(
        (entry) => entry.id == 'enemy.unocoDemon',
      );
      final edited = plugin.applyEdit(
        document,
        buildEntityUpdateCommand(unoco, halfX: 8.5),
      );
      final definition = File(workspace.resolve(unocoPath));
      final source = definition.readAsStringSync();
      final drifted = source.replaceFirst('halfX: 8.125', 'halfX: 8.25');
      expect(drifted, isNot(source));
      definition.writeAsStringSync(drifted);
      final registry = File(workspace.resolve(catalogPath)).readAsStringSync();
      final result = await plugin.exportToRepo(workspace, document: edited);
      expect(result.outcome, ExportOutcome.sourceDrift);
      expect(definition.readAsStringSync(), drifted);
      expect(File('${definition.path}.bak').existsSync(), isFalse);
      expect(File(workspace.resolve(catalogPath)).readAsStringSync(), registry);
    },
  );

  test('missing imported definition blocks export', () async {
    File(workspace.resolve(unocoPath)).deleteSync();
    final document = await plugin.loadFromRepo(workspace) as EntityDocument;
    expect(
      document.loadIssues,
      contains(
        isA<ValidationIssue>()
            .having((issue) => issue.code, 'code', 'actor_archetype_shape')
            .having(
              (issue) => issue.severity,
              'severity',
              ValidationSeverity.error,
            ),
      ),
    );
    final grojib = document.entries.singleWhere(
      (entry) => entry.id == 'enemy.grojib',
    );
    final edited = plugin.applyEdit(
      document,
      buildEntityUpdateCommand(grojib, halfX: 20),
    );
    final result = await plugin.exportToRepo(workspace, document: edited);
    expect(result.outcome, ExportOutcome.validationFailed);
    expect(
      File('${workspace.resolve(grojib.sourcePath)}.bak').existsSync(),
      isFalse,
    );
  });
}
