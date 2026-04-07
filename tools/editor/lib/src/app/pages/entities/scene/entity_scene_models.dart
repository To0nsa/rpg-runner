part of '../entities_editor_page.dart';

/// Fallback viewport size used when constraints are unbounded.
const Size _entitySceneDefaultViewportSize = Size(800, 500);

/// Visual radius in logical pixels for collider drag handles.
const double _entityColliderHandleRadius = 6.0;

/// Hit radius in logical pixels for collider handle picking.
const double _entityColliderHandleHitRadius = 14.0;

/// Visual radius in logical pixels for reference anchor handle.
const double _entityAnchorHandleRadius = 4.5;

/// Hit radius in logical pixels for reference anchor picking.
const double _entityAnchorHandleHitRadius = 8.0;

/// Minimum collider half-extent enforced during interactive resize.
const double _entityMinColliderHalfExtent = 1.0;

enum _SceneColliderHandle { center, top, right }

enum _SceneHandleType { colliderCenter, colliderTop, colliderRight, anchor }

extension _SceneHandleTypeMapping on _SceneHandleType {
  static _SceneHandleType fromColliderHandle(_SceneColliderHandle handle) {
    switch (handle) {
      case _SceneColliderHandle.center:
        return _SceneHandleType.colliderCenter;
      case _SceneColliderHandle.top:
        return _SceneHandleType.colliderTop;
      case _SceneColliderHandle.right:
        return _SceneHandleType.colliderRight;
    }
  }

  _SceneColliderHandle toColliderHandle() {
    switch (this) {
      case _SceneHandleType.colliderCenter:
        return _SceneColliderHandle.center;
      case _SceneHandleType.colliderTop:
        return _SceneColliderHandle.top;
      case _SceneHandleType.colliderRight:
        return _SceneColliderHandle.right;
      case _SceneHandleType.anchor:
        throw StateError('Anchor handle does not map to collider handle.');
    }
  }
}

class _SceneHandleDrag {
  /// Immutable drag baseline used to compute deterministic coalesced updates.
  const _SceneHandleDrag({
    required this.pointer,
    required this.entryId,
    required this.handle,
    required this.startLocalPosition,
    required this.scale,
    required this.startHalfX,
    required this.startHalfY,
    required this.startOffsetX,
    required this.startOffsetY,
    required this.startAnchorXPx,
    required this.startAnchorYPx,
    required this.referenceFrameWidth,
    required this.referenceFrameHeight,
    required this.referenceRenderScale,
  });

  final int pointer;
  final String entryId;
  final _SceneHandleType handle;
  final Offset startLocalPosition;
  final double scale;
  final double startHalfX;
  final double startHalfY;
  final double startOffsetX;
  final double startOffsetY;
  final double startAnchorXPx;
  final double startAnchorYPx;
  final double referenceFrameWidth;
  final double referenceFrameHeight;
  final double referenceRenderScale;
}

class _ViewportEntityHandles {
  const _ViewportEntityHandles({
    required this.center,
    required this.top,
    required this.right,
  });

  final Offset center;
  final Offset top;
  final Offset right;

  Offset centerFor(_SceneColliderHandle handle) {
    switch (handle) {
      case _SceneColliderHandle.center:
        return center;
      case _SceneColliderHandle.top:
        return top;
      case _SceneColliderHandle.right:
        return right;
    }
  }
}

class _ResolvedReferenceVisual {
  /// Normalized reference visual data used by scene rendering controls.
  const _ResolvedReferenceVisual({
    required this.frameWidth,
    required this.frameHeight,
    required this.renderScale,
    required this.anchorX,
    required this.anchorY,
    required this.defaultAnimKey,
    required this.animViewsByKey,
  });

  final double frameWidth;
  final double frameHeight;
  final double renderScale;
  final double anchorX;
  final double anchorY;
  final String? defaultAnimKey;
  final Map<String, _ResolvedReferenceAnimView> animViewsByKey;

  String? resolveAnimKey(String? preferredKey) {
    if (preferredKey != null && animViewsByKey.containsKey(preferredKey)) {
      return preferredKey;
    }
    final fallbackKey = defaultAnimKey;
    if (fallbackKey != null && animViewsByKey.containsKey(fallbackKey)) {
      return fallbackKey;
    }
    if (animViewsByKey.isEmpty) {
      return null;
    }
    return animViewsByKey.keys.first;
  }
}

class _ResolvedReferenceAnimView {
  const _ResolvedReferenceAnimView({
    required this.key,
    required this.absolutePath,
    required this.displayPath,
    required this.defaultRow,
    required this.defaultFrameStart,
    required this.defaultFrameCount,
    required this.defaultGridColumns,
  });

  final String key;
  final String absolutePath;
  final String displayPath;
  final int defaultRow;
  final int defaultFrameStart;
  final int? defaultFrameCount;
  final int? defaultGridColumns;

  int? get maxFrameIndex {
    final count = defaultFrameCount;
    if (count == null || count <= 0) {
      return null;
    }
    return defaultFrameStart + count - 1;
  }
}
