import '../domain/strict_authoring_json.dart';
import 'terrain_source_models.dart';

/// Strict structural parser for polygon shape arrays in authored source.
///
/// This checks the representation as written and preserves vertex order.
/// Geometry acceptance and canonical winding remain Core-owned.
abstract final class StrictTerrainSourceCodec {
  static List<TerrainSourceShapeDef> decodeShapes(
    Object? raw, {
    required String sourcePath,
  }) {
    if (raw is! List<Object?>) {
      throw FormatException('$sourcePath must be an array.');
    }
    final shapes = <TerrainSourceShapeDef>[];
    for (var index = 0; index < raw.length; index += 1) {
      final shapePath = '$sourcePath[$index]';
      final json = StrictAuthoringJson.object(
        raw[index],
        sourcePath: shapePath,
      );
      StrictAuthoringJson.requireKeys(
        json,
        sourcePath: shapePath,
        allowed: const <String>{
          'shapeId',
          'collisionMode',
          'vertices',
          'surfaceKind',
          'materialKey',
        },
        required: const <String>{'shapeId', 'collisionMode', 'vertices'},
      );
      if (json.containsKey('surfaceKind')) {
        StrictAuthoringJson.nonEmptyString(
          json['surfaceKind'],
          sourcePath: '$shapePath.surfaceKind',
        );
      }
      if (json.containsKey('materialKey')) {
        StrictAuthoringJson.nonEmptyString(
          json['materialKey'],
          sourcePath: '$shapePath.materialKey',
        );
      }
      final vertices = json['vertices'];
      if (vertices is! List<Object?>) {
        throw FormatException('$shapePath.vertices must be an array.');
      }
      for (
        var vertexIndex = 0;
        vertexIndex < vertices.length;
        vertexIndex += 1
      ) {
        StrictAuthoringJson.requireKeys(
          StrictAuthoringJson.object(
            vertices[vertexIndex],
            sourcePath: '$shapePath.vertices[$vertexIndex]',
          ),
          sourcePath: '$shapePath.vertices[$vertexIndex]',
          allowed: const <String>{'x', 'y'},
          required: const <String>{'x', 'y'},
        );
      }
      shapes.add(TerrainSourceShapeDef.fromJson(json, sourcePath: shapePath));
    }
    StrictAuthoringJson.requireStrictStringOrder(
      shapes.map((shape) => shape.shapeId),
      sourcePath: sourcePath,
    );
    return canonicalTerrainSourceShapes(shapes);
  }

  /// Rejects polygon coordinates that do not lie on whole source pixels.
  ///
  /// Source models use half-pixel ticks, so accepted coordinates must be even.
  /// Domain codecs call this after structural decoding when their authored
  /// contract is stricter than the shared source representation.
  static void requireWholePixelCoordinates(
    Iterable<TerrainSourceShapeDef> shapes, {
    required String sourcePath,
  }) {
    for (final (shapeIndex, shape) in shapes.indexed) {
      for (final (vertexIndex, vertex) in shape.vertices.indexed) {
        final vertexPath = '$sourcePath[$shapeIndex].vertices[$vertexIndex]';
        if (vertex.xHalfPixels.isOdd) {
          throw FormatException('$vertexPath.x must be a whole-pixel value.');
        }
        if (vertex.yHalfPixels.isOdd) {
          throw FormatException('$vertexPath.y must be a whole-pixel value.');
        }
      }
    }
  }
}
