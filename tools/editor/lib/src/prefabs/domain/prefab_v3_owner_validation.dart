import '../models/models.dart';
import '../store/prefab_determinism.dart';
import '../validation/prefab_validation.dart';
import 'prefab_domain_models.dart';

/// Validates revision-owned prefab-v3 fields against the current visual catalog.
///
/// This is intentionally owner-scoped: slice/module mutation policy performs
/// catalog-wide checks, while polygon topology remains delegated to the shared
/// Core-backed prefab collision validator.
List<PrefabValidationIssue> validatePrefabV3Owner({
  required PrefabV3FileData prefabData,
  required PrefabTileFileData tileData,
  required PrefabV3Def prefab,
  required PrefabV3VisualBounds? visualBounds,
  String sourcePath = 'assets/authoring/level/prefab_defs.json',
}) {
  final ownerPath = '$sourcePath:${prefab.prefabKey}';
  final issues = <PrefabValidationIssue>[];
  if (prefab.status == PrefabStatus.unknown) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_status_invalid',
        message: 'Prefab ${prefab.id} has an unsupported lifecycle status.',
        sourcePath: ownerPath,
      ),
    );
  }
  if (prefab.kind == PrefabKind.unknown) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_kind_invalid',
        message: 'Prefab ${prefab.id} has an unsupported kind.',
        sourcePath: ownerPath,
      ),
    );
  }

  final canonicalTags = PrefabDeterminism.normalizeTags(prefab.tags);
  if (!_stringListsEqual(prefab.tags, canonicalTags)) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_tags_noncanonical',
        message:
            'Prefab ${prefab.id} tags must be trimmed, non-empty, unique, '
            'and ordered lexically before commit.',
        sourcePath: ownerPath,
      ),
    );
  }

  switch (prefab.visualSource.type) {
    case PrefabVisualSourceType.atlasSlice:
      if (!prefabData.slices.any((slice) => slice.id == prefab.sliceId)) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_source_slice_missing',
            message:
                'Prefab ${prefab.id} references missing prefab slice '
                '${prefab.sliceId}.',
            sourcePath: ownerPath,
          ),
        );
      }
      if (prefab.kind == PrefabKind.platform) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_kind_source_mismatch',
            message:
                'Prefab ${prefab.id} cannot use an atlas slice as a platform.',
            sourcePath: ownerPath,
          ),
        );
      }
    case PrefabVisualSourceType.platformModule:
      if (!tileData.platformModules.any(
        (module) => module.id == prefab.moduleId,
      )) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_source_module_missing',
            message:
                'Prefab ${prefab.id} references missing platform module '
                '${prefab.moduleId}.',
            sourcePath: ownerPath,
          ),
        );
      }
      if (prefab.kind != PrefabKind.platform) {
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_kind_source_mismatch',
            message:
                'Prefab ${prefab.id} must be a platform to use a platform '
                'module visual source.',
            sourcePath: ownerPath,
          ),
        );
      }
    case PrefabVisualSourceType.unknown:
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_source_type_invalid',
          message: 'Prefab ${prefab.id} has an unsupported visual source.',
          sourcePath: ownerPath,
        ),
      );
  }

  if (prefab.kind != PrefabKind.decoration && visualBounds == null) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_polygon_visual_bounds_unresolved',
        message:
            'Prefab ${prefab.id} visual bounds must resolve before its '
            'metadata can be committed.',
        sourcePath: ownerPath,
      ),
    );
  }
  if (visualBounds != null &&
      (prefab.anchorXPx < 0 ||
          prefab.anchorYPx < 0 ||
          prefab.anchorXPx > visualBounds.widthPx ||
          prefab.anchorYPx > visualBounds.heightPx)) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_anchor_out_of_bounds',
        message:
            'Prefab ${prefab.id} anchor (${prefab.anchorXPx},'
            '${prefab.anchorYPx}) is outside visual bounds '
            '${visualBounds.widthPx}x${visualBounds.heightPx}.',
        sourcePath: ownerPath,
      ),
    );
  }

  issues.addAll(
    validatePrefabCollisionShapes(
      prefabId: prefab.id,
      prefabKey: prefab.prefabKey,
      kind: prefab.kind,
      anchorXPx: prefab.anchorXPx,
      anchorYPx: prefab.anchorYPx,
      collisionShapes: prefab.collisionShapes,
      sourceWidthPx: visualBounds?.widthPx,
      sourceHeightPx: visualBounds?.heightPx,
      sourcePath: ownerPath,
    ),
  );
  issues.sort((left, right) {
    final pathOrder = left.sourcePath.compareTo(right.sourcePath);
    if (pathOrder != 0) return pathOrder;
    final codeOrder = left.code.compareTo(right.code);
    return codeOrder != 0 ? codeOrder : left.message.compareTo(right.message);
  });
  return List<PrefabValidationIssue>.unmodifiable(issues);
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
