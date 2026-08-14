import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:terrain_materials/terrain_materials.dart';

import 'generated_artifact_plan.dart';

const String terrainMaterialDefsPath =
    'assets/authoring/level/terrain_material_defs.json';
const String terrainMaterialRegistryOutputPath =
    'lib/game/themes/authored_terrain_materials.dart';

/// One repository-level material source validation finding.
final class TerrainMaterialGenerationIssue
    implements Comparable<TerrainMaterialGenerationIssue> {
  const TerrainMaterialGenerationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  @override
  int compareTo(TerrainMaterialGenerationIssue other) {
    final pathOrder = path.compareTo(other.path);
    return pathOrder != 0 ? pathOrder : code.compareTo(other.code);
  }
}

/// Validated terrain-material source plus its deterministic generated output.
final class TerrainMaterialGenerationResult {
  const TerrainMaterialGenerationResult({
    required this.catalog,
    required this.output,
    required this.issues,
  });

  final TerrainMaterialCatalog? catalog;
  final GeneratedArtifact? output;
  final List<TerrainMaterialGenerationIssue> issues;
}

/// Loads the canonical material manifest and verifies every referenced image.
Future<TerrainMaterialGenerationResult> buildTerrainMaterialRegistry({
  String defsPath = terrainMaterialDefsPath,
  String outputPath = terrainMaterialRegistryOutputPath,
}) async {
  final issues = <TerrainMaterialGenerationIssue>[];
  final file = File(defsPath);
  if (!await file.exists()) {
    return TerrainMaterialGenerationResult(
      catalog: null,
      output: null,
      issues: <TerrainMaterialGenerationIssue>[
        TerrainMaterialGenerationIssue(
          path: defsPath,
          code: 'missing_terrain_material_defs',
          message: 'Required terrain material manifest is missing.',
        ),
      ],
    );
  }
  late final String source;
  try {
    source = await file.readAsString();
  } on Object catch (error) {
    return TerrainMaterialGenerationResult(
      catalog: null,
      output: null,
      issues: <TerrainMaterialGenerationIssue>[
        TerrainMaterialGenerationIssue(
          path: defsPath,
          code: 'terrain_material_defs_read_failed',
          message: 'Unable to read material manifest: $error',
        ),
      ],
    );
  }
  final decoded = decodeTerrainMaterialCatalog(source, sourcePath: defsPath);
  issues.addAll(
    decoded.issues.map(
      (issue) => TerrainMaterialGenerationIssue(
        path: issue.path,
        code: issue.code,
        message: issue.message,
      ),
    ),
  );
  final catalog = decoded.catalog;
  if (catalog == null) {
    issues.sort();
    return TerrainMaterialGenerationResult(
      catalog: null,
      output: null,
      issues: List<TerrainMaterialGenerationIssue>.unmodifiable(issues),
    );
  }
  if (_normalizeNewlines(source) != catalog.toCanonicalJson()) {
    issues.add(
      TerrainMaterialGenerationIssue(
        path: defsPath,
        code: 'non_canonical_terrain_material_defs',
        message:
            'Material definitions must use canonical fields, key order, '
            'paths, and numeric formatting.',
      ),
    );
  }
  final dimensionsByPath = <String, TerrainMaterialImageDimensions>{};
  for (final material in catalog.materials) {
    for (final assetPath in terrainMaterialAssetPaths(material)) {
      if (dimensionsByPath.containsKey(assetPath)) continue;
      final assetFile = File(assetPath);
      if (!await assetFile.exists()) {
        issues.add(
          TerrainMaterialGenerationIssue(
            path: assetPath,
            code: 'terrain_material_asset_missing',
            message: 'Material "${material.key}" references a missing image.',
          ),
        );
        continue;
      }
      try {
        final decodedImage = image.decodePng(await assetFile.readAsBytes());
        if (decodedImage == null) {
          throw const FormatException('PNG decoder returned no image.');
        }
        dimensionsByPath[assetPath] = TerrainMaterialImageDimensions(
          width: decodedImage.width,
          height: decodedImage.height,
        );
      } on Object catch (error) {
        issues.add(
          TerrainMaterialGenerationIssue(
            path: assetPath,
            code: 'terrain_material_asset_invalid',
            message: 'Terrain material image is not a valid PNG: $error',
          ),
        );
      }
    }
  }
  issues.addAll(
    validateTerrainMaterialImageDimensions(
      catalog,
      dimensionsFor: (assetPath) => dimensionsByPath[assetPath],
    ).map(
      (issue) => TerrainMaterialGenerationIssue(
        path: issue.path,
        code: issue.code,
        message: issue.message,
      ),
    ),
  );
  issues.sort();
  return TerrainMaterialGenerationResult(
    catalog: catalog,
    output: issues.isEmpty
        ? GeneratedArtifact(
            path: outputPath,
            content: renderTerrainMaterialRegistry(catalog),
          )
        : null,
    issues: List<TerrainMaterialGenerationIssue>.unmodifiable(issues),
  );
}

