import 'dart:math' as math;

import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/collision/terrain/terrain_polygon_overlap.dart';
import 'package:runner_core/collision/terrain/terrain_source_canonicalizer.dart';

import '../../terrain_authoring/terrain_authoring_capacity_issues.dart';
import '../../terrain_authoring/terrain_source_core_adapter.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import '../models/shared/prefab_enums.dart';

/// Current prefab-v3 polygon validation and deterministic issue ordering.
part 'prefab_validation_polygons.dart';
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
    this.ownerKey,
    this.shapeId = '',
    this.elementIndex = 0,
  });

  final String code;
  final String message;
  final PrefabValidationSeverity severity;
  final String sourcePath;
  final String? ownerKey;
  final String shapeId;
  final int elementIndex;
}
