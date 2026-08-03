import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_collision_commit.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/validation/prefab_validation.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  const policy = PrefabV3CollisionCommitPolicy();

  test('accepted owner-valid commit replaces one prefab and bumps once', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final after = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 10, bottom: 8),
    ];
    final data = _data(before);

    final result = policy.apply(
      data: data,
      prefabKey: 'target',
      commit: _commit(before: before, after: after),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isTrue);
    expect(result.issues, isEmpty);
    expect(result.data, isNot(same(data)));
    expect(result.data.prefabs.first, same(data.prefabs.first));
    final updated = result.data.prefabs.last;
    expect(updated.prefabKey, 'target');
    expect(updated.id, 'target');
    expect(updated.revision, 8);
    expect(updated.collisionShapes, after);
  });

  test('no-op commit preserves document identity and revision', () {
    final shapes = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final data = _data(shapes);

    final result = policy.apply(
      data: data,
      prefabKey: 'target',
      commit: _commit(before: shapes, after: shapes),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isFalse);
    expect(result.data, same(data));
    expect(result.data.prefabs.last.revision, 7);
  });

  test('stale commit rejects without changing document', () {
    final current = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final stale = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -6, top: -8, right: 8, bottom: 8),
    ];
    final data = _data(current);

    final result = policy.apply(
      data: data,
      prefabKey: 'target',
      commit: _commit(before: stale, after: current),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    expect(result.accepted, isFalse);
    expect(result.changed, isFalse);
    expect(result.data, same(data));
    expect(result.issues.single.code, 'prefab_polygon_commit_stale');
  });

  test('allows cleared collision and rejects decoration collision', () {
    final obstacleShapes = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final obstacleData = _data(obstacleShapes);
    final obstacleResult = policy.apply(
      data: obstacleData,
      prefabKey: 'target',
      commit: _commit(
        before: obstacleShapes,
        after: const <TerrainSourceShapeDef>[],
      ),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    final decorationData = _data(
      const <TerrainSourceShapeDef>[],
      targetKind: PrefabKind.decoration,
    );
    final decorationResult = policy.apply(
      data: decorationData,
      prefabKey: 'target',
      commit: _commit(
        before: const <TerrainSourceShapeDef>[],
        after: obstacleShapes,
      ),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    expect(obstacleResult.accepted, isTrue);
    expect(obstacleResult.changed, isTrue);
    final cleared = obstacleResult.data.prefabs.singleWhere(
      (prefab) => prefab.prefabKey == 'target',
    );
    expect(cleared.collisionShapes, isEmpty);
    expect(cleared.revision, 8);
    expect(
      obstacleResult.issues.map((issue) => issue.code),
      contains('prefab_collision_shape_missing'),
    );
    expect(
      obstacleResult.issues.single.severity,
      PrefabValidationSeverity.warning,
    );
    expect(decorationResult.accepted, isFalse);
    expect(decorationResult.data, same(decorationData));
    expect(
      decorationResult.issues.map((issue) => issue.code),
      contains('decoration_prefab_collision_shape_forbidden'),
    );
  });

  test('non-blocking outside extent warning commits normally', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final after = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 12, bottom: 8),
    ];

    final result = policy.apply(
      data: _data(before),
      prefabKey: 'target',
      commit: _commit(before: before, after: after),
      sourceWidthPx: 10,
      sourceHeightPx: 10,
    );

    expect(result.accepted, isTrue);
    expect(result.changed, isTrue);
    expect(result.issues, hasLength(1));
    expect(
      result.issues.single.code,
      'prefab_collision_shape_outside_visual_bounds',
    );
    expect(result.issues.single.severity, PrefabValidationSeverity.warning);
  });

  test(
    'missing owner and noncanonical shape order reject deterministically',
    () {
      final before = <TerrainSourceShapeDef>[
        _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
      ];
      final data = _data(before);
      final missing = policy.apply(
        data: data,
        prefabKey: 'missing',
        commit: _commit(before: before, after: before),
        sourceWidthPx: 10,
        sourceHeightPx: 10,
      );
      final unordered = <TerrainSourceShapeDef>[
        _rectangle('collision_002', left: 0, top: -8, right: 8, bottom: 8),
        _rectangle('collision_001', left: -8, top: -8, right: 0, bottom: 8),
      ];
      final noncanonical = policy.apply(
        data: data,
        prefabKey: 'target',
        commit: _commit(before: before, after: unordered),
        sourceWidthPx: 10,
        sourceHeightPx: 10,
      );

      expect(missing.accepted, isFalse);
      expect(missing.issues.single.code, 'prefab_polygon_owner_missing');
      expect(noncanonical.accepted, isFalse);
      expect(
        noncanonical.issues.single.code,
        'prefab_collision_shape_order_noncanonical',
      );
    },
  );

  test('colliding edit fails closed when visual bounds are unresolved', () {
    final before = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
    ];
    final after = <TerrainSourceShapeDef>[
      _rectangle('collision_001', left: -8, top: -8, right: 10, bottom: 8),
    ];
    final data = _data(before);

    final result = policy.apply(
      data: data,
      prefabKey: 'target',
      commit: _commit(before: before, after: after),
      sourceWidthPx: null,
      sourceHeightPx: null,
    );

    expect(result.accepted, isFalse);
    expect(result.data, same(data));
    expect(
      result.issues.single.code,
      'prefab_polygon_visual_bounds_unresolved',
    );
  });
}

PrefabV3FileData _data(
  Iterable<TerrainSourceShapeDef> targetShapes, {
  PrefabKind targetKind = PrefabKind.obstacle,
}) => PrefabV3FileData(
  slices: const <AtlasSliceDef>[],
  prefabs: <PrefabV3Def>[
    _prefab(
      prefabKey: 'first',
      revision: 3,
      collisionShapes: <TerrainSourceShapeDef>[
        _rectangle('collision_001', left: -8, top: -8, right: 8, bottom: 8),
      ],
    ),
    _prefab(
      prefabKey: 'target',
      revision: 7,
      kind: targetKind,
      collisionShapes: targetShapes,
    ),
  ],
);

PrefabV3Def _prefab({
  required String prefabKey,
  required int revision,
  required Iterable<TerrainSourceShapeDef> collisionShapes,
  PrefabKind kind = PrefabKind.obstacle,
}) => PrefabV3Def(
  prefabKey: prefabKey,
  id: prefabKey,
  revision: revision,
  status: PrefabStatus.active,
  kind: kind,
  visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
  anchorXPx: 5,
  anchorYPx: 5,
  collisionShapes: collisionShapes,
  tags: const <String>['test'],
);

TerrainPolygonInteractionCommit _commit({
  required Iterable<TerrainSourceShapeDef> before,
  required Iterable<TerrainSourceShapeDef> after,
}) => TerrainPolygonInteractionCommit(
  beforeShapes: before,
  afterShapes: after,
  beforeSelection: null,
  afterSelection: null,
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
