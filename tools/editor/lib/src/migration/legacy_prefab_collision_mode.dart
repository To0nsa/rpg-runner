import '../prefabs/models/models.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'legacy_prefab_models.dart';

/// Applies rectangle-era prefab sidedness without changing polygon geometry.
List<TerrainSourceShapeDef> applyLegacyPrefabCollisionMode({
  required LegacyPrefabDef prefab,
  required Iterable<TerrainSourceShapeDef> shapes,
}) {
  final source = shapes.toList(growable: false);
  if (source.isEmpty) return const <TerrainSourceShapeDef>[];
  final mode = switch (prefab.kind) {
    PrefabKind.obstacle => TerrainSourceCollisionMode.solid,
    PrefabKind.platform => TerrainSourceCollisionMode.oneWay,
    PrefabKind.decoration || PrefabKind.unknown => throw ArgumentError.value(
      prefab.kind,
      'prefab.kind',
      'A colliding legacy prefab must be an obstacle or platform.',
    ),
  };
  return canonicalTerrainSourceShapes(
    source.map(
      (shape) => TerrainSourceShapeDef(
        shapeId: shape.shapeId,
        vertices: shape.vertices,
        collisionMode: mode,
        surfaceKind: shape.surfaceKind,
        materialKey: shape.materialKey,
      ),
    ),
  );
}
