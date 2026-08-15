import 'package:flutter/foundation.dart';

import 'entity_domain_models.dart';

/// Numeric equality used by entity gestures, history, dirty state, and export.
///
/// All entity change decisions use this policy so a gesture cannot create an
/// undo entry that the pending/export layers later consider unchanged.
abstract final class EntityNumericPolicy {
  static const double tolerance = 0.000001;

  static bool equal(double left, double right) =>
      (left - right).abs() <= tolerance;

  static bool nullableEqual(double? left, double? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return equal(left, right);
  }

  static bool isEffectivelyZero(double value) => value.abs() <= tolerance;
}

/// Typed editable-field delta between two snapshots of the same entity.
@immutable
class EntityChangeSet {
  const EntityChangeSet({
    required this.halfXChanged,
    required this.halfYChanged,
    required this.offsetXChanged,
    required this.offsetYChanged,
    required this.castOriginOffsetChanged,
    required this.renderScaleChanged,
    required this.anchorXChanged,
    required this.anchorYChanged,
  });

  final bool halfXChanged;
  final bool halfYChanged;
  final bool offsetXChanged;
  final bool offsetYChanged;
  final bool castOriginOffsetChanged;
  final bool renderScaleChanged;
  final bool anchorXChanged;
  final bool anchorYChanged;

  bool get colliderChanged =>
      halfXChanged || halfYChanged || offsetXChanged || offsetYChanged;

  bool get anchorChanged => anchorXChanged || anchorYChanged;

  bool get hasChanges =>
      colliderChanged ||
      castOriginOffsetChanged ||
      renderScaleChanged ||
      anchorChanged;
}

/// Produces the single domain-owned change set consumed by editor layers.
abstract final class EntityChangePolicy {
  static EntityChangeSet between(EntityEntry current, EntityEntry baseline) {
    if (current.id != baseline.id) {
      throw ArgumentError(
        'Entity change comparison requires matching ids '
        '(${current.id} != ${baseline.id}).',
      );
    }

    final currentReference = current.referenceVisual;
    final baselineReference = baseline.referenceVisual;
    return EntityChangeSet(
      halfXChanged: !EntityNumericPolicy.equal(current.halfX, baseline.halfX),
      halfYChanged: !EntityNumericPolicy.equal(current.halfY, baseline.halfY),
      offsetXChanged: !EntityNumericPolicy.equal(
        current.offsetX,
        baseline.offsetX,
      ),
      offsetYChanged: !EntityNumericPolicy.equal(
        current.offsetY,
        baseline.offsetY,
      ),
      castOriginOffsetChanged: !EntityNumericPolicy.nullableEqual(
        current.castOriginOffset,
        baseline.castOriginOffset,
      ),
      renderScaleChanged: !EntityNumericPolicy.nullableEqual(
        currentReference?.renderScale,
        baselineReference?.renderScale,
      ),
      anchorXChanged: !EntityNumericPolicy.nullableEqual(
        currentReference?.anchorXPx,
        baselineReference?.anchorXPx,
      ),
      anchorYChanged: !EntityNumericPolicy.nullableEqual(
        currentReference?.anchorYPx,
        baselineReference?.anchorYPx,
      ),
    );
  }
}
