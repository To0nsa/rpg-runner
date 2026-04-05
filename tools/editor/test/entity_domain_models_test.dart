import 'package:flutter_test/flutter_test.dart';

import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';

void main() {
  const binding = EntitySourceBinding(
    kind: EntitySourceBindingKind.enemyAabbExpression,
    sourcePath: 'lib/src/enemies.dart',
    startOffset: 0,
    endOffset: 10,
    sourceSnippet: 'ColliderAabbDef(...)',
  );
  const entry = EntityEntry(
    id: 'enemy.test',
    label: 'Enemy: Test',
    entityType: EntityType.enemy,
    halfX: 12,
    halfY: 14,
    offsetX: 0,
    offsetY: 0,
    sourcePath: 'lib/src/enemies.dart',
    sourceBinding: binding,
  );
  const loadIssue = ValidationIssue(
    severity: ValidationSeverity.warning,
    code: 'test_issue',
    message: 'Test issue',
  );

  test('EntityReferenceVisual snapshots animation views immutably', () {
    final animViews = <String, EntityReferenceAnimView>{
      'idle': const EntityReferenceAnimView(assetPath: 'idle.png'),
    };
    final visual = EntityReferenceVisual(
      assetPath: 'idle.png',
      animViewsByKey: animViews,
    );

    animViews['run'] = const EntityReferenceAnimView(assetPath: 'run.png');

    expect(visual.animViewsByKey.keys, <String>['idle']);
    expect(
      () => visual.animViewsByKey['hit'] = const EntityReferenceAnimView(
        assetPath: 'hit.png',
      ),
      throwsUnsupportedError,
    );
  });

  test('EntityDocument snapshots list and map inputs immutably', () {
    final entries = <EntityEntry>[entry];
    final baselineById = <String, EntityEntry>{entry.id: entry};
    final loadIssues = <ValidationIssue>[loadIssue];
    final document = EntityDocument(
      entries: entries,
      baselineById: baselineById,
      runtimeGridCellSize: 32,
      loadIssues: loadIssues,
    );

    entries.clear();
    baselineById.clear();
    loadIssues.clear();

    expect(document.entries, <EntityEntry>[entry]);
    expect(document.baselineById, <String, EntityEntry>{entry.id: entry});
    expect(document.loadIssues, <ValidationIssue>[loadIssue]);
    expect(() => document.entries.add(entry), throwsUnsupportedError);
    expect(
      () => document.baselineById['other'] = entry,
      throwsUnsupportedError,
    );
    expect(() => document.loadIssues.add(loadIssue), throwsUnsupportedError);
  });

  test('EntityScene snapshots entries immutably', () {
    final entries = <EntityEntry>[entry];
    final scene = EntityScene(entries: entries, runtimeGridCellSize: 32);

    entries.clear();

    expect(scene.entries, <EntityEntry>[entry]);
    expect(() => scene.entries.add(entry), throwsUnsupportedError);
  });
}
