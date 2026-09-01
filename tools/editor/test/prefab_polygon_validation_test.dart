import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_capacity.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/validation/prefab_validation.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test(
    'accepts canonical collision that intersects anchor-relative bounds',
    () {
      final issues = _validate(<TerrainSourceShapeDef>[
        _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
      ]);

      expect(issues, isEmpty);
    },
  );

  test('enforces colliding-kind and decoration shape contracts', () {
    final colliderless = _validate(const <TerrainSourceShapeDef>[]);
    expect(
      colliderless.map((issue) => issue.code),
      contains('prefab_collision_shape_missing'),
    );
    expect(colliderless.single.severity, PrefabValidationSeverity.warning);
    expect(
      _validate(<TerrainSourceShapeDef>[
        _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
      ], kind: PrefabKind.decoration).map((issue) => issue.code),
      contains('decoration_prefab_collision_shape_forbidden'),
    );
  });

  test('delegates canonical policy and occupied overlap to Core', () {
    final noncanonical = TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
      ],
    );
    final overlap = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 4, bottom: 8),
      _rectangle('collision_002', left: 0, top: -8, right: 8, bottom: 8),
    ];

    expect(
      _validate(<TerrainSourceShapeDef>[noncanonical])
          .map((issue) => issue.code),
      contains('noncanonical_start'),
    );
    expect(
      _validate(overlap).map((issue) => issue.code),
      contains('polygon_area_overlap'),
    );
  });

  test('permits shared boundaries without reporting occupied overlap', () {
    final issues = _validate(<TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 0, bottom: 8),
      _rectangle('collision_002', left: 0, top: -8, right: 8, bottom: 8),
    ]);

    expect(
      issues.map((issue) => issue.code),
      isNot(contains('polygon_area_overlap')),
    );
  });

  test('rejects prefab collision vertices outside the whole-pixel grid', () {
    final issues = _validate(<TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -7, top: -8, right: 7, bottom: 8),
    ]);

    final issue = issues.singleWhere(
      (issue) => issue.code == 'prefab_collision_shape_not_whole_pixel',
    );
    expect(issue.severity, PrefabValidationSeverity.error);
    expect(issue.ownerKey, 'test_prefab');
    expect(issue.shapeId, 'collision_001');
    expect(issue.message, contains('4 vertex/vertices'));
  });

  test(
    'requires positive-area visual intersection and reports exact extent',
    () {
      final outside = _validate(<TerrainSourceShapeDef>[
        _rectangle('collision_001', left: 12, top: -8, right: 20, bottom: 8),
      ]);
      final partial = _validate(<TerrainSourceShapeDef>[
        _rectangle('collision_001', left: 8, top: -8, right: 20, bottom: 8),
      ]);

      expect(
        outside.map((issue) => issue.code),
        contains('prefab_collision_shapes_outside_visual_source'),
      );
      final outsideExtent = outside.singleWhere(
        (issue) => issue.code == 'prefab_collision_shape_outside_visual_bounds',
      );
      expect(outsideExtent.severity, PrefabValidationSeverity.warning);
      expect(outsideExtent.message, contains('right=5 px'));
      expect(
        partial.map((issue) => issue.code),
        isNot(contains('prefab_collision_shapes_outside_visual_source')),
      );
      expect(partial.single.severity, PrefabValidationSeverity.warning);
    },
  );

  test('forwards the Core per-prefab shape capacity limit', () {
    final shapes = <TerrainSourceShapeDef>[
      for (var index = 0; index < 65; index++)
        _rectangle(
          'collision_${(index + 1).toString().padLeft(3, '0')}',
          left: index * 6,
          top: 0,
          right: index * 6 + 4,
          bottom: 4,
        ),
    ];

    expect(
      _validate(
        shapes,
        anchorXPx: 0,
        anchorYPx: 0,
        sourceWidthPx: 300,
        sourceHeightPx: 20,
      ).map((issue) => issue.code),
      contains('prefab_shape_limit'),
    );
  });

  test('warns only above the prefab shape authoring target', () {
    List<TerrainSourceShapeDef> shapes(int count) => <TerrainSourceShapeDef>[
      for (var index = 0; index < count; index += 1)
        _rectangle(
          'collision_${(index + 1).toString().padLeft(3, '0')}',
          left: index * 6,
          top: 0,
          right: index * 6 + 4,
          bottom: 4,
        ),
    ];

    final atTarget = _validate(
      shapes(TerrainAuthoringCapacityTargets.shapesPerPrefab),
      anchorXPx: 0,
      anchorYPx: 0,
      sourceWidthPx: 100,
      sourceHeightPx: 10,
    );
    final aboveTarget = _validate(
      shapes(TerrainAuthoringCapacityTargets.shapesPerPrefab + 1),
      anchorXPx: 0,
      anchorYPx: 0,
      sourceWidthPx: 100,
      sourceHeightPx: 10,
    );

    expect(
      atTarget.map((issue) => issue.code),
      isNot(contains('prefab_shape_soft_target_exceeded')),
    );
    final warning = aboveTarget.singleWhere(
      (issue) => issue.code == 'prefab_shape_soft_target_exceeded',
    );
    expect(warning.severity, PrefabValidationSeverity.warning);
    expect(warning.ownerKey, 'test_prefab');
    expect(warning.shapeId, isEmpty);
    expect(warning.message, contains('17 collision shapes'));
  });

  test('warns only above the polygon vertex authoring target', () {
    final atTarget = _validate(
      <TerrainSourceShapeDef>[
        _strip(
          'collision_001',
          vertexCount: TerrainAuthoringCapacityTargets.verticesPerShape,
        ),
      ],
      anchorXPx: 0,
      anchorYPx: 0,
      sourceWidthPx: 20,
      sourceHeightPx: 20,
    );
    final aboveTarget = _validate(
      <TerrainSourceShapeDef>[
        _strip(
          'collision_001',
          vertexCount: TerrainAuthoringCapacityTargets.verticesPerShape + 1,
        ),
      ],
      anchorXPx: 0,
      anchorYPx: 0,
      sourceWidthPx: 20,
      sourceHeightPx: 20,
    );

    expect(
      atTarget.map((issue) => issue.code),
      isNot(contains('polygon_vertex_soft_target_exceeded')),
    );
    final warning = aboveTarget.singleWhere(
      (issue) => issue.code == 'polygon_vertex_soft_target_exceeded',
    );
    expect(warning.severity, PrefabValidationSeverity.warning);
    expect(warning.ownerKey, 'test_prefab');
    expect(warning.shapeId, 'collision_001');
    expect(warning.sourcePath, endsWith(':collision_001'));
    expect(warning.message, contains('25 vertices'));
  });

  test('requires visual dimensions to be provided as one resolved pair', () {
    expect(
      () => validatePrefabCollisionShapes(
        prefabId: 'test_prefab',
        prefabKey: 'test_prefab',
        kind: PrefabKind.obstacle,
        anchorXPx: 0,
        anchorYPx: 0,
        collisionShapes: <TerrainSourceShapeDef>[
          _rectangle('collision_001', left: 0, top: 0, right: 8, bottom: 8),
        ],
        sourceWidthPx: 10,
        sourceHeightPx: null,
        sourcePath: 'test/prefab_defs.json:test_prefab',
      ),
      throwsArgumentError,
    );
  });
}

