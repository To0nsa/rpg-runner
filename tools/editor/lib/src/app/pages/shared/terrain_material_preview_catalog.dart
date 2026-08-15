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

/// Builds a deterministic selector list with None first and an unknown current
/// value retained so opening an existing source record is non-destructive.
List<String> terrainMetadataSelectorOptions({
  required String? current,
  required Iterable<String> known,
}) {
  final normalizedCurrent = current?.trim() ?? '';
  return <String>{
    '',
    ...known,
    if (normalizedCurrent.isNotEmpty) normalizedCurrent,
  }.toList(growable: false);
}

/// User-facing label for an optional metadata selector value.
String terrainMetadataSelectorLabel(String value) =>
    value.isEmpty ? 'None' : value;

/// Selected material label that preserves both its display name and source key.
String terrainMaterialSelectorLabel(
  TerrainMaterialCatalog? catalog,
  String value,
) {
  if (value.isEmpty) return 'None';
  final material = terrainMaterialPreviewForKey(catalog, value);
  return material == null ? value : '${material.displayName} · ${material.key}';
}

/// Converts the inline None value back to nullable source metadata.
String? nullableTerrainMetadataSelection(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
