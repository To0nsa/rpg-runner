import 'dart:collection';

import 'terrain_polygon.dart';
import 'terrain_source_canonicalizer.dart';

/// Severity exposed by authoring validation boundaries.
enum TerrainAuthoringIssueSeverity { warning, error }

/// Portable owner-aware issue envelope for terrain authoring consumers.
///
/// Core geometry keeps [TerrainDiagnostic] as its focused internal contract.
/// Generator and editor adapters use this envelope when they need explicit
/// owner and severity evidence alongside the Core lineage.
final class TerrainAuthoringIssue implements Comparable<TerrainAuthoringIssue> {
  TerrainAuthoringIssue({
    required this.severity,
    required this.code,
    required this.message,
    required this.sourcePath,
    required this.ownerKey,
    required this.placementKey,
    required this.shapeId,
    required this.elementIndex,
    this.elementId,
    this.fieldKey,
  }) {
    _requireNonEmpty(code, 'code');
    _requireNonEmpty(message, 'message');
    _requireNonEmpty(sourcePath, 'sourcePath');
    _requireNonEmpty(ownerKey, 'ownerKey');
    _requireOptionalNonEmpty(placementKey, 'placementKey');
    _requireOptionalNonEmpty(shapeId, 'shapeId');
    _requireOptionalNonEmpty(elementId, 'elementId');
    _requireOptionalNonEmpty(fieldKey, 'fieldKey');
    if (elementIndex != null && elementIndex! < 0) {
      throw ArgumentError.value(
        elementIndex,
        'elementIndex',
        'A present value must not be negative.',
      );
    }
  }

  /// Adapts one Core geometry diagnostic without changing its code or lineage.
  factory TerrainAuthoringIssue.fromCore({
    required TerrainDiagnostic diagnostic,
    required String ownerKey,
    required String? placementKey,
  }) => TerrainAuthoringIssue(
    severity: terrainDiagnosticIsBlocking(diagnostic)
        ? TerrainAuthoringIssueSeverity.error
        : TerrainAuthoringIssueSeverity.warning,
    code: diagnostic.code,
    message: diagnostic.message,
    sourcePath: diagnostic.sourcePath,
    ownerKey: ownerKey,
    placementKey: placementKey,
    shapeId: diagnostic.shapeId,
    elementIndex: diagnostic.elementIndex,
  );

  final TerrainAuthoringIssueSeverity severity;
  final String code;
  final String message;
  final String sourcePath;
  final String ownerKey;
  final String? placementKey;
  final String? shapeId;
  final int? elementIndex;

  /// Stable owner-local content identity when the issue is not polygon lineage.
  final String? elementId;
  final String? fieldKey;

  bool get isBlocking => severity == TerrainAuthoringIssueSeverity.error;

  @override
  int compareTo(TerrainAuthoringIssue other) {
    var order = sourcePath.compareTo(other.sourcePath);
    if (order != 0) return order;
    order = ownerKey.compareTo(other.ownerKey);
    if (order != 0) return order;
    order = _compareNullable(placementKey, other.placementKey);
    if (order != 0) return order;
    order = _compareNullable(shapeId, other.shapeId);
    if (order != 0) return order;
    order = _compareNullableInt(elementIndex, other.elementIndex);
    if (order != 0) return order;
    order = code.compareTo(other.code);
    if (order != 0) return order;
    order = _compareNullable(elementId, other.elementId);
    if (order != 0) return order;
    order = _compareNullable(fieldKey, other.fieldKey);
    return order != 0 ? order : severity.index.compareTo(other.severity.index);
  }
}

/// Returns an immutable canonical authoring-issue snapshot.
List<TerrainAuthoringIssue> canonicalTerrainAuthoringIssues(
  Iterable<TerrainAuthoringIssue> issues,
) => UnmodifiableListView<TerrainAuthoringIssue>(
  List<TerrainAuthoringIssue>.of(issues)..sort(),
);

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

void _requireOptionalNonEmpty(String? value, String name) {
  if (value != null) _requireNonEmpty(value, name);
}

int _compareNullable(String? left, String? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}

int _compareNullableInt(int? left, int? right) {
  if (identical(left, right)) return 0;
  if (left == null) return -1;
  if (right == null) return 1;
  return left.compareTo(right);
}
