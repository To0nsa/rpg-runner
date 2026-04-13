part of 'prefab_validation.dart';

/// Validates prefab records against slice/module lookup indexes.
void _validatePrefabs({
  required List<PrefabValidationIssue> issues,
  required List<PrefabDef> prefabs,
  required Set<String> prefabSliceIds,
  required Map<String, AtlasSliceDef> prefabSliceById,
  required Set<String> moduleIds,
  required Map<String, TileModuleDef> moduleById,
  required Map<String, AtlasSliceDef> tileSliceById,
}) {
  final prefabIds = <String>{};
  final prefabKeys = <String>{};

  for (final prefab in prefabs) {
    final prefabLabel = _prefabLabel(prefab);
    if (prefab.id.isEmpty) {
      issues.add(
        const PrefabValidationIssue(
          code: 'prefab_id_missing',
          message: 'Prefab with empty id.',
        ),
      );
    } else if (!prefabIds.add(prefab.id)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_id_duplicate',
          message: 'Duplicate prefab id: ${prefab.id}',
        ),
      );
    }

    if (prefab.prefabKey.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_key_missing',
          message: 'Prefab $prefabLabel has empty prefabKey.',
        ),
      );
    } else if (!prefabKeys.add(prefab.prefabKey)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_key_duplicate',
          message: 'Duplicate prefab key: ${prefab.prefabKey}',
        ),
      );
    }

    if (prefab.revision <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_revision_invalid',
          message:
              'Prefab $prefabLabel has invalid revision ${prefab.revision}.',
        ),
      );
    }

    if (prefab.status == PrefabStatus.unknown) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_status_invalid',
          message: 'Prefab $prefabLabel has unsupported status.',
        ),
      );
    }

    if (prefab.kind == PrefabKind.unknown) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_kind_invalid',
          message: 'Prefab $prefabLabel has unsupported kind.',
        ),
      );
    }

    final source = prefab.visualSource;
    _SourceGeometry? sourceGeometry;
    switch (source.type) {
      case PrefabVisualSourceType.atlasSlice:
        if (source.sliceId.isEmpty) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_slice_id_missing',
              message: 'Prefab $prefabLabel has empty atlas slice source id.',
            ),
          );
        } else if (!prefabSliceIds.contains(source.sliceId)) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_slice_missing',
              message:
                  'Prefab ${prefab.id} references missing prefab slice ${source.sliceId}.',
            ),
          );
        } else {
          final slice = prefabSliceById[source.sliceId];
          if (slice != null) {
            sourceGeometry = _SourceGeometry(
              widthPx: slice.width,
              heightPx: slice.height,
              snapUnitPx: 1,
            );
          }
        }
        if (prefab.kind == PrefabKind.platform) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_kind_source_mismatch',
              message:
                  'Prefab $prefabLabel has incompatible kind/source '
                  '(platform + atlas_slice).',
            ),
          );
        }
      case PrefabVisualSourceType.platformModule:
        if (source.moduleId.isEmpty) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_module_id_missing',
              message:
                  'Prefab $prefabLabel has empty platform module source id.',
            ),
          );
        } else if (!moduleIds.contains(source.moduleId)) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_source_module_missing',
              message:
                  'Prefab ${prefab.id} references missing platform module ${source.moduleId}.',
            ),
          );
        } else {
          sourceGeometry = _geometryForModule(
            moduleById[source.moduleId]!,
            tileSliceById: tileSliceById,
          );
        }
        if (prefab.kind == PrefabKind.obstacle) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_kind_source_mismatch',
              message:
                  'Prefab $prefabLabel has incompatible kind/source '
                  '(obstacle + platform_module).',
            ),
          );
        } else if (prefab.kind == PrefabKind.decoration) {
          issues.add(
            PrefabValidationIssue(
              code: 'prefab_kind_source_mismatch',
              message:
                  'Prefab $prefabLabel has incompatible kind/source '
                  '(decoration + platform_module).',
            ),
          );
        }
      case PrefabVisualSourceType.unknown:
        issues.add(
          PrefabValidationIssue(
            code: 'prefab_source_type_invalid',
            message: 'Prefab $prefabLabel has unsupported visual source type.',
          ),
        );
    }

    _validatePrefabTags(issues: issues, prefab: prefab);
    _validatePrefabAnchorAndColliders(
      issues: issues,
      prefab: prefab,
      sourceGeometry: sourceGeometry,
    );
  }
}

/// Chooses a stable identifier for human-readable validation messages.
String _prefabLabel(PrefabDef prefab) {
  if (prefab.id.isNotEmpty) {
    return prefab.id;
  }
  if (prefab.prefabKey.isNotEmpty) {
    return prefab.prefabKey;
  }
  return '(unidentified prefab)';
}

