import 'package:terrain_materials/terrain_materials.dart';

import '../domain/authoring_types.dart';
import '../workspace/repository_png_catalog.dart';

const String terrainMaterialDefsSourcePath =
    'assets/authoring/level/terrain_material_defs.json';

/// Repository baseline used to reject writes after external source drift.
final class TerrainMaterialSourceBaseline {
  const TerrainMaterialSourceBaseline({
    required this.sourcePath,
    required this.source,
  });

  final String sourcePath;
  final String source;
}

/// Session-owned editable terrain material catalog.
final class TerrainMaterialDocument extends AuthoringDocument {
  const TerrainMaterialDocument({
    required this.workspaceRootPath,
    required this.materials,
    required this.baseline,
    required this.referencedMaterialKeys,
    required this.atlasImages,
    this.loadIssues = const <ValidationIssue>[],
  });

  final String workspaceRootPath;
  final List<TerrainMaterialDefinition> materials;
  final TerrainMaterialSourceBaseline? baseline;
  final Set<String> referencedMaterialKeys;
  final List<RepositoryPngImage> atlasImages;
  final List<ValidationIssue> loadIssues;

  TerrainMaterialDocument copyWith({
    List<TerrainMaterialDefinition>? materials,
  }) => TerrainMaterialDocument(
    workspaceRootPath: workspaceRootPath,
    materials: materials ?? this.materials,
    baseline: baseline,
    referencedMaterialKeys: referencedMaterialKeys,
    atlasImages: atlasImages,
    loadIssues: loadIssues,
  );
}

/// UI projection of the current material catalog and reference state.
final class TerrainMaterialScene extends EditableScene {
  const TerrainMaterialScene({
    required this.workspaceRootPath,
    required this.materials,
    required this.referencedMaterialKeys,
    required this.atlasImages,
  });

  final String workspaceRootPath;
  final List<TerrainMaterialDefinition> materials;
  final Set<String> referencedMaterialKeys;
  final List<RepositoryPngImage> atlasImages;
}
