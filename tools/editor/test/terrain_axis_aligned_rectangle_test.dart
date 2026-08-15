import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_axis_aligned_rectangle.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test(
    'recognizes an axis-aligned four-corner polygon regardless of order',
    () {
      final rectangle = TerrainAxisAlignedRectangle.tryFromShape(
        TerrainSourceShapeDef(
          shapeId: 'solid_001',
          vertices: const <TerrainSourceVertexDef>[
            TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 60),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 60),
            TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 10),
            TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 10),
          ],
        ),
      );

      expect(rectangle, isNotNull);
      expect(rectangle!.xHalfPixels, 20);
      expect(rectangle.yHalfPixels, 10);
      expect(rectangle.widthHalfPixels, 60);
      expect(rectangle.heightHalfPixels, 50);
      expect(rectangle.vertices, const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 10),
        TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 10),
        TerrainSourceVertexDef(xHalfPixels: 80, yHalfPixels: 60),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 60),
      ]);
    },
  );

  test('does not classify a skewed quadrilateral as a rectangle', () {
    final shape = TerrainSourceShapeDef(
      shapeId: 'solid_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 30, yHalfPixels: 20),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 20),
      ],
    );

    expect(TerrainAxisAlignedRectangle.tryFromShape(shape), isNull);
    expect(
      TerrainAxisAlignedRectangle.tryCreate(
        xHalfPixels: 0,
        yHalfPixels: 0,
        widthHalfPixels: 0,
        heightHalfPixels: 20,
      ),
      isNull,
    );
  });
}
