import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:test/test.dart';

void main() {
  test('Core diagnostic adaptation preserves lineage and derives severity', () {
    final blocking = TerrainAuthoringIssue.fromCore(
      diagnostic: const TerrainDiagnostic(
        sourcePath: 'chunks/forest/chunk.json#direct=ground',
        shapeId: 'ground',
        elementIndex: 2,
        code: 'minimum_edge_length',
        message: 'Edge is too short.',
      ),
      ownerKey: 'chunk',
      placementKey: null,
    );
    final warning = TerrainAuthoringIssue.fromCore(
      diagnostic: const TerrainDiagnostic(
        sourcePath: 'prefabs/prefab.json#shape=collision_001',
        shapeId: 'collision_001',
        elementIndex: 1,
        code: 'normalized_collinear_vertex',
        message: 'Vertex was normalized.',
      ),
      ownerKey: 'prefab_rock',
      placementKey: 'prefab_rock|20|30|0',
    );

    expect(blocking.severity, TerrainAuthoringIssueSeverity.error);
    expect(blocking.isBlocking, isTrue);
    expect(blocking.ownerKey, 'chunk');
    expect(blocking.shapeId, 'ground');
    expect(blocking.elementIndex, 2);
    expect(warning.severity, TerrainAuthoringIssueSeverity.warning);
    expect(warning.isBlocking, isFalse);
    expect(warning.ownerKey, 'prefab_rock');
    expect(warning.placementKey, 'prefab_rock|20|30|0');
  });

  test('canonical ordering covers every machine-readable lineage field', () {
    TerrainAuthoringIssue issue({
      String sourcePath = 'b',
      String ownerKey = 'owner',
      String? placementKey,
      String? shapeId,
      int? elementIndex,
      String code = 'code',
      TerrainAuthoringIssueSeverity severity =
          TerrainAuthoringIssueSeverity.error,
      String message = 'message',
    }) => TerrainAuthoringIssue(
      severity: severity,
      code: code,
      message: message,
      sourcePath: sourcePath,
      ownerKey: ownerKey,
      placementKey: placementKey,
      shapeId: shapeId,
      elementIndex: elementIndex,
    );

    final expected = <TerrainAuthoringIssue>[
      issue(sourcePath: 'a'),
      issue(ownerKey: 'a'),
      issue(),
      issue(placementKey: 'a'),
      issue(placementKey: 'a', shapeId: 'a'),
      issue(placementKey: 'a', shapeId: 'a', elementIndex: 0),
      issue(
        placementKey: 'a',
        shapeId: 'a',
        elementIndex: 0,
        code: 'other',
        severity: TerrainAuthoringIssueSeverity.warning,
      ),
      issue(placementKey: 'a', shapeId: 'a', elementIndex: 0, code: 'other'),
    ];
    final snapshot = canonicalTerrainAuthoringIssues(expected.reversed);

    expect(snapshot, expected);
    expect(() => snapshot.add(issue(sourcePath: 'z')), throwsUnsupportedError);
    expect(
      issue(message: 'different').compareTo(issue(message: 'message')),
      0,
      reason: 'Human-readable text must not affect diagnostic ordering.',
    );
  });

  test('malformed envelope identities fail immediately', () {
    TerrainAuthoringIssue create({
      String code = 'code',
      String message = 'message',
      String sourcePath = 'source',
      String ownerKey = 'owner',
      String? placementKey,
      String? shapeId,
      int? elementIndex,
    }) => TerrainAuthoringIssue(
      severity: TerrainAuthoringIssueSeverity.error,
      code: code,
      message: message,
      sourcePath: sourcePath,
      ownerKey: ownerKey,
      placementKey: placementKey,
      shapeId: shapeId,
      elementIndex: elementIndex,
    );

    expect(() => create(code: ''), throwsArgumentError);
    expect(() => create(message: ''), throwsArgumentError);
    expect(() => create(sourcePath: ''), throwsArgumentError);
    expect(() => create(ownerKey: ''), throwsArgumentError);
    expect(() => create(placementKey: ''), throwsArgumentError);
    expect(() => create(shapeId: ''), throwsArgumentError);
    expect(() => create(elementIndex: -1), throwsArgumentError);
  });
}
