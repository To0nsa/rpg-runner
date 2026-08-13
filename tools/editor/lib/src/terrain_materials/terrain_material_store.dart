import 'dart:convert';
import 'dart:io';

import 'package:terrain_materials/terrain_materials.dart';

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import '../workspace/workspace_file_io.dart';
import 'terrain_material_domain_models.dart';

/// Repository I/O boundary for the canonical terrain material manifest.
final class TerrainMaterialStore {
  const TerrainMaterialStore();

  Future<TerrainMaterialDocument> load(EditorWorkspace workspace) async {
    final file = File(workspace.resolve(terrainMaterialDefsSourcePath));
    if (!await file.exists()) {
      return TerrainMaterialDocument(
        workspaceRootPath: workspace.rootPath,
        materials: const <TerrainMaterialDefinition>[],
        baseline: null,
        referencedMaterialKeys: _scanMaterialReferences(workspace),
        loadIssues: const <ValidationIssue>[
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'missing_terrain_material_defs',
            message: 'Required terrain material manifest is missing.',
            sourcePath: terrainMaterialDefsSourcePath,
          ),
        ],
      );
    }
    final source = await file.readAsString();
    final decoded = decodeTerrainMaterialCatalog(
      source,
      sourcePath: terrainMaterialDefsSourcePath,
    );
    final issues = <ValidationIssue>[
      for (final issue in decoded.issues)
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: issue.code,
          message: issue.message,
          sourcePath: issue.path,
          ownerKey: issue.materialKey,
        ),
    ];
    final catalog = decoded.catalog;
    if (catalog != null &&
        _normalizeNewlines(source) != catalog.toCanonicalJson()) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'non_canonical_terrain_material_defs',
          message: 'Terrain material definitions are not canonically encoded.',
          sourcePath: terrainMaterialDefsSourcePath,
        ),
      );
    }
    return TerrainMaterialDocument(
      workspaceRootPath: workspace.rootPath,
      materials: catalog?.materials ?? const <TerrainMaterialDefinition>[],
      baseline: TerrainMaterialSourceBaseline(
        sourcePath: terrainMaterialDefsSourcePath,
        source: source,
      ),
      referencedMaterialKeys: _scanMaterialReferences(workspace),
      loadIssues: List<ValidationIssue>.unmodifiable(issues),
    );
  }

  String canonicalSource(TerrainMaterialDocument document) =>
      TerrainMaterialCatalog(materials: document.materials).toCanonicalJson();

  Future<void> save(
    EditorWorkspace workspace, {
    required TerrainMaterialDocument document,
  }) async {
    final file = File(workspace.resolve(terrainMaterialDefsSourcePath));
    final current = file.existsSync() ? file.readAsStringSync() : null;
    final baseline = document.baseline;
    if (baseline == null || current != baseline.source) {
      throw StateError(
        'Terrain material source changed outside the editor. Reload before applying.',
      );
    }
    WorkspaceFileIo.atomicWrite(file, canonicalSource(document));
  }
}

Set<String> _scanMaterialReferences(EditorWorkspace workspace) {
  final roots = <String>[
    'assets/authoring/level/prefab_defs.json',
    'assets/authoring/level/chunks',
  ];
  final references = <String>{};
  for (final relativePath in roots) {
    final entityType = FileSystemEntity.typeSync(
      workspace.resolve(relativePath),
    );
    if (entityType == FileSystemEntityType.file) {
      _collectFileReferences(File(workspace.resolve(relativePath)), references);
    } else if (entityType == FileSystemEntityType.directory) {
      final files =
          Directory(workspace.resolve(relativePath))
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.json'))
              .toList()
            ..sort((left, right) => left.path.compareTo(right.path));
      for (final file in files) {
        _collectFileReferences(file, references);
      }
    }
  }
  return Set<String>.unmodifiable(references);
}

void _collectFileReferences(File file, Set<String> references) {
  try {
    _collectJsonReferences(jsonDecode(file.readAsStringSync()), references);
  } on Object {
    // Owning Prefab/Chunk plugins report malformed source. This scan only
    // supplies conservative delete protection for successfully decoded keys.
  }
}

void _collectJsonReferences(Object? value, Set<String> references) {
  if (value is Map<String, Object?>) {
    final materialKey = value['materialKey'];
    if (materialKey is String && materialKey.trim().isNotEmpty) {
      references.add(materialKey.trim());
    }
    for (final nested in value.values) {
      _collectJsonReferences(nested, references);
    }
  } else if (value is List<Object?>) {
    for (final nested in value) {
      _collectJsonReferences(nested, references);
    }
  }
}

String _normalizeNewlines(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
