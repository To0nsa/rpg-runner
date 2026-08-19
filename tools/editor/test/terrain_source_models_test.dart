import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  group('TerrainSourceVertexDef', () {
    test('parses and emits exact integer and half-pixel coordinates', () {
      final vertex = TerrainSourceVertexDef.fromJson(<String, Object?>{
        'x': -12.5,
        'y': 8,
      });

      expect(vertex.xHalfPixels, -25);
      expect(vertex.yHalfPixels, 16);
      expect(vertex.toJson(), <String, Object>{'x': -12.5, 'y': 8});
      expect(jsonEncode(vertex.toJson()), r'{"x":-12.5,"y":8}');
    });

    test('canonical JSON never emits negative zero or exponent notation', () {
      const zero = TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0);
      const nearExactLimit = TerrainSourceVertexDef(
        xHalfPixels: (1 << 52) - 1,
        yHalfPixels: -((1 << 52) - 1),
      );

      final encoded = jsonEncode(<Object>[
        zero.toJson(),
        nearExactLimit.toJson(),
      ]);

      expect(encoded, isNot(contains('-0')));
      expect(encoded.toLowerCase(), isNot(contains('e')));
      expect(encoded, contains('.5'));
    });

    test('rejects malformed, non-finite, and off-grid values', () {
      for (final raw in <Object?>[0.25, double.nan, double.infinity, '1.5']) {
        expect(
          () => TerrainSourceVertexDef.fromJson(<String, Object?>{
            'x': raw,
            'y': 0,
          }),
          throwsFormatException,
        );
      }
    });

    test('uses exact integer equality', () {
      expect(
        const TerrainSourceVertexDef(xHalfPixels: 3, yHalfPixels: -4),
        const TerrainSourceVertexDef(xHalfPixels: 3, yHalfPixels: -4),
      );
      expect(
        const TerrainSourceVertexDef(xHalfPixels: 3, yHalfPixels: -4),
        isNot(const TerrainSourceVertexDef(xHalfPixels: 2, yHalfPixels: -4)),
      );
    });
  });

  group('TerrainSourceShapeDef', () {
    test('round-trips collision mode and optional metadata exactly', () {
      final shape = TerrainSourceShapeDef.fromJson(<String, Object?>{
        'shapeId': 'ground_001',
        'collisionMode': 'oneWay',
        'surfaceKind': 'grass',
        'materialKey': 'forest_ground',
        'vertices': <Object?>[
          <String, Object?>{'x': 0, 'y': 0},
          <String, Object?>{'x': 4.5, 'y': 0},
          <String, Object?>{'x': 2, 'y': 3.5},
        ],
      });

      expect(shape.collisionMode, TerrainSourceCollisionMode.oneWay);
      expect(shape.surfaceKind, 'grass');
      expect(shape.materialKey, 'forest_ground');
      expect(shape.vertices.map((vertex) => vertex.xHalfPixels), <int>[
        0,
        9,
        4,
      ]);
      expect(shape.toJson()['collisionMode'], 'oneWay');
    });

    test('round-trips render-only terrain as collisionMode none', () {
      final shape = TerrainSourceShapeDef.fromJson(<String, Object?>{
        'shapeId': 'dark_pit',
        'collisionMode': 'none',
        'materialKey': 'dark_pit',
        'vertices': <Object?>[
          <String, Object?>{'x': 0, 'y': 0},
          <String, Object?>{'x': 8, 'y': 0},
          <String, Object?>{'x': 8, 'y': 4},
        ],
      });

      expect(shape.collisionMode, TerrainSourceCollisionMode.none);
      expect(shape.toJson()['collisionMode'], 'none');
      expect(shape.materialKey, 'dark_pit');
    });

    test('rejects unstable IDs, collision modes, and empty metadata', () {
      expect(
        () => TerrainSourceShapeDef(
          shapeId: 'Ground-1',
          vertices: const <TerrainSourceVertexDef>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => TerrainSourceShapeDef.fromJson(<String, Object?>{
          'shapeId': 'ground_001',
          'collisionMode': 'sensor',
          'vertices': <Object?>[],
        }),
        throwsFormatException,
      );
      expect(
        () => TerrainSourceShapeDef.fromJson(<String, Object?>{
          'shapeId': 'ground_001',
          'collisionMode': 'solid',
          'surfaceKind': '  ',
          'vertices': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test('equality includes ordered vertices and metadata', () {
      final a = _shape('ground_001', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 4, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 4, yHalfPixels: 4),
      ]);
      final same = _shape('ground_001', a.vertices);
      final reordered = _shape('ground_001', a.vertices.reversed);

      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(reordered));
    });
  });

  group('owner shape lists', () {
    test('parses decoded JSON collections with half-pixel values', () {
      final decoded = jsonDecode('''
[
  {
    "shapeId": "ground_001",
    "collisionMode": "solid",
    "vertices": [{"x": -0.5, "y": 2}]
  }
]
''');

      final shapes = terrainSourceShapesFromJson(decoded);

      expect(shapes, hasLength(1));
      expect(shapes.single.vertices.single.xHalfPixels, -1);
      expect(shapes.single.vertices.single.yHalfPixels, 4);
    });

    test('sort by shape ID without changing vertex order', () {
      final shapeB = _shape('shape_b', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 2),
        TerrainSourceVertexDef(xHalfPixels: 4, yHalfPixels: 6),
      ]);
      final shapeA = _shape('shape_a', const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 1, yHalfPixels: 3),
        TerrainSourceVertexDef(xHalfPixels: 5, yHalfPixels: 7),
      ]);

      final canonical = canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
        shapeB,
        shapeA,
      ]);
      final encoded = terrainSourceShapesToJson(<TerrainSourceShapeDef>[
        shapeB,
        shapeA,
      ]);

      expect(canonical.map((shape) => shape.shapeId), <String>[
        'shape_a',
        'shape_b',
      ]);
      expect(canonical.first.vertices, shapeA.vertices);
      expect(encoded.map((shape) => shape['shapeId']), <String>[
        'shape_a',
        'shape_b',
      ]);
      expect(() => canonical.add(shapeA), throwsUnsupportedError);
    });

    test('reject duplicate IDs when parsing or serializing an owner', () {
      final duplicate = _shape('shape_a', const <TerrainSourceVertexDef>[]);

      expect(
        () => canonicalTerrainSourceShapes(<TerrainSourceShapeDef>[
          duplicate,
          duplicate,
        ]),
        throwsArgumentError,
      );
      expect(
        () => terrainSourceShapesFromJson(<Object?>[
          duplicate.toJson(),
          duplicate.toJson(),
        ]),
        throwsFormatException,
      );
    });
  });
}

TerrainSourceShapeDef _shape(
  String shapeId,
  Iterable<TerrainSourceVertexDef> vertices,
) => TerrainSourceShapeDef(shapeId: shapeId, vertices: vertices);
