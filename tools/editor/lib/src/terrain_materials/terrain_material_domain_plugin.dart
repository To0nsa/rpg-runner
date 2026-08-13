import 'dart:io';

import 'package:terrain_materials/terrain_materials.dart';

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'terrain_material_domain_models.dart';
import 'terrain_material_store.dart';

/// Session plugin for repository-backed terrain render material authoring.
final class TerrainMaterialDomainPlugin implements AuthoringDomainPlugin {
  TerrainMaterialDomainPlugin({
    TerrainMaterialStore store = const TerrainMaterialStore(),
  }) : _store = store;

  static const String pluginId = 'terrain_materials';

  final TerrainMaterialStore _store;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) =>
      _store.load(workspace);

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final materialDocument = _requireDocument(document);
    final issues = <ValidationIssue>[...materialDocument.loadIssues];
    final byKey = <String, TerrainMaterialDefinition>{};
    for (final material in materialDocument.materials) {
      if (byKey.containsKey(material.key)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_material_key',
            message: 'Material key "${material.key}" is duplicated.',
            sourcePath: terrainMaterialDefsSourcePath,
            ownerKey: material.key,
          ),
        );
      }
      byKey[material.key] = material;
      for (final assetPath in _assetPaths(material)) {
        if (!File(
          '${materialDocument.workspaceRootPath}${Platform.pathSeparator}'
          '${assetPath.replaceAll('/', Platform.pathSeparator)}',
        ).existsSync()) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'terrain_material_asset_missing',
              message: 'Referenced image is missing: $assetPath',
              sourcePath: assetPath,
              ownerKey: material.key,
            ),
          );
        }
      }
    }
    for (final key in materialDocument.referencedMaterialKeys) {
      if (!byKey.containsKey(key)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'referenced_material_missing',
            message: 'Polygon sources reference missing material "$key".',
            sourcePath: terrainMaterialDefsSourcePath,
            ownerKey: key,
          ),
        );
      }
    }
    issues.sort((left, right) {
      var order = (left.sourcePath ?? '').compareTo(right.sourcePath ?? '');
      if (order != 0) return order;
      order = (left.ownerKey ?? '').compareTo(right.ownerKey ?? '');
      return order != 0 ? order : left.code.compareTo(right.code);
    });
    return List<ValidationIssue>.unmodifiable(issues);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final materialDocument = _requireDocument(document);
    return TerrainMaterialScene(
      workspaceRootPath: materialDocument.workspaceRootPath,
      materials: materialDocument.materials,
      referencedMaterialKeys: materialDocument.referencedMaterialKeys,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final materialDocument = _requireDocument(document);
    switch (command.kind) {
      case 'upsert_material':
        final material = command.payload['material'];
        final previousKey = command.payload['previousKey'];
        if (material is! TerrainMaterialDefinition || previousKey is! String) {
          return materialDocument;
        }
        if (previousKey.isNotEmpty &&
            previousKey != material.key &&
            materialDocument.referencedMaterialKeys.contains(previousKey)) {
          return materialDocument;
        }
        final next = <TerrainMaterialDefinition>[
          for (final current in materialDocument.materials)
            if (current.key != previousKey) current,
          material,
        ]..sort((left, right) => left.key.compareTo(right.key));
        if (_sameMaterials(next, materialDocument.materials)) {
          return materialDocument;
        }
        return materialDocument.copyWith(
          materials: List<TerrainMaterialDefinition>.unmodifiable(next),
        );
      case 'delete_material':
        final key = command.payload['key'];
        if (key is! String ||
            materialDocument.referencedMaterialKeys.contains(key)) {
          return materialDocument;
        }
        final next = materialDocument.materials
            .where((material) => material.key != key)
            .toList(growable: false);
        if (next.length == materialDocument.materials.length) {
          return materialDocument;
        }
        return materialDocument.copyWith(materials: next);
      default:
        return materialDocument;
    }
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final materialDocument = _requireDocument(document);
    final blocking = validate(
      materialDocument,
    ).where((issue) => issue.severity == ValidationSeverity.error);
    if (blocking.isNotEmpty) {
      throw StateError('Cannot apply terrain materials with blocking issues.');
    }
    final after = _store.canonicalSource(materialDocument);
    if (after == materialDocument.baseline?.source) {
      return ExportResult(applied: false);
    }
    await _store.save(workspace, document: materialDocument);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(
          title: 'terrain_material_summary.md',
          content:
              '# Terrain Materials\n\nmaterials: '
              '${materialDocument.materials.length}\n',
        ),
      ],
    );
  }

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final materialDocument = _requireDocument(document);
    final before = materialDocument.baseline?.source ?? '';
    final after = _store.canonicalSource(materialDocument);
    if (before == after) return PendingChanges.empty;
    return PendingChanges(
      changedItemIds: materialDocument.materials
          .map((material) => material.key)
          .toList(growable: false),
      fileDiffs: <PendingFileDiff>[
        PendingFileDiff(
          relativePath: terrainMaterialDefsSourcePath,
          editCount: 1,
          unifiedDiff:
              'diff --git a/$terrainMaterialDefsSourcePath '
              'b/$terrainMaterialDefsSourcePath\n'
              '--- a/$terrainMaterialDefsSourcePath\n'
              '+++ b/$terrainMaterialDefsSourcePath\n'
              '@@ terrain material catalog @@\n'
              '-$before\n+$after',
        ),
      ],
    );
  }
}

TerrainMaterialDocument _requireDocument(AuthoringDocument document) {
  if (document is! TerrainMaterialDocument) {
    throw StateError('Terrain material plugin requires its own document.');
  }
  return document;
}

List<String> _assetPaths(TerrainMaterialDefinition material) {
  final paths = <String>{material.fillAssetPath};
  void addProfile(TerrainMaterialEdgeProfile? profile) {
    if (profile == null) return;
    paths.add(profile.base.assetPath);
    if (profile.detail case final detail?) paths.add(detail.assetPath);
  }

  addProfile(material.top);
  addProfile(material.leftWall);
  addProfile(material.rightWall);
  addProfile(material.underside);
  if (material.topStartCap case final cap?) paths.add(cap.assetPath);
  if (material.topEndCap case final cap?) paths.add(cap.assetPath);
  return paths.toList()..sort();
}

bool _sameMaterials(
  List<TerrainMaterialDefinition> left,
  List<TerrainMaterialDefinition> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
