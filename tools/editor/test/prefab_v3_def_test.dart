import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('snapshots polygon source and preserves supplied shape order', () {
    final shapes = <TerrainSourceShapeDef>[
      _shape('collision_002', offset: 20),
      _shape('collision_001'),
    ];
    final tags = <String>['stone'];

    final prefab = _prefab(collisionShapes: shapes, tags: tags);
    shapes.clear();
    tags.clear();

    expect(prefab.collisionShapes.map((shape) => shape.shapeId), <String>[
      'collision_002',
      'collision_001',
    ]);
    expect(prefab.tags, <String>['stone']);
    expect(() => prefab.collisionShapes.clear(), throwsUnsupportedError);
    expect(() => prefab.tags.clear(), throwsUnsupportedError);
  });

  test(
    'copy and equality include collision, metadata, and revision semantics',
    () {
      final original = _prefab();
      final equivalent = _prefab();
      final edited = original.copyWith(
        revision: 4,
        collisionShapes: <TerrainSourceShapeDef>[
          _shape('collision_001', offset: 2),
        ],
      );

      expect(original, equivalent);
      expect(original.hashCode, equivalent.hashCode);
      expect(edited, isNot(original));
      expect(edited.revision, 4);
      expect(edited.collisionShapes.single.vertices.first.xHalfPixels, 2);
      expect(original.renamed('renamed').id, 'renamed');
    },
  );

  test('emits prefab-v3 collisionShapes without legacy colliders', () {
    final json = _prefab().toJson();

    expect(json['collisionShapes'], isA<List<Object>>());
    expect(json, isNot(contains('colliders')));
    expect(json['visualSource'], <String, Object?>{
      'type': 'atlas_slice',
      'sliceId': 'slice_01',
    });
  });
}

PrefabV3Def _prefab({
  Iterable<TerrainSourceShapeDef>? collisionShapes,
  Iterable<String> tags = const <String>['stone'],
}) => PrefabV3Def(
  prefabKey: 'prefab_key',
  id: 'prefab_id',
  revision: 3,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('slice_01'),
  anchorXPx: 8,
  anchorYPx: 12,
  collisionShapes:
      collisionShapes ?? <TerrainSourceShapeDef>[_shape('collision_001')],
  tags: tags,
);

TerrainSourceShapeDef _shape(String shapeId, {int offset = 0}) =>
    TerrainSourceShapeDef(
      shapeId: shapeId,
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: offset, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: offset + 10, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: offset + 10, yHalfPixels: 10),
        TerrainSourceVertexDef(xHalfPixels: offset, yHalfPixels: 10),
      ],
    );
