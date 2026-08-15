import 'terrain_source_models.dart';

/// Exact axis-aligned rectangle recognized from a four-vertex source polygon.
///
/// Rectangles remain stored as ordinary polygons. This derived view lets editor
/// controls preserve rectangular geometry when changing its dimensions.
final class TerrainAxisAlignedRectangle {
  const TerrainAxisAlignedRectangle._({
    required this.xHalfPixels,
    required this.yHalfPixels,
    required this.widthHalfPixels,
    required this.heightHalfPixels,
  });

  /// Returns a rectangle when [shape] has each corner of one positive-area
  /// axis-aligned bounds exactly once; otherwise returns `null`.
  static TerrainAxisAlignedRectangle? tryFromShape(
    TerrainSourceShapeDef shape,
  ) {
    if (shape.vertices.length != 4) return null;
    final xCoordinates =
        shape.vertices.map((vertex) => vertex.xHalfPixels).toSet().toList()
          ..sort();
    final yCoordinates =
        shape.vertices.map((vertex) => vertex.yHalfPixels).toSet().toList()
          ..sort();
    if (xCoordinates.length != 2 || yCoordinates.length != 2) return null;

    final x = xCoordinates.first;
    final y = yCoordinates.first;
    final width = xCoordinates.last - x;
    final height = yCoordinates.last - y;
    final rectangle = tryCreate(
      xHalfPixels: x,
      yHalfPixels: y,
      widthHalfPixels: width,
      heightHalfPixels: height,
    );
    if (rectangle == null) return null;

    final corners = shape.vertices
        .map((vertex) => (vertex.xHalfPixels, vertex.yHalfPixels))
        .toSet();
    return rectangle._cornerPoints.every(corners.contains) ? rectangle : null;
  }

  /// Returns `null` for a zero-area or negatively sized rectangle.
  static TerrainAxisAlignedRectangle? tryCreate({
    required int xHalfPixels,
    required int yHalfPixels,
    required int widthHalfPixels,
    required int heightHalfPixels,
  }) {
    if (widthHalfPixels <= 0 || heightHalfPixels <= 0) return null;
    return TerrainAxisAlignedRectangle._(
      xHalfPixels: xHalfPixels,
      yHalfPixels: yHalfPixels,
      widthHalfPixels: widthHalfPixels,
      heightHalfPixels: heightHalfPixels,
    );
  }

  final int xHalfPixels;
  final int yHalfPixels;
  final int widthHalfPixels;
  final int heightHalfPixels;

  /// Canonical clockwise Y-down source loop for this rectangle.
  List<TerrainSourceVertexDef> get vertices => <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: xHalfPixels, yHalfPixels: yHalfPixels),
    TerrainSourceVertexDef(
      xHalfPixels: xHalfPixels + widthHalfPixels,
      yHalfPixels: yHalfPixels,
    ),
    TerrainSourceVertexDef(
      xHalfPixels: xHalfPixels + widthHalfPixels,
      yHalfPixels: yHalfPixels + heightHalfPixels,
    ),
    TerrainSourceVertexDef(
      xHalfPixels: xHalfPixels,
      yHalfPixels: yHalfPixels + heightHalfPixels,
    ),
  ];

  Iterable<(int, int)> get _cornerPoints => <(int, int)>[
    (xHalfPixels, yHalfPixels),
    (xHalfPixels + widthHalfPixels, yHalfPixels),
    (xHalfPixels + widthHalfPixels, yHalfPixels + heightHalfPixels),
    (xHalfPixels, yHalfPixels + heightHalfPixels),
  ];
}
