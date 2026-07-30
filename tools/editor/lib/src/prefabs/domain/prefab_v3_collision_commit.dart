import '../../terrain_authoring/terrain_polygon_interaction.dart';
import '../../terrain_authoring/terrain_source_models.dart';
import '../models/models.dart';
import '../validation/prefab_validation.dart';

/// Result of applying one shared polygon interaction commit to a prefab owner.
final class PrefabV3CollisionCommitResult {
  PrefabV3CollisionCommitResult({
    required this.data,
    required this.accepted,
    required this.changed,
    required Iterable<PrefabValidationIssue> issues,
  }) : issues = List<PrefabValidationIssue>.unmodifiable(issues);

  final PrefabV3FileData data;
  final bool accepted;
  final bool changed;
  final List<PrefabValidationIssue> issues;
}

/// Prefab-owned validation and revision policy for polygon interaction commits.
///
/// The shared interaction reducer owns gesture geometry and produces one
/// before/after commit. This policy verifies that commit against the current
/// prefab snapshot, applies prefab visual/owner rules, and bumps revision once.
/// Rejected or no-op commits return the original [PrefabV3FileData] instance so
/// session history cannot record an invalid or empty edit.
final class PrefabV3CollisionCommitPolicy {
  const PrefabV3CollisionCommitPolicy();

  PrefabV3CollisionCommitResult apply({
    required PrefabV3FileData data,
    required String prefabKey,
    required TerrainPolygonInteractionCommit commit,
    required int? sourceWidthPx,
    required int? sourceHeightPx,
    String sourcePath = 'assets/authoring/level/prefab_defs.json',
  }) {
    final prefabIndex = data.prefabs.indexWhere(
      (prefab) => prefab.prefabKey == prefabKey,
    );
    if (prefabIndex < 0) {
      return _rejected(
        data,
        PrefabValidationIssue(
          code: 'prefab_polygon_owner_missing',
          message: 'Prefab $prefabKey does not exist in the current document.',
          sourcePath: sourcePath,
        ),
      );
    }

    final prefab = data.prefabs[prefabIndex];
    if (!_shapeListsEqual(prefab.collisionShapes, commit.beforeShapes)) {
      return _rejected(
        data,
        PrefabValidationIssue(
          code: 'prefab_polygon_commit_stale',
          message:
              'Prefab ${prefab.id} changed after this polygon gesture began; '
              'reload its current collision source before committing.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (_shapeListsEqual(commit.beforeShapes, commit.afterShapes)) {
      return PrefabV3CollisionCommitResult(
        data: data,
        accepted: true,
        changed: false,
        issues: const <PrefabValidationIssue>[],
      );
    }

    late final List<TerrainSourceShapeDef> canonicalShapes;
    try {
      canonicalShapes = canonicalTerrainSourceShapes(commit.afterShapes);
    } on ArgumentError catch (error) {
      return _rejected(
        data,
        PrefabValidationIssue(
          code: 'prefab_collision_shape_identity_invalid',
          message: 'Prefab ${prefab.id} has invalid shape identity: $error',
          sourcePath: sourcePath,
        ),
      );
    }
    if (!_shapeListsEqual(canonicalShapes, commit.afterShapes)) {
      return _rejected(
        data,
        PrefabValidationIssue(
          code: 'prefab_collision_shape_order_noncanonical',
          message:
              'Prefab ${prefab.id} collision shapes must be ordered by stable '
              'shape ID before commit.',
          sourcePath: sourcePath,
        ),
      );
    }
    if (prefab.kind != PrefabKind.decoration &&
        (sourceWidthPx == null || sourceHeightPx == null)) {
      return _rejected(
        data,
        PrefabValidationIssue(
          code: 'prefab_polygon_visual_bounds_unresolved',
          message:
              'Prefab ${prefab.id} visual bounds must resolve before collision '
              'geometry can be committed.',
          sourcePath: sourcePath,
        ),
      );
    }

    final issues = validatePrefabCollisionShapes(
      prefabId: prefab.id,
      prefabKey: prefab.prefabKey,
      kind: prefab.kind,
      anchorXPx: prefab.anchorXPx,
      anchorYPx: prefab.anchorYPx,
      collisionShapes: canonicalShapes,
      sourceWidthPx: sourceWidthPx,
      sourceHeightPx: sourceHeightPx,
      sourcePath: '$sourcePath:${prefab.prefabKey}',
    );
    if (issues.any(
      (issue) => issue.severity == PrefabValidationSeverity.error,
    )) {
      return PrefabV3CollisionCommitResult(
        data: data,
        accepted: false,
        changed: false,
        issues: issues,
      );
    }

    final updatedPrefab = prefab.copyWith(
      revision: prefab.revision + 1,
      collisionShapes: canonicalShapes,
    );
    final updatedPrefabs = data.prefabs.toList(growable: false);
    updatedPrefabs[prefabIndex] = updatedPrefab;
    return PrefabV3CollisionCommitResult(
      data: data.copyWith(prefabs: updatedPrefabs),
      accepted: true,
      changed: true,
      issues: issues,
    );
  }
}

PrefabV3CollisionCommitResult _rejected(
  PrefabV3FileData data,
  PrefabValidationIssue issue,
) => PrefabV3CollisionCommitResult(
  data: data,
  accepted: false,
  changed: false,
  issues: <PrefabValidationIssue>[issue],
);

bool _shapeListsEqual(
  List<TerrainSourceShapeDef> left,
  List<TerrainSourceShapeDef> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
