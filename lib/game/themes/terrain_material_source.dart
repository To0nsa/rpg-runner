import 'package:terrain_materials/terrain_materials.dart';

import 'terrain_material_registry.dart';

/// Projects the validated shared source contract into runtime render values.
Map<String, TerrainMaterialSpec> terrainMaterialSpecsFromCatalog(
  TerrainMaterialCatalog catalog,
) => Map<String, TerrainMaterialSpec>.unmodifiable({
  for (final material in catalog.materials)
    material.key: TerrainMaterialSpec(
      key: material.key,
      displayName: material.displayName,
      revision: material.revision,
      fill: _region(material.fill),
      top: _profile(material.top)!,
      leftWall: _profile(material.leftWall),
      rightWall: _profile(material.rightWall),
      underside: _profile(material.underside),
      topStartCap: _cap(material.topStartCap),
      topEndCap: _cap(material.topEndCap),
      undersideStartCap: _cap(material.undersideStartCap),
      undersideEndCap: _cap(material.undersideEndCap),
    ),
});

TerrainMaterialImageRegionSpec _region(TerrainMaterialImageRegion value) =>
    TerrainMaterialImageRegionSpec(
      assetPath: value.assetPath.substring('assets/images/'.length),
      x: value.x,
      y: value.y,
      width: value.width,
      height: value.height,
    );
TerrainMaterialEdgeLayerSpec _layer(TerrainMaterialEdgeLayer value) =>
    TerrainMaterialEdgeLayerSpec(
      region: _region(value.region),
      anchorY: value.anchorY,
    );
TerrainMaterialEdgeProfileSpec? _profile(TerrainMaterialEdgeProfile? value) =>
    value == null
    ? null
    : TerrainMaterialEdgeProfileSpec(
        base: _layer(value.base),
        detail: value.detail == null ? null : _layer(value.detail!),
      );
TerrainMaterialCapSpec? _cap(TerrainMaterialCap? value) => value == null
    ? null
    : TerrainMaterialCapSpec(
        region: _region(value.region),
        anchorX: value.anchorX,
        anchorY: value.anchorY,
      );