/// Validates tag normalization constraints used by deterministic serialization.
void _validatePrefabTags({
  required List<PrefabValidationIssue> issues,
  required PrefabDef prefab,
}) {
  final seenTags = <String>{};
  for (var i = 0; i < prefab.tags.length; i += 1) {
    final rawTag = prefab.tags[i];
    final normalized = rawTag.trim();
    if (normalized.isEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_empty',
          message: 'Prefab ${prefab.id} has empty tag at index $i.',
        ),
      );
      continue;
    }
    if (normalized != rawTag) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_whitespace',
          message:
              'Prefab ${prefab.id} tag "$rawTag" must not contain leading/trailing whitespace.',
        ),
      );
    }
    if (!seenTags.add(normalized)) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_tag_duplicate',
          message: 'Prefab ${prefab.id} has duplicate tag "$normalized".',
        ),
      );
    }
  }
}

/// Validates prefab anchor/collider geometry against its resolved visual source.
void _validatePrefabAnchorAndColliders({
  required List<PrefabValidationIssue> issues,
  required PrefabDef prefab,
  required _SourceGeometry? sourceGeometry,
}) {
  final prefabId = prefab.id;
  final anchorX = prefab.anchorXPx;
  final anchorY = prefab.anchorYPx;
  final snapUnitPx = sourceGeometry?.snapUnitPx ?? 1;

  if (sourceGeometry != null) {
    if (anchorX < 0 ||
        anchorY < 0 ||
        anchorX > sourceGeometry.widthPx ||
        anchorY > sourceGeometry.heightPx) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_anchor_out_of_bounds',
          message:
              'Prefab $prefabId has anchor ($anchorX,$anchorY) outside source bounds '
              '${sourceGeometry.widthPx}x${sourceGeometry.heightPx}.',
        ),
      );
    }
  }

  if (prefab.kind == PrefabKind.decoration) {
    if (prefab.colliders.isNotEmpty) {
      issues.add(
        PrefabValidationIssue(
          code: 'decoration_prefab_collider_forbidden',
          message:
              'Prefab $prefabId is decoration and must not include colliders.',
        ),
      );
    }
    return;
  }

  if (prefab.kind == PrefabKind.platform && snapUnitPx > 1) {
    if (!_isSnappedToUnit(anchorX, snapUnitPx) ||
        !_isSnappedToUnit(anchorY, snapUnitPx)) {
      issues.add(
        PrefabValidationIssue(
          code: 'platform_anchor_snap_invalid',
          message:
              'Prefab $prefabId anchor must be snapped to module tileSize $snapUnitPx.',
        ),
      );
    }

    for (var i = 0; i < prefab.colliders.length; i += 1) {
      final collider = prefab.colliders[i];
      if (!_isSnappedToUnit(collider.offsetX, snapUnitPx) ||
          !_isSnappedToUnit(collider.offsetY, snapUnitPx) ||
          !_isSnappedToUnit(collider.width, snapUnitPx) ||
          !_isSnappedToUnit(collider.height, snapUnitPx)) {
        issues.add(
          PrefabValidationIssue(
            code: 'platform_collider_snap_invalid',
            message:
                'Prefab $prefabId collider[$i] must be snapped to module tileSize '
                '$snapUnitPx.',
          ),
        );
      }
    }
  }

  if (prefab.colliders.isEmpty) {
    issues.add(
      PrefabValidationIssue(
        code: 'prefab_collider_missing',
        message: 'Prefab $prefabId must include at least one collider.',
      ),
    );
    return;
  }

  var hasColliderInsideSource = false;
  for (final collider in prefab.colliders) {
    if (collider.width <= 0 || collider.height <= 0) {
      issues.add(
        PrefabValidationIssue(
          code: 'prefab_collider_size_invalid',
          message: 'Prefab $prefabId has collider with non-positive size.',
        ),
      );
      continue;
    }

    if (sourceGeometry != null &&
        _colliderIntersectsSource(
          collider: collider,
          anchorX: anchorX,
          anchorY: anchorY,
          sourceWidthPx: sourceGeometry.widthPx,
          sourceHeightPx: sourceGeometry.heightPx,
        )) {
      hasColliderInsideSource = true;
    }
  }

  if (sourceGeometry != null && !hasColliderInsideSource) {
    final code = switch (prefab.kind) {
      PrefabKind.obstacle => 'obstacle_collider_outside_source',
      PrefabKind.platform => 'platform_collider_outside_source',
      PrefabKind.decoration => 'decoration_collider_outside_source',
      PrefabKind.unknown => 'prefab_collider_outside_source',
    };
    issues.add(
      PrefabValidationIssue(
        code: code,
        message:
            'Prefab $prefabId colliders do not intersect its authored source bounds.',
      ),
    );
  }
}

bool _isSnappedToUnit(int value, int unit) {
  if (unit <= 1) {
    return true;
  }
  return value % unit == 0;
}
