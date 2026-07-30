import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:path/path.dart' as p;
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import '../../terrain_authoring/terrain_source_core_adapter.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import '../models/models.dart';

/// Prefab-domain validation entry points and shared private state.
///
/// Validation is split into part files by concern (atlas/module/prefab) but
/// orchestrated here to produce one deterministic issue list.

part 'prefab_validation_atlas.dart';
part 'prefab_validation_geometry.dart';
part 'prefab_validation_modules.dart';
part 'prefab_validation_polygons.dart';
part 'prefab_validation_prefabs.dart';
part 'prefab_validation_sorting.dart';

/// Export impact of one prefab validation finding.
enum PrefabValidationSeverity { warning, error }

/// Structured validation issue with stable code for UI and tests.
class PrefabValidationIssue {
  const PrefabValidationIssue({
    required this.code,
    required this.message,
    this.severity = PrefabValidationSeverity.error,
    this.sourcePath = '',
    this.shapeId = '',
    this.elementIndex = 0,
  });

  final String code;
  final String message;
  final PrefabValidationSeverity severity;
  final String sourcePath;
  final String shapeId;
  final int elementIndex;
}

/// Slice lookup state built once and reused by module/prefab validation.
class _SliceValidationIndex {
  const _SliceValidationIndex({
    required this.prefabSliceIds,
    required this.tileSliceIds,
    required this.prefabSliceById,
    required this.tileSliceById,
  });

  final Set<String> prefabSliceIds;
  final Set<String> tileSliceIds;
  final Map<String, AtlasSliceDef> prefabSliceById;
  final Map<String, AtlasSliceDef> tileSliceById;
}

/// Module lookup state built once and reused by prefab validation.
class _ModuleValidationIndex {
  const _ModuleValidationIndex({
    required this.moduleIds,
    required this.moduleById,
  });

  final Set<String> moduleIds;
  final Map<String, TileModuleDef> moduleById;
}

/// Validates [data] and returns deterministic, structured issues.
List<PrefabValidationIssue> validatePrefabDataIssues({
  required PrefabData data,
  required Map<String, Size> atlasImageSizes,
}) {
  final normalizedAtlasImageSizes = <String, Size>{};
  for (final entry in atlasImageSizes.entries) {
    normalizedAtlasImageSizes[_normalizeAtlasSourcePath(entry.key)] =
        entry.value;
  }

  final issues = <PrefabValidationIssue>[];
  if (data.schemaVersion != currentPrefabSchemaVersion) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_schema_version_invalid',
        message:
            'Invalid prefab schemaVersion ${data.schemaVersion}; '
            'expected $currentPrefabSchemaVersion.',
      ),
    );
  }

  final sortedPrefabSlices = List<AtlasSliceDef>.from(data.prefabSlices)
    ..sort(_compareSlices);
  final sortedTileSlices = List<AtlasSliceDef>.from(data.tileSlices)
    ..sort(_compareSlices);
  final sortedModules = List<TileModuleDef>.from(data.platformModules)
    ..sort((a, b) => a.id.compareTo(b.id));
  final sortedPrefabs = List<PrefabDef>.from(data.prefabs)
    ..sort(_comparePrefabs);

  final sliceIndex = _validateAndIndexSlices(
    issues: issues,
    prefabSlices: sortedPrefabSlices,
    tileSlices: sortedTileSlices,
    atlasImageSizes: normalizedAtlasImageSizes,
  );

  final moduleIndex = _validateAndIndexModules(
    issues: issues,
    modules: sortedModules,
    tileSliceIds: sliceIndex.tileSliceIds,
  );

  _validatePrefabs(
    issues: issues,
    prefabs: sortedPrefabs,
    prefabSliceIds: sliceIndex.prefabSliceIds,
    prefabSliceById: sliceIndex.prefabSliceById,
    moduleIds: moduleIndex.moduleIds,
    moduleById: moduleIndex.moduleById,
    tileSliceById: sliceIndex.tileSliceById,
  );

  issues.sort(_compareIssues);
  return List<PrefabValidationIssue>.unmodifiable(issues);
}

String _normalizeAtlasSourcePath(String rawPath) {
  final normalized = p.normalize(rawPath.trim());
  if (p.context.style == p.Style.windows) {
    return normalized.toLowerCase();
  }
  return normalized;
}

/// Convenience wrapper used by callers that only need issue messages.
List<String> validatePrefabData({
  required PrefabData data,
  required Map<String, Size> atlasImageSizes,
}) {
  return validatePrefabDataIssues(
    data: data,
    atlasImageSizes: atlasImageSizes,
  ).map((issue) => issue.message).toList(growable: false);
}
