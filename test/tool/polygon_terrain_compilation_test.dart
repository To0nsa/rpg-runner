import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';

import '../../tool/polygon_terrain_compilation.dart';
import '../../tool/polygon_terrain_source.dart';

const String _fixtureDirectory = 'test/fixtures/polygon_terrain_generator';
const String _chunkSourcePath = 'chunks/forest/fixture_chunk.json';
const String _transformChunkSourcePath = 'chunks/forest/transform_chunk.json';
const String _migrationChunkSourcePath = 'chunks/forest/migration_chunk.json';

void main() {
  test('strict current-schema fixture compiles through Core exactly', () {
    final compiled = _compileFixture();
    final golden = _golden();

    expect(
      compiled.geometry.polygons,
      hasLength(golden['polygonCount']! as int),
    );
    expect(compiled.geometry.edges, hasLength(golden['edgeCount']! as int));
    expect(compiled.triangles, hasLength(golden['triangleCount']! as int));
    expect(
      <String, String>{
        'sourceSignature': compiled.geometry.sourceSignature(),
        'edgeSignature': compiled.geometry.edgeSignature(),
        'authoringPolygonSignature': compiled.authoringPolygonSignature(),
        'placementSignature': compiled.placementSignature(),
        'triangleSignature': compiled.triangleSignature(),
      },
      <String, Object?>{
        'sourceSignature': golden['sourceSignature'],
        'edgeSignature': golden['edgeSignature'],
        'authoringPolygonSignature': golden['authoringPolygonSignature'],
        'placementSignature': golden['placementSignature'],
        'triangleSignature': golden['triangleSignature'],
      },
    );

    final lineage = compiled.placementLineage.single;
    expect(lineage.placementKey, 'prefab_ramp|60|20|0');
    expect(lineage.prefabKey, 'prefab_ramp');
    expect(lineage.prefabRevision, 3);
    expect(lineage.scaleTenths, 5);
    expect(lineage.flipX, isTrue);
  });

  test(
    'transform and terrain feature fixture compiles through Core exactly',
    () {
      final compiled = _compileTransformFixture();
      final golden = _golden('transform_golden.json');

      expect(
        compiled.geometry.polygons,
        hasLength(golden['polygonCount']! as int),
      );
      expect(compiled.geometry.edges, hasLength(golden['edgeCount']! as int));
      expect(compiled.triangles, hasLength(golden['triangleCount']! as int));
      expect(
        <String, String>{
          'sourceSignature': compiled.geometry.sourceSignature(),
          'edgeSignature': compiled.geometry.edgeSignature(),
          'authoringPolygonSignature': compiled.authoringPolygonSignature(),
          'placementSignature': compiled.placementSignature(),
          'triangleSignature': compiled.triangleSignature(),
        },
        <String, Object?>{
          'sourceSignature': golden['sourceSignature'],
          'edgeSignature': golden['edgeSignature'],
          'authoringPolygonSignature': golden['authoringPolygonSignature'],
          'placementSignature': golden['placementSignature'],
          'triangleSignature': golden['triangleSignature'],
        },
      );

      expect(
        compiled.placementLineage
            .map(
              (lineage) => (
                lineage.placementKey,
                lineage.scaleTenths,
                lineage.flipX,
                lineage.flipY,
              ),
            )
            .toList(growable: false),
        <(String, int, bool, bool)>[
          ('prefab_asymmetric|30|30|0', 3, true, false),
          ('prefab_asymmetric|80|50|0', 30, false, true),
        ],
      );
      expect(
        <String, Set<(int, int)>>{
          for (final polygon in compiled.geometry.polygons)
            ?polygon.identity.placementKey: polygon.vertices
                .map((vertex) => (vertex.xTicks, vertex.yTicks))
                .toSet(),
        },
        <String, Set<(int, int)>>{
          'prefab_asymmetric|30|30|0': <(int, int)>{
            (29184, 30259),
            (31488, 30259),
            (31488, 31334),
            (29184, 31334),
          },
          'prefab_asymmetric|80|50|0': <(int, int)>{
            (74240, 45056),
            (97280, 45056),
            (97280, 55808),
            (74240, 55808),
          },
        },
      );
      expect(
        compiled.geometry.polygons
            .expand((polygon) => polygon.sourceVertices)
            .any((vertex) => vertex.xTicks.isOdd || vertex.yTicks.isOdd),
        isTrue,
      );
      expect(
        compiled.geometry.edges.any(
          (edge) =>
              edge.start.xTicks == 102400 &&
              edge.end.xTicks == 102400 &&
              <int>{
                edge.start.yTicks,
                edge.end.yTicks,
              }.containsAll(const <int>{82432, 133120}),
        ),
        isFalse,
        reason:
            'The exact shared solid boundary must be internal and cancelled.',
      );
      expect(
        compiled.geometry.edges.any(
          (edge) =>
              edge.start.xTicks == 20480 &&
              edge.start.yTicks == 102400 &&
              edge.end.xTicks == 61952 &&
              edge.end.yTicks == 82432,
        ),
        isTrue,
        reason: 'The reviewed flat-to-slope edge must survive compilation.',
      );
    },
  );

  test('legacy prefab migration fixture compiles through Core exactly', () {
    final compiled = _compileMigrationFixture();
    final golden = _golden('migration_golden.json');

    expect(
      compiled.geometry.polygons,
      hasLength(golden['polygonCount']! as int),
    );
    expect(compiled.geometry.edges, hasLength(golden['edgeCount']! as int));
    expect(compiled.triangles, hasLength(golden['triangleCount']! as int));
    expect(
      <String, String>{
        'sourceSignature': compiled.geometry.sourceSignature(),
        'edgeSignature': compiled.geometry.edgeSignature(),
        'authoringPolygonSignature': compiled.authoringPolygonSignature(),
        'placementSignature': compiled.placementSignature(),
        'triangleSignature': compiled.triangleSignature(),
      },
      <String, Object?>{
        'sourceSignature': golden['sourceSignature'],
        'edgeSignature': golden['edgeSignature'],
        'authoringPolygonSignature': golden['authoringPolygonSignature'],
        'placementSignature': golden['placementSignature'],
        'triangleSignature': golden['triangleSignature'],
      },
    );
    expect(
      compiled.placementLineage
          .map((lineage) => '${lineage.placementKey}:${lineage.shapeId}')
          .toList(growable: false),
      <String>[
        'prefab_migration_concave|100|20|0:collision_001',
        'prefab_migration_disconnected|220|40|0:collision_001',
        'prefab_migration_disconnected|220|40|0:collision_002',
        'prefab_migration_rectangle|30|30|0:collision_001',
      ],
    );
  });

  test('fresh parses reproduce records and signatures', () {
    final first = _compileFixture();
    final second = _compileFixture();

    expect(
      second.geometry.canonicalSourceRecords(),
      first.geometry.canonicalSourceRecords(),
    );
    expect(
      second.geometry.canonicalEdgeRecords(),
      first.geometry.canonicalEdgeRecords(),
    );
    expect(second.placementRecords(), first.placementRecords());
    expect(second.triangleRecords(), first.triangleRecords());
    expect(second.authoringPolygonRecords(), first.authoringPolygonRecords());
  });

  test(
    'source-text boundary preserves success and normalizes parse errors',
    () {
      final direct = _compileFixture();
      final wrapped = compilePolygonTerrainSourceText(
        prefabSource: _fixture('prefab_defs.json'),
        prefabSourcePath: 'prefab_defs.json',
        chunkSource: _fixture('chunk.json'),
        chunkSourcePath: _chunkSourcePath,
      );

      expect(wrapped.issues, isEmpty);
      expect(wrapped.compiled, isNotNull);
      expect(
        wrapped.compiled!.geometry.canonicalSourceRecords(),
        direct.geometry.canonicalSourceRecords(),
      );
      expect(
        wrapped.compiled!.geometry.canonicalEdgeRecords(),
        direct.geometry.canonicalEdgeRecords(),
      );
      expect(wrapped.compiled!.placementRecords(), direct.placementRecords());
      expect(wrapped.compiled!.triangleRecords(), direct.triangleRecords());
      expect(
        wrapped.compiled!.authoringPolygonRecords(),
        direct.authoringPolygonRecords(),
      );

      final invalid = compilePolygonTerrainSourceText(
        prefabSource: '{',
        prefabSourcePath: 'prefab_defs.json',
        chunkSource: _mutated(_json('chunk.json'), (root) {
          _firstCollisionShape(root)['collisionMode'] = 'ghost';
        }),
        chunkSourcePath: _chunkSourcePath,
      );
      expect(invalid.compiled, isNull);
      expect(
        invalid.issues
            .map(
              (issue) => (
                issue.severity,
                issue.code,
                issue.sourcePath,
                issue.ownerKey,
                issue.placementKey,
                issue.shapeId,
                issue.elementIndex,
              ),
            )
            .toList(growable: false),
        <
          (
            TerrainAuthoringIssueSeverity,
            String,
            String,
            String,
            String?,
            String?,
            int?,
          )
        >[
          (
            TerrainAuthoringIssueSeverity.error,
            'chunk_source_invalid',
            _chunkSourcePath,
            _chunkSourcePath,
            null,
            null,
            null,
          ),
          (
            TerrainAuthoringIssueSeverity.error,
            'prefab_source_invalid',
            'prefab_defs.json',
            'prefab_defs.json',
            null,
            null,
            null,
          ),
        ],
      );
      expect(
        invalid.issues.first.message,
        contains('collisionMode must be one of oneWay, solid'),
      );
      expect(invalid.issues.last.message, contains('is malformed JSON'));
    },
  );

  test('compiled product signatures ignore caller collection order', () {
    final compiled = _compileFixture();
    final permuted = PolygonTerrainCompiledChunk(
      chunk: compiled.chunk,
      geometry: compiled.geometry,
      authoringPolygons: compiled.authoringPolygons.reversed,
      placementLineage: compiled.placementLineage.reversed,
      triangles: compiled.triangles.reversed,
    );

    expect(
      permuted.authoringPolygonRecords(),
      compiled.authoringPolygonRecords(),
    );
    expect(permuted.placementRecords(), compiled.placementRecords());
    expect(permuted.triangleRecords(), compiled.triangleRecords());
    expect(
      permuted.authoringPolygonSignature(),
      compiled.authoringPolygonSignature(),
    );
    expect(permuted.placementSignature(), compiled.placementSignature());
    expect(permuted.triangleSignature(), compiled.triangleSignature());
  });

  test('compiled product rejects duplicate derived identities', () {
    final compiled = _compileFixture();
    expect(
      () => PolygonTerrainCompiledChunk(
        chunk: compiled.chunk,
        geometry: compiled.geometry,
        authoringPolygons: compiled.authoringPolygons,
        placementLineage: <PolygonTerrainPlacementLineage>[
          compiled.placementLineage.single,
          compiled.placementLineage.single,
        ],
        triangles: compiled.triangles,
      ),
      throwsArgumentError,
    );
    expect(
      () => PolygonTerrainCompiledChunk(
        chunk: compiled.chunk,
        geometry: compiled.geometry,
        authoringPolygons: compiled.authoringPolygons,
        placementLineage: compiled.placementLineage,
        triangles: <PolygonTerrainTriangle>[
          compiled.triangles.first,
          compiled.triangles.first,
        ],
      ),
      throwsArgumentError,
    );
  });

  test('source identity is host-separator invariant and traversal-safe', () {
    final forward = _compileFixture();
    final windows = _compileFixture(
      sourcePath: r'chunks\forest\fixture_chunk.json',
    );

    expect(
      windows.geometry.canonicalSourceRecords(),
      forward.geometry.canonicalSourceRecords(),
    );
    expect(
      windows.geometry.canonicalEdgeRecords(),
      forward.geometry.canonicalEdgeRecords(),
    );
    expect(
      windows.geometry.sourceSignature(),
      forward.geometry.sourceSignature(),
    );
    expect(windows.geometry.edgeSignature(), forward.geometry.edgeSignature());

    for (final invalid in const <String>[
      '',
      '/chunks/forest/chunk.json',
      'chunks//forest/chunk.json',
      'chunks/../forest/chunk.json',
      r'C:\chunks\forest\chunk.json',
    ]) {
      expect(
        () => compilePolygonTerrainChunk(
          chunk: forward.chunk,
          prefabSources: PolygonTerrainPrefabSourceSet(
            const <PolygonTerrainPrefabSource>[],
          ),
          sourcePath: invalid,
        ),
        throwsArgumentError,
        reason: invalid,
      );
    }
  });

  test('every placement-lineage field participates in its signature', () {
    final compiled = _compileFixture();
    final baselineRecord = compiled.placementLineage.single;
    final baseline = compiled.placementSignature();
    final mutations = <PolygonTerrainPlacementLineage>[
      _lineage(baselineRecord, chunkKey: 'other_chunk'),
      _lineage(baselineRecord, placementKey: 'other|0|0|0'),
      _lineage(baselineRecord, prefabKey: 'prefab_other'),
      _lineage(baselineRecord, prefabId: 'other'),
      _lineage(baselineRecord, prefabRevision: 4),
      _lineage(baselineRecord, shapeId: 'other_shape'),
      _lineage(baselineRecord, placementX: 61),
      _lineage(baselineRecord, placementY: 21),
      _lineage(baselineRecord, scaleTenths: 6),
      _lineage(baselineRecord, flipX: !baselineRecord.flipX),
      _lineage(baselineRecord, flipY: !baselineRecord.flipY),
    ];

    for (final mutation in mutations) {
      expect(_placementSignatureWith(compiled, mutation), isNot(baseline));
    }
  });

  test('every triangle identity/index field participates in its signature', () {
    final compiled = _compileFixture();
    final baselineRecord = compiled.triangles.first;
    final baseline = _triangleSignatureWith(compiled, baselineRecord);
    final mutations = <PolygonTerrainTriangle>[
      _triangle(baselineRecord, chunkKey: 'other_chunk'),
      _triangle(
        baselineRecord,
        placementKey: baselineRecord.placementKey == null ? 'placed' : null,
        replacePlacementKey: true,
      ),
      _triangle(baselineRecord, shapeId: 'other_shape'),
      _triangle(baselineRecord, first: baselineRecord.first + 1),
      _triangle(baselineRecord, second: baselineRecord.second + 1),
      _triangle(baselineRecord, third: baselineRecord.third + 1),
    ];

    for (final mutation in mutations) {
      expect(_triangleSignatureWith(compiled, mutation), isNot(baseline));
    }
  });

  test('strict parsers reject legacy, unknown, and off-grid source', () {
    final prefab = _json('prefab_defs.json');
    final chunk = _json('chunk.json');

    expect(
      () => decodePolygonTerrainPrefabs(
        _mutated(prefab, (root) => root['schemaVersion'] = 2),
      ),
      throwsA(_formatMessage(contains('must be exactly 3'))),
    );
    expect(
      () => decodePolygonTerrainChunk(
        _mutated(chunk, (root) => root['groundProfile'] = <String, Object?>{}),
      ),
      throwsA(_formatMessage(contains('unknown field groundProfile'))),
    );
    for (final invalidScale in <Object>[0.2, 0.35, 3.1]) {
      expect(
        () => decodePolygonTerrainChunk(
          _mutated(chunk, (root) {
            final placement =
                (root['prefabs']! as List<Object?>).first!
                    as Map<String, Object?>;
            placement['scale'] = invalidScale;
          }),
        ),
        throwsA(_formatMessage(contains('0.3-3.0 scale in 0.1 steps'))),
        reason: '$invalidScale',
      );
    }
    expect(
      () => decodePolygonTerrainChunk(
        _mutated(chunk, (root) {
          final shape =
              (root['collisionShapes']! as List<Object?>).first!
                  as Map<String, Object?>;
          final vertex =
              (shape['vertices']! as List<Object?>).first!
                  as Map<String, Object?>;
          vertex['x'] = 0.25;
        }),
      ),
      throwsA(_formatMessage(contains('divisible exactly by 0.5'))),
    );
  });

  test('strict chunk parser rejects the structural diagnostic matrix', () {
    void expectChunkFailure(
      void Function(Map<String, Object?> root) mutate,
      String message,
    ) {
      expect(
        () => decodePolygonTerrainChunk(
          _mutated(_json('chunk.json'), mutate),
          sourcePath: _chunkSourcePath,
        ),
        throwsA(_formatMessage(contains(message))),
      );
    }

    expect(
      () => decodePolygonTerrainChunk('{', sourcePath: _chunkSourcePath),
      throwsA(_formatMessage(contains('$_chunkSourcePath is malformed JSON:'))),
    );
    expectChunkFailure(
      (root) => root.remove('schemaVersion'),
      '$_chunkSourcePath is missing field schemaVersion.',
    );
    expectChunkFailure((root) {
      _firstCollisionShape(root).remove('collisionMode');
    }, '$_chunkSourcePath.collisionShapes[0] is missing field collisionMode.');
    expectChunkFailure(
      (root) {
        _firstCollisionShape(root)['collisionMode'] = 'ghost';
      },
      '$_chunkSourcePath.collisionShapes[0].collisionMode must be one of oneWay, solid.',
    );
    expectChunkFailure(
      (root) {
        _firstVertex(root)['x'] = 0.25;
      },
      '$_chunkSourcePath.collisionShapes[0].vertices[0].x must be divisible exactly by 0.5.',
    );
    expectChunkFailure((root) {
      _firstCollisionShape(root).remove('shapeId');
    }, '$_chunkSourcePath.collisionShapes[0] is missing field shapeId.');
    expectChunkFailure(
      (root) {
        _firstCollisionShape(root)['shapeId'] = 'Ground';
      },
      '$_chunkSourcePath.collisionShapes[0].shapeId must match ^[a-z][a-z0-9_]*\$.',
    );
    expectChunkFailure(
      (root) {
        final shape = _firstCollisionShape(root);
        root['collisionShapes'] = <Object?>[
          shape,
          jsonDecode(jsonEncode(shape)) as Map<String, Object?>,
        ];
      },
      '$_chunkSourcePath.collisionShapes must be strictly ordered with no duplicates.',
    );
  });

  test('Core topology failures retain exact staged diagnostic lineage', () {
    PolygonTerrainCompilationResult compileShapes(
      List<Map<String, Object?>> shapes,
    ) {
      final chunk = decodePolygonTerrainChunk(
        _mutated(_json('chunk.json'), (root) {
          root['prefabs'] = <Object?>[];
          root['collisionShapes'] = shapes;
        }),
        sourcePath: _chunkSourcePath,
      );
      return compilePolygonTerrainChunk(
        chunk: chunk,
        prefabSources: PolygonTerrainPrefabSourceSet(
          const <PolygonTerrainPrefabSource>[],
        ),
        sourcePath: _chunkSourcePath,
      );
    }

    final cases =
        <String, ({List<(num, num)> vertices, List<(String, int)> issues})>{
          'collinear': (
            vertices: const <(num, num)>[
              (0, 0),
              (5, 0),
              (10, 0),
              (10, 10),
              (0, 10),
            ],
            issues: const <(String, int)>[('collinear_middle_vertex', 1)],
          ),
          'consecutive_duplicate': (
            vertices: const <(num, num)>[(0, 0), (5, 0), (5, 0), (0, 5)],
            issues: const <(String, int)>[
              ('self_intersection', 0),
              ('collinear_middle_vertex', 1),
              ('minimum_edge_length', 1),
              ('collinear_middle_vertex', 2),
              ('consecutive_duplicate', 2),
            ],
          ),
          'minimum_area': (
            vertices: const <(num, num)>[(0, 0), (1, 0), (0, 1)],
            issues: const <(String, int)>[('minimum_area', 0)],
          ),
          'noncanonical_start': (
            vertices: const <(num, num)>[(10, 0), (10, 10), (0, 10), (0, 0)],
            issues: const <(String, int)>[('noncanonical_start', 3)],
          ),
          'noncanonical_winding': (
            vertices: const <(num, num)>[(0, 10), (10, 10), (10, 0), (0, 0)],
            issues: const <(String, int)>[('noncanonical_winding', 0)],
          ),
          'repeated_closing': (
            vertices: const <(num, num)>[(0, 0), (5, 0), (0, 5), (0, 0)],
            issues: const <(String, int)>[
              ('collinear_middle_vertex', 0),
              ('self_intersection', 0),
              ('collinear_middle_vertex', 3),
              ('minimum_edge_length', 3),
              ('repeated_closing_vertex', 3),
            ],
          ),
          'self_intersection': (
            vertices: const <(num, num)>[(0, 0), (5, 5), (0, 5), (4, 0)],
            issues: const <(String, int)>[('self_intersection', 0)],
          ),
          'short_edge': (
            vertices: const <(num, num)>[(0, 0), (0.5, 0), (2, 5), (0, 5)],
            issues: const <(String, int)>[('minimum_edge_length', 0)],
          ),
          'too_few_vertices': (
            vertices: const <(num, num)>[(0, 0), (5, 0)],
            issues: const <(String, int)>[('too_few_vertices', 0)],
          ),
        };

    for (final entry in cases.entries) {
      final result = compileShapes(<Map<String, Object?>>[
        _shapeJson(entry.key, entry.value.vertices),
      ]);
      expect(result.compiled, isNull, reason: entry.key);
      expect(
        result.issues
            .map((issue) => (issue.code, issue.elementIndex))
            .toList(growable: false),
        entry.value.issues,
        reason: entry.key,
      );
      expect(
        result.issues.every(
          (issue) =>
              issue.sourcePath == '$_chunkSourcePath#direct=${entry.key}' &&
              issue.placementKey == null &&
              issue.shapeId == entry.key,
        ),
        isTrue,
        reason: entry.key,
      );
    }

    final overlap = compileShapes(<Map<String, Object?>>[
      _shapeJson('overlap_left', const <(num, num)>[
        (0, 0),
        (10, 0),
        (10, 10),
        (0, 10),
      ]),
      _shapeJson('overlap_right', const <(num, num)>[
        (5, 0),
        (15, 0),
        (15, 10),
        (5, 10),
      ]),
    ]);
    expect(overlap.compiled, isNull);
    expect(
      overlap.issues
          .map(
            (issue) => (
              issue.code,
              issue.sourcePath,
              issue.placementKey,
              issue.shapeId,
              issue.elementIndex,
            ),
          )
          .toList(growable: false),
      <(String, String, String?, String?, int?)>[
        (
          'polygon_area_overlap',
          '$_chunkSourcePath#direct=overlap_right',
          null,
          'overlap_right',
          0,
        ),
      ],
    );
  });

  test('post-transform degeneracy retains exact placement lineage', () {
    final prefabJson = _json('prefab_defs.json');
    final prefabs = decodePolygonTerrainPrefabs(
      _mutated(prefabJson, (root) {
        final prefab =
            (root['prefabs']! as List<Object?>).single! as Map<String, Object?>;
        final shape =
            (prefab['collisionShapes']! as List<Object?>).single!
                as Map<String, Object?>;
        shape['vertices'] = <Object?>[
          <String, Object?>{'x': 0, 'y': 0},
          <String, Object?>{'x': 1, 'y': 0},
          <String, Object?>{'x': 1, 'y': 1},
          <String, Object?>{'x': 0, 'y': 1},
        ];
      }),
      sourcePath: 'prefab_defs.json',
    );
    final chunk = decodePolygonTerrainChunk(
      _mutated(_json('chunk.json'), (root) {
        final placement =
            (root['prefabs']! as List<Object?>).single! as Map<String, Object?>;
        placement['scale'] = 0.3;
        root['collisionShapes'] = <Object?>[];
      }),
      sourcePath: _chunkSourcePath,
    );

    final result = compilePolygonTerrainChunk(
      chunk: chunk,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(
      result.issues
          .map(
            (issue) => (
              issue.code,
              issue.sourcePath,
              issue.placementKey,
              issue.shapeId,
              issue.elementIndex,
            ),
          )
          .toList(growable: false),
      <(String, String, String?, String?, int?)>[
        for (var edgeIndex = 0; edgeIndex < 4; edgeIndex += 1)
          (
            'transform_minimum_edge_length',
            '$_chunkSourcePath#placement=prefab_ramp|60|20|0'
                '#prefab=prefab_ramp#shape=collision_001',
            'prefab_ramp|60|20|0',
            'collision_001',
            edgeIndex,
          ),
      ],
    );
  });

  test('unresolved placement fails without fabricated geometry', () {
    final chunk = decodePolygonTerrainChunk(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );
    final result = compilePolygonTerrainChunk(
      chunk: chunk,
      prefabSources: PolygonTerrainPrefabSourceSet(
        const <PolygonTerrainPrefabSource>[],
      ),
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(result.issues, hasLength(1));
    expect(result.issues.single.code, 'unknown_prefab_reference');
    expect(result.issues.single.placementKey, 'prefab_ramp|60|20|0');
  });

  test('ambiguous prefab reference is stable across catalog order', () {
    final prefabJson = _json('prefab_defs.json');
    final prefabs = decodePolygonTerrainPrefabs(
      _mutated(prefabJson, (root) {
        final source =
            (root['prefabs']! as List<Object?>).single! as Map<String, Object?>;
        final alias = jsonDecode(jsonEncode(source)) as Map<String, Object?>;
        alias['prefabKey'] = 'prefab_second';
        alias['id'] = 'prefab_ramp';
        root['prefabs'] = <Object?>[alias, source];
      }),
    );
    final chunk = decodePolygonTerrainChunk(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );

    List<(String, String, String?, String?)> compileWith(
      Iterable<PolygonTerrainPrefabSource> catalog,
    ) {
      final result = compilePolygonTerrainChunk(
        chunk: chunk,
        prefabSources: PolygonTerrainPrefabSourceSet(catalog),
        sourcePath: _chunkSourcePath,
      );
      expect(result.compiled, isNull);
      return result.issues
          .map(
            (issue) => (
              issue.code,
              issue.sourcePath,
              issue.placementKey,
              issue.shapeId,
            ),
          )
          .toList(growable: false);
    }

    final forward = compileWith(prefabs.prefabs);
    expect(compileWith(prefabs.prefabs.reversed), forward);
    expect(forward, <(String, String, String?, String?)>[
      (
        'ambiguous_prefab_reference',
        '$_chunkSourcePath#placement=prefab_ramp|60|20|0',
        'prefab_ramp|60|20|0',
        null,
      ),
    ]);
  });

  test('Core source-range rejection is a stable generation issue', () {
    final chunkJson = _json('chunk.json');
    final oversized = decodePolygonTerrainChunk(
      _mutated(chunkJson, (root) {
        final shape =
            (root['collisionShapes']! as List<Object?>).first!
                as Map<String, Object?>;
        final vertex =
            (shape['vertices']! as List<Object?>).first!
                as Map<String, Object?>;
        vertex['x'] = 1 << 40;
      }),
      sourcePath: _chunkSourcePath,
    );
    final prefabs = decodePolygonTerrainPrefabs(_fixture('prefab_defs.json'));

    final result = compilePolygonTerrainChunk(
      chunk: oversized,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    final issue = result.issues.singleWhere(
      (candidate) => candidate.code == 'chunk_collision_source_value_invalid',
    );
    expect(issue.shapeId, 'ground');
    expect(issue.sourcePath, '$_chunkSourcePath#direct=ground');
  });

  test('prefab source-range rejection retains placement lineage', () {
    final prefabJson = _json('prefab_defs.json');
    final oversized = decodePolygonTerrainPrefabs(
      _mutated(prefabJson, (root) {
        final prefab =
            (root['prefabs']! as List<Object?>).single! as Map<String, Object?>;
        final shape =
            (prefab['collisionShapes']! as List<Object?>).single!
                as Map<String, Object?>;
        final vertex =
            (shape['vertices']! as List<Object?>).first!
                as Map<String, Object?>;
        vertex['x'] = 1 << 40;
      }),
      sourcePath: 'prefab_defs.json',
    );
    final chunk = decodePolygonTerrainChunk(
      _fixture('chunk.json'),
      sourcePath: _chunkSourcePath,
    );

    final result = compilePolygonTerrainChunk(
      chunk: chunk,
      prefabSources: oversized,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    final issue = result.issues.singleWhere(
      (candidate) => candidate.code == 'prefab_collision_source_value_invalid',
    );
    expect(issue.placementKey, 'prefab_ramp|60|20|0');
    expect(issue.shapeId, 'collision_001');
    expect(
      issue.sourcePath,
      '$_chunkSourcePath#placement=prefab_ramp|60|20|0'
      '#prefab=prefab_ramp#shape=collision_001',
    );
  });

  test('direct and expanded bounds issues are exact and sorted', () {
    final chunkJson = _json('chunk.json');
    final outOfBounds = decodePolygonTerrainChunk(
      _mutated(chunkJson, (root) {
        final placement =
            (root['prefabs']! as List<Object?>).single! as Map<String, Object?>;
        placement['x'] = 110;
        final platform =
            (root['collisionShapes']! as List<Object?>)[1]!
                as Map<String, Object?>;
        final vertices = platform['vertices']! as List<Object?>;
        for (final index in <int>[1, 2]) {
          (vertices[index]! as Map<String, Object?>)['x'] = 101;
        }
      }),
      sourcePath: _chunkSourcePath,
    );
    final prefabs = decodePolygonTerrainPrefabs(_fixture('prefab_defs.json'));

    final result = compilePolygonTerrainChunk(
      chunk: outOfBounds,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(
      result.issues
          .map(
            (issue) => (
              issue.severity,
              issue.code,
              issue.ownerKey,
              issue.placementKey,
              issue.shapeId,
              issue.elementIndex,
            ),
          )
          .toList(growable: false),
      <(TerrainAuthoringIssueSeverity, String, String, String?, String?, int?)>[
        (
          TerrainAuthoringIssueSeverity.error,
          'chunk_collision_shape_out_of_bounds',
          'fixture_chunk',
          null,
          'platform',
          1,
        ),
        (
          TerrainAuthoringIssueSeverity.error,
          'chunk_collision_shape_out_of_bounds',
          'fixture_chunk',
          null,
          'platform',
          2,
        ),
        (
          TerrainAuthoringIssueSeverity.error,
          'expanded_prefab_vertex_out_of_bounds',
          'prefab_ramp',
          'prefab_ramp|110|20|0',
          'collision_001',
          0,
        ),
        (
          TerrainAuthoringIssueSeverity.error,
          'expanded_prefab_vertex_out_of_bounds',
          'prefab_ramp',
          'prefab_ramp|110|20|0',
          'collision_001',
          1,
        ),
        (
          TerrainAuthoringIssueSeverity.error,
          'expanded_prefab_vertex_out_of_bounds',
          'prefab_ramp',
          'prefab_ramp|110|20|0',
          'collision_001',
          2,
        ),
        (
          TerrainAuthoringIssueSeverity.error,
          'expanded_prefab_vertex_out_of_bounds',
          'prefab_ramp',
          'prefab_ramp|110|20|0',
          'collision_001',
          3,
        ),
      ],
    );
  });

  test('noncanonical source is rejected instead of normalized silently', () {
    final chunkJson = _json('chunk.json');
    final noncanonical = decodePolygonTerrainChunk(
      _mutated(chunkJson, (root) {
        final shape =
            (root['collisionShapes']! as List<Object?>).first!
                as Map<String, Object?>;
        final vertices = shape['vertices']! as List<Object?>;
        shape['vertices'] = vertices.reversed.toList(growable: false);
      }),
      sourcePath: _chunkSourcePath,
    );
    final prefabs = decodePolygonTerrainPrefabs(_fixture('prefab_defs.json'));

    final result = compilePolygonTerrainChunk(
      chunk: noncanonical,
      prefabSources: prefabs,
      sourcePath: _chunkSourcePath,
    );

    expect(result.compiled, isNull);
    expect(
      result.issues.map((issue) => issue.code),
      contains('noncanonical_winding'),
    );
  });
}

PolygonTerrainCompiledChunk _compileFixture({
  String sourcePath = _chunkSourcePath,
}) {
  final prefabs = decodePolygonTerrainPrefabs(
    _fixture('prefab_defs.json'),
    sourcePath: 'prefab_defs.json',
  );
  final chunk = decodePolygonTerrainChunk(
    _fixture('chunk.json'),
    sourcePath: _chunkSourcePath,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: sourcePath,
  );
  expect(result.issues, isEmpty);
  expect(result.compiled, isNotNull);
  return result.compiled!;
}

PolygonTerrainCompiledChunk _compileTransformFixture() {
  final prefabs = decodePolygonTerrainPrefabs(
    _fixture('transform_prefab_defs.json'),
    sourcePath: 'transform_prefab_defs.json',
  );
  final chunk = decodePolygonTerrainChunk(
    _fixture('transform_chunk.json'),
    sourcePath: _transformChunkSourcePath,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: _transformChunkSourcePath,
  );
  expect(result.issues, isEmpty);
  expect(result.compiled, isNotNull);
  return result.compiled!;
}

PolygonTerrainCompiledChunk _compileMigrationFixture() {
  final prefabs = decodePolygonTerrainPrefabs(
    _fixture('migration_prefab_defs.json'),
    sourcePath: 'migration_prefab_defs.json',
  );
  final chunk = decodePolygonTerrainChunk(
    _fixture('migration_chunk.json'),
    sourcePath: _migrationChunkSourcePath,
  );
  final result = compilePolygonTerrainChunk(
    chunk: chunk,
    prefabSources: prefabs,
    sourcePath: _migrationChunkSourcePath,
  );
  expect(result.issues, isEmpty);
  expect(result.compiled, isNotNull);
  return result.compiled!;
}

Map<String, Object?> _golden([String name = 'golden.json']) =>
    jsonDecode(_fixture(name)) as Map<String, Object?>;

String _fixture(String name) =>
    File('$_fixtureDirectory/$name').readAsStringSync();

Map<String, Object?> _json(String name) =>
    jsonDecode(_fixture(name)) as Map<String, Object?>;

String _mutated(
  Map<String, Object?> source,
  void Function(Map<String, Object?> root) mutate,
) {
  final copied = jsonDecode(jsonEncode(source)) as Map<String, Object?>;
  mutate(copied);
  return jsonEncode(copied);
}

Matcher _formatMessage(Matcher message) =>
    isA<FormatException>().having((error) => error.message, 'message', message);

Map<String, Object?> _firstCollisionShape(Map<String, Object?> root) =>
    (root['collisionShapes']! as List<Object?>).first! as Map<String, Object?>;

Map<String, Object?> _firstVertex(Map<String, Object?> root) =>
    (_firstCollisionShape(root)['vertices']! as List<Object?>).first!
        as Map<String, Object?>;

Map<String, Object?> _shapeJson(String shapeId, List<(num, num)> vertices) =>
    <String, Object?>{
      'shapeId': shapeId,
      'collisionMode': 'solid',
      'vertices': <Object?>[
        for (final vertex in vertices)
          <String, Object?>{'x': vertex.$1, 'y': vertex.$2},
      ],
    };

PolygonTerrainPlacementLineage _lineage(
  PolygonTerrainPlacementLineage source, {
  String? chunkKey,
  String? placementKey,
  String? prefabKey,
  String? prefabId,
  int? prefabRevision,
  String? shapeId,
  int? placementX,
  int? placementY,
  int? scaleTenths,
  bool? flipX,
  bool? flipY,
}) => PolygonTerrainPlacementLineage(
  chunkKey: chunkKey ?? source.chunkKey,
  placementKey: placementKey ?? source.placementKey,
  prefabKey: prefabKey ?? source.prefabKey,
  prefabId: prefabId ?? source.prefabId,
  prefabRevision: prefabRevision ?? source.prefabRevision,
  shapeId: shapeId ?? source.shapeId,
  placementX: placementX ?? source.placementX,
  placementY: placementY ?? source.placementY,
  scaleTenths: scaleTenths ?? source.scaleTenths,
  flipX: flipX ?? source.flipX,
  flipY: flipY ?? source.flipY,
);

PolygonTerrainTriangle _triangle(
  PolygonTerrainTriangle source, {
  String? chunkKey,
  String? placementKey,
  bool replacePlacementKey = false,
  String? shapeId,
  int? first,
  int? second,
  int? third,
}) => PolygonTerrainTriangle(
  chunkKey: chunkKey ?? source.chunkKey,
  placementKey: replacePlacementKey ? placementKey : source.placementKey,
  shapeId: shapeId ?? source.shapeId,
  first: first ?? source.first,
  second: second ?? source.second,
  third: third ?? source.third,
);

String _placementSignatureWith(
  PolygonTerrainCompiledChunk source,
  PolygonTerrainPlacementLineage lineage,
) => PolygonTerrainCompiledChunk(
  chunk: source.chunk,
  geometry: source.geometry,
  authoringPolygons: source.authoringPolygons,
  placementLineage: <PolygonTerrainPlacementLineage>[lineage],
  triangles: source.triangles,
).placementSignature();

String _triangleSignatureWith(
  PolygonTerrainCompiledChunk source,
  PolygonTerrainTriangle triangle,
) => PolygonTerrainCompiledChunk(
  chunk: source.chunk,
  geometry: source.geometry,
  authoringPolygons: source.authoringPolygons,
  placementLineage: source.placementLineage,
  triangles: <PolygonTerrainTriangle>[triangle],
).triangleSignature();
