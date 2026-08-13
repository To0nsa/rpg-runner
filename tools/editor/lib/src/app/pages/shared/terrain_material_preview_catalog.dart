import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:terrain_materials/terrain_materials.dart';

/// Surface semantics currently consumed by terrain placement and navigation.
const List<String> terrainSurfaceKindOptions = <String>['ground', 'obstacle'];

const String _terrainMaterialManifestPath =
    'assets/authoring/level/terrain_material_defs.json';

/// Loads the same authored material manifest consumed by runtime generation.
///
/// This synchronous read is intentionally limited to workspace initialization
/// and dialog creation. Callers retain the result for painting/building so an
/// editor frame never performs repository I/O.
TerrainMaterialCatalogDecodeResult loadTerrainMaterialPreviewCatalog(
  String workspaceRootPath,
) {
  final file = File(
    p.normalize(p.join(workspaceRootPath, _terrainMaterialManifestPath)),
  );
  if (!file.existsSync()) {
    return const TerrainMaterialCatalogDecodeResult(
      catalog: null,
      issues: <TerrainMaterialCatalogIssue>[
        TerrainMaterialCatalogIssue(
          code: 'missing_terrain_material_defs',
          path: _terrainMaterialManifestPath,
          message: 'Required terrain material manifest is missing.',
        ),
      ],
    );
  }
  try {
    return decodeTerrainMaterialCatalog(
      file.readAsStringSync(),
      sourcePath: _terrainMaterialManifestPath,
    );
  } on Object catch (error) {
    return TerrainMaterialCatalogDecodeResult(
      catalog: null,
      issues: <TerrainMaterialCatalogIssue>[
        TerrainMaterialCatalogIssue(
          code: 'terrain_material_defs_read_failed',
          path: _terrainMaterialManifestPath,
          message: 'Could not read terrain material definitions: $error',
        ),
      ],
    );
  }
}

/// Resolves one material after trimming its source key.
TerrainMaterialDefinition? terrainMaterialPreviewForKey(
  TerrainMaterialCatalog? catalog,
  String? materialKey,
) => catalog?.byKey[materialKey?.trim()];
