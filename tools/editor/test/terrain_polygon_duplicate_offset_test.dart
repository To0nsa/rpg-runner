import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_duplicate_offset.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('chooses the nearest snapped right-side position deterministically', () {
    final shape = _rectangle('ground_001', 20, 20, 100, 80);

    expect(
      findTerrainPolygonDuplicateOffset(
        selectedShape: shape,
        ownerShapes: <TerrainSourceShapeDef>[shape],
        snapStepHalfPixels: 2,
        minXHalfPixels: 0,
        minYHalfPixels: 0,
        maxXHalfPixels: 200,
        maxYHalfPixels: 100,
      ),
      const TerrainPolygonDuplicateOffset(
        deltaXHalfPixels: 82,
        deltaYHalfPixels: 0,
      ),
    );
  });

  test('rounds an odd half-pixel extent outward to the owner grid', () {
    final shape = _rectangle('collision_001', 1, 1, 6, 6);

    expect(
      findTerrainPolygonDuplicateOffset(
        selectedShape: shape,
        ownerShapes: <TerrainSourceShapeDef>[shape],
        snapStepHalfPixels: 2,
      ),
      const TerrainPolygonDuplicateOffset(
        deltaXHalfPixels: 8,
        deltaYHalfPixels: 0,
      ),
    );
  });

  test('skips occupied candidates independent of owner input order', () {
    final selected = _rectangle('ground_001', 20, 20, 60, 60);
    final right = _rectangle('ground_002', 62, 20, 102, 60);
    final first = findTerrainPolygonDuplicateOffset(
      selectedShape: selected,
      ownerShapes: <TerrainSourceShapeDef>[selected, right],
      snapStepHalfPixels: 2,
      minXHalfPixels: 0,
      minYHalfPixels: 0,
      maxXHalfPixels: 200,
      maxYHalfPixels: 100,
    );
    final reversed = findTerrainPolygonDuplicateOffset(
      selectedShape: selected,
      ownerShapes: <TerrainSourceShapeDef>[right, selected],
      snapStepHalfPixels: 2,
      minXHalfPixels: 0,
      minYHalfPixels: 0,
      maxXHalfPixels: 200,
      maxYHalfPixels: 100,
    );

    expect(first, reversed);
    expect(first, isNotNull);
    expect(first!.deltaXHalfPixels, greaterThan(42));
  });

  test('returns null when the closed owner has no conservative free slot', () {
    final selected = _rectangle('ground_001', 0, 0, 20, 20);

    expect(
      findTerrainPolygonDuplicateOffset(
        selectedShape: selected,
        ownerShapes: <TerrainSourceShapeDef>[selected],
        snapStepHalfPixels: 2,
        minXHalfPixels: 0,
        minYHalfPixels: 0,
        maxXHalfPixels: 20,
        maxYHalfPixels: 20,
      ),
      isNull,
    );
  });
}

TerrainSourceShapeDef _rectangle(
  String shapeId,
  int minX,
  int minY,
  int maxX,
  int maxY,
) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: minX, yHalfPixels: minY),
    TerrainSourceVertexDef(xHalfPixels: maxX, yHalfPixels: minY),
    TerrainSourceVertexDef(xHalfPixels: maxX, yHalfPixels: maxY),
    TerrainSourceVertexDef(xHalfPixels: minX, yHalfPixels: maxY),
  ],
);
