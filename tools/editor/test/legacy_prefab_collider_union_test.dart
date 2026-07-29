import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/prefabs/migration/legacy_prefab_collider_union.dart';
import 'package:runner_editor/src/prefabs/migration/reviewed_legacy_prefab_collision_reauthorings.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('isolated odd-sized AABB becomes one exact clockwise loop', () {
    final result = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/odd',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 3, height: 5),
      ],
    );

    expect(result.canMigrate, isTrue);
    expect(result.occupiedAreaHalfPixelSquared, BigInt.from(60));
    expect(result.plannedAreaHalfPixelSquared, BigInt.from(60));
    expect(result.areaDeltaHalfPixelSquared, BigInt.zero);
    expect(result.isReauthored, isFalse);
    expect(result.shapes.single.shapeId, 'collision_001');
    expect(_vertices(result.shapes.single), const <(int, int)>[
      (-3, -5),
      (3, -5),
      (3, 5),
      (-3, 5),
    ]);
  });

  test('overlapping rectangles become the documented concave union', () {
    final result = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/concave',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 16, offsetY: 16, width: 32, height: 32),
        PrefabColliderDef(offsetX: 32, offsetY: 32, width: 32, height: 32),
      ],
    );

    expect(result.canMigrate, isTrue);
    expect(result.shapes, hasLength(1));
    expect(_vertices(result.shapes.single), const <(int, int)>[
      (0, 0),
      (64, 0),
      (64, 32),
      (96, 32),
      (96, 96),
      (32, 96),
      (32, 64),
      (0, 64),
    ]);
  });

  test('edge-disconnected components receive stable canonical IDs', () {
    const colliders = <PrefabColliderDef>[
      PrefabColliderDef(offsetX: 10, offsetY: 0, width: 4, height: 4),
      PrefabColliderDef(offsetX: -10, offsetY: 0, width: 4, height: 4),
    ];
    final forward = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/disconnected',
      colliders: colliders,
    );
    final reversed = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/disconnected',
      colliders: colliders.reversed,
    );

    expect(forward.canMigrate, isTrue);
    expect(forward.shapes.map((shape) => shape.shapeId), <String>[
      'collision_001',
      'collision_002',
    ]);
    expect(forward.shapes, reversed.shapes);
    expect(_vertices(forward.shapes.first).first.$1, -24);
    expect(_vertices(forward.shapes.last).first.$1, 16);
  });

  test('full shared edge merges while point-only contact blocks', () {
    final merged = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/shared_edge',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 10, height: 10),
        PrefabColliderDef(offsetX: 10, offsetY: 0, width: 10, height: 10),
      ],
    );
    final pointContact = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/point_contact',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 10, height: 10),
        PrefabColliderDef(offsetX: 10, offsetY: 10, width: 10, height: 10),
      ],
    );

    expect(merged.canMigrate, isTrue);
    expect(merged.shapes, hasLength(1));
    expect(_vertices(merged.shapes.single), const <(int, int)>[
      (-10, -10),
      (30, -10),
      (30, 10),
      (-10, 10),
    ]);
    expect(pointContact.canMigrate, isFalse);
    expect(pointContact.shapes, isEmpty);
    expect(pointContact.issues.single.code, 'legacy_point_contact');
  });

  test('enclosed unoccupied component blocks as a union hole', () {
    final result = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/hole',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 10, offsetY: 2, width: 20, height: 4),
        PrefabColliderDef(offsetX: 10, offsetY: 18, width: 20, height: 4),
        PrefabColliderDef(offsetX: 2, offsetY: 10, width: 4, height: 12),
        PrefabColliderDef(offsetX: 18, offsetY: 10, width: 4, height: 12),
      ],
    );

    expect(result.canMigrate, isFalse);
    expect(result.shapes, isEmpty);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_union_hole',
    ]);
  });

  test(
    'invalid sizes and source-range overflow fail without partial shapes',
    () {
      final result = LegacyPrefabColliderUnion.plan(
        sourcePath: 'test/invalid',
        colliders: const <PrefabColliderDef>[
          PrefabColliderDef(offsetX: 0, offsetY: 0, width: 0, height: 4),
          PrefabColliderDef(
            offsetX: 0x7fffffffffffffff,
            offsetY: 0,
            width: 4,
            height: 4,
          ),
        ],
      );

      expect(result.canMigrate, isFalse);
      expect(result.shapes, isEmpty);
      expect(result.issues.map((issue) => issue.code), <String>[
        'invalid_legacy_collider',
        'legacy_coordinate_range',
      ]);
    },
  );

  test('duplicate rectangles preserve occupied area once', () {
    final result = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/duplicate',
      colliders: const <PrefabColliderDef>[
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 6),
        PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 6),
      ],
    );

    expect(result.canMigrate, isTrue);
    expect(result.shapes, hasLength(1));
    expect(result.occupiedAreaHalfPixelSquared, BigInt.from(192));
  });

  test('repository audit isolates minimum-edge migration blockers', () async {
    final data = await const PrefabStore().load(_repoRootPath());
    var collisionBearingPrefabs = 0;
    var decorationPrefabs = 0;
    var multiColliderPrefabs = 0;
    var automaticallyMigratedPrefabs = 0;
    var outputShapes = 0;
    var maximumShapes = 0;
    var maximumVertices = 0;
    final blockers = <String>[];

    for (final prefab in data.prefabs) {
      final result = LegacyPrefabColliderUnion.plan(
        sourcePath: '${PrefabStore.prefabDefsPath}:${prefab.prefabKey}',
        colliders: prefab.colliders,
      );
      blockers.addAll(
        result.issues.map(
          (issue) => '${prefab.prefabKey}: ${issue.code} ${issue.message}',
        ),
      );
      if (prefab.colliders.isEmpty) {
        decorationPrefabs += 1;
      } else {
        collisionBearingPrefabs += 1;
        if (result.canMigrate) automaticallyMigratedPrefabs += 1;
      }
      if (prefab.colliders.length > 1) multiColliderPrefabs += 1;
      outputShapes += result.shapes.length;
      if (result.shapes.length > maximumShapes) {
        maximumShapes = result.shapes.length;
      }
      for (final shape in result.shapes) {
        if (shape.vertices.length > maximumVertices) {
          maximumVertices = shape.vertices.length;
        }
      }
    }

    expect(collisionBearingPrefabs, 70);
    expect(decorationPrefabs, 29);
    expect(multiColliderPrefabs, 29);
    expect(automaticallyMigratedPrefabs, 67);
    expect(outputShapes, 85);
    expect(maximumShapes, 3);
    expect(maximumVertices, 14);
    expect(blockers, <String>[
      'dark_menhir_01: legacy_core_minimum_edge_length '
          'Every source edge must be at least one world unit long.',
      'dark_menhir_03: legacy_core_minimum_edge_length '
          'Every source edge must be at least one world unit long.',
      'ruin_stone_00: legacy_core_minimum_edge_length '
          'Every source edge must be at least one world unit long.',
    ]);
  });

  test('reviewed corrections resolve all repository prefab blockers', () async {
    final data = await const PrefabStore().load(_repoRootPath());
    var collisionBearingPrefabs = 0;
    var automaticallyMigratedPrefabs = 0;
    var outputShapes = 0;
    final appliedAreaDeltas = <String, BigInt>{};
    final correctedVertices = <String, List<(int, int)>>{};
    final blockers = <String>[];

    for (final prefab in data.prefabs) {
      final reauthoring =
          ReviewedLegacyPrefabCollisionReauthorings.forPrefabKey(
            prefab.prefabKey,
          );
      final result = LegacyPrefabColliderUnion.plan(
        sourcePath: '${PrefabStore.prefabDefsPath}:${prefab.prefabKey}',
        colliders: prefab.colliders,
        reviewedReauthoring: reauthoring,
      );
      blockers.addAll(
        result.issues.map(
          (issue) => '${prefab.prefabKey}: ${issue.code} ${issue.message}',
        ),
      );
      if (prefab.colliders.isNotEmpty) {
        collisionBearingPrefabs += 1;
        if (result.canMigrate) automaticallyMigratedPrefabs += 1;
      }
      outputShapes += result.shapes.length;
      if (result.isReauthored) {
        appliedAreaDeltas[prefab.prefabKey] = result.areaDeltaHalfPixelSquared;
        correctedVertices[prefab.prefabKey] = _vertices(result.shapes.single);
      }
    }

    expect(blockers, isEmpty);
    expect(collisionBearingPrefabs, 70);
    expect(automaticallyMigratedPrefabs, 70);
    expect(outputShapes, 88);
    expect(appliedAreaDeltas, <String, BigInt>{
      'dark_menhir_01': BigInt.from(34),
      'dark_menhir_03': BigInt.from(25),
      'ruin_stone_00': BigInt.from(36),
    });
    expect(correctedVertices, <String, List<(int, int)>>{
      'dark_menhir_01': <(int, int)>[
        (-33, -137),
        (4, -137),
        (4, -103),
        (37, -103),
        (37, -1),
        (-33, -1),
      ],
      'dark_menhir_03': <(int, int)>[
        (-35, -71),
        (11, -71),
        (11, -50),
        (36, -50),
        (36, 3),
        (-35, 3),
      ],
      'ruin_stone_00': <(int, int)>[
        (-20, -253),
        (-1, -253),
        (-1, -217),
        (8, -217),
        (8, -3),
        (-20, -3),
      ],
    });
  });

  test('reviewed correction blocks when its legacy collider source drifts', () {
    final reauthoring = ReviewedLegacyPrefabCollisionReauthorings.forPrefabKey(
      'dark_menhir_01',
    )!;
    final drifted = <PrefabColliderDef>[
      reauthoring.expectedColliders.first.copyWith(width: 20),
      reauthoring.expectedColliders.last,
    ];

    final result = LegacyPrefabColliderUnion.plan(
      sourcePath: 'test/reauthoring_drift',
      colliders: drifted,
      reviewedReauthoring: reauthoring,
    );

    expect(result.canMigrate, isFalse);
    expect(result.shapes, isEmpty);
    expect(result.issues.map((issue) => issue.code), <String>[
      'legacy_reauthoring_source_drift',
    ]);
  });
}

List<(int, int)> _vertices(TerrainSourceShapeDef shape) => shape.vertices
    .map((vertex) => (vertex.xHalfPixels, vertex.yHalfPixels))
    .toList(growable: false);

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
