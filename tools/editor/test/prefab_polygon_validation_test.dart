import 'package:flutter_test/flutter_test.dart';
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
      _validate(<TerrainSourceShapeDef>[
        noncanonical,
      ]).map((issue) => issue.code),
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