/// Renders the Flame registry without reinterpreting the source schema.
String renderTerrainMaterialRegistry(TerrainMaterialCatalog catalog) {
  final buffer = StringBuffer()
    ..writeln('// Generated by tool/generate_chunk_runtime_data.dart.')
    ..writeln('// Do not edit by hand.')
    ..writeln()
    ..writeln("part of 'terrain_material_registry.dart';")
    ..writeln()
    ..writeln(
      'const Map<String, TerrainMaterialSpec> _authoredTerrainMaterials =',
    )
    ..writeln('    <String, TerrainMaterialSpec>{');
  for (final material in catalog.materials) {
    buffer
      ..writeln('      ${_dartString(material.key)}: TerrainMaterialSpec(')
      ..writeln('        key: ${_dartString(material.key)},')
      ..writeln('        displayName: ${_dartString(material.displayName)},')
      ..writeln('        revision: ${material.revision},')
      ..writeln('        fill: TerrainMaterialImageRegionSpec(');
    _writeRegionFields(buffer, material.fill, indent: '          ');
    buffer.writeln('        ),');
    _writeProfile(buffer, 'top', material.top, indent: '        ');
    if (material.leftWall case final profile?) {
      _writeProfile(buffer, 'leftWall', profile, indent: '        ');
    }
    if (material.rightWall case final profile?) {
      _writeProfile(buffer, 'rightWall', profile, indent: '        ');
    }
    if (material.underside case final profile?) {
      _writeProfile(buffer, 'underside', profile, indent: '        ');
    }
    if (material.topStartCap case final cap?) {
      _writeCap(buffer, 'topStartCap', cap, indent: '        ');
    }
    if (material.topEndCap case final cap?) {
      _writeCap(buffer, 'topEndCap', cap, indent: '        ');
    }
    if (material.undersideStartCap case final cap?) {
      _writeCap(buffer, 'undersideStartCap', cap, indent: '        ');
    }
    if (material.undersideEndCap case final cap?) {
      _writeCap(buffer, 'undersideEndCap', cap, indent: '        ');
    }
    buffer.writeln('      ),');
  }
  buffer.writeln('    };');
  return buffer.toString();
}

void _writeProfile(
  StringBuffer buffer,
  String fieldName,
  TerrainMaterialEdgeProfile profile, {
  required String indent,
}) {
  final childIndent = '$indent  ';
  buffer.writeln('$indent$fieldName: TerrainMaterialEdgeProfileSpec(');
  _writeLayer(buffer, 'base', profile.base, indent: childIndent);
  if (profile.detail case final detail?) {
    _writeLayer(buffer, 'detail', detail, indent: childIndent);
  }
  buffer.writeln('$indent),');
}

void _writeLayer(
  StringBuffer buffer,
  String fieldName,
  TerrainMaterialEdgeLayer layer, {
  required String indent,
}) {
  buffer
    ..writeln('$indent$fieldName: TerrainMaterialEdgeLayerSpec(')
    ..writeln('$indent  region: TerrainMaterialImageRegionSpec(');
  _writeRegionFields(buffer, layer.region, indent: '$indent    ');
  buffer
    ..writeln('$indent  ),')
    ..writeln('$indent  anchorY: ${_dartNumber(layer.anchorY)},')
    ..writeln('$indent),');
}

void _writeCap(
  StringBuffer buffer,
  String fieldName,
  TerrainMaterialCap cap, {
  required String indent,
}) {
  buffer
    ..writeln('$indent$fieldName: TerrainMaterialCapSpec(')
    ..writeln('$indent  region: TerrainMaterialImageRegionSpec(');
  _writeRegionFields(buffer, cap.region, indent: '$indent    ');
  buffer
    ..writeln('$indent  ),')
    ..writeln('$indent  anchorX: ${_dartNumber(cap.anchorX)},')
    ..writeln('$indent  anchorY: ${_dartNumber(cap.anchorY)},')
    ..writeln('$indent),');
}

void _writeRegionFields(
  StringBuffer buffer,
  TerrainMaterialImageRegion region, {
  required String indent,
}) {
  buffer
    ..writeln(
      '${indent}assetPath: ${_dartString(_runtimePath(region.assetPath))},',
    )
    ..writeln('${indent}x: ${region.x},')
    ..writeln('${indent}y: ${region.y},')
    ..writeln('${indent}width: ${region.width},')
    ..writeln('${indent}height: ${region.height},');
}

String _runtimePath(String path) => path.substring('assets/images/'.length);

String _dartString(String value) =>
    "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";

String _dartNumber(double value) => value == value.roundToDouble()
    ? '${value.toInt()}.0'
    : value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');

String _normalizeNewlines(String value) =>
    value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