List<PrefabValidationIssue> _validate(
  Iterable<TerrainSourceShapeDef> shapes, {
  PrefabKind kind = PrefabKind.obstacle,
  int anchorXPx = 5,
  int anchorYPx = 5,
  int? sourceWidthPx = 10,
  int? sourceHeightPx = 10,
}) => validatePrefabCollisionShapes(
  prefabId: 'test_prefab',
  prefabKey: 'test_prefab',
  kind: kind,
  anchorXPx: anchorXPx,
  anchorYPx: anchorYPx,
  collisionShapes: shapes,
  sourceWidthPx: sourceWidthPx,
  sourceHeightPx: sourceHeightPx,
  sourcePath: 'test/prefab_defs.json:test_prefab',
);

TerrainSourceShapeDef _rectangle(
  String shapeId, {
  required int left,
  required int top,
  required int right,
  required int bottom,
}) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: top),
    TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: bottom),
    TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: bottom),
  ],
);

TerrainSourceShapeDef _strip(String shapeId, {required int vertexCount}) {
  final topCount = (vertexCount + 1) ~/ 2;
  final bottomCount = vertexCount - topCount;
  return TerrainSourceShapeDef(
    shapeId: shapeId,
    vertices: <TerrainSourceVertexDef>[
      for (var x = 0; x < topCount; x += 1)
        TerrainSourceVertexDef(
          xHalfPixels: x * 2,
          yHalfPixels: x.isEven ? 0 : 2,
        ),
      for (var x = bottomCount - 1; x >= 0; x -= 1)
        TerrainSourceVertexDef(
          xHalfPixels: x * 2,
          yHalfPixels: x.isEven ? 20 : 22,
        ),
    ],
  );
}
