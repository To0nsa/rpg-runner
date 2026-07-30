part of 'prefab_validation.dart';

/// Resolved source bounds used for anchor/collider validation.
class _SourceGeometry {
  const _SourceGeometry({
    required this.widthPx,
    required this.heightPx,
    required this.snapUnitPx,
  });

  final int widthPx;
  final int heightPx;
  final int snapUnitPx;
}

/// Returns true when collider and source rectangles overlap in prefab-local
/// coordinates.
bool _colliderIntersectsSource({
  required PrefabColliderDef collider,
  required int anchorX,
  required int anchorY,
  required int sourceWidthPx,
  required int sourceHeightPx,
}) {
  final sourceLeft = -anchorX.toDouble();
  final sourceTop = -anchorY.toDouble();
  final sourceRight = (sourceWidthPx - anchorX).toDouble();
  final sourceBottom = (sourceHeightPx - anchorY).toDouble();

  final colliderCenterX = collider.offsetX.toDouble();
  final colliderCenterY = collider.offsetY.toDouble();
  final halfW = collider.width * 0.5;
  final halfH = collider.height * 0.5;
  final colliderLeft = colliderCenterX - halfW;
  final colliderTop = colliderCenterY - halfH;
  final colliderRight = colliderCenterX + halfW;
  final colliderBottom = colliderCenterY + halfH;

  return colliderLeft < sourceRight &&
      colliderRight > sourceLeft &&
      colliderTop < sourceBottom &&
      colliderBottom > sourceTop;
}

/// Derives module source bounds from placed tile cells.
///
/// Cells can use slices with dimensions different from module tile size, so the
/// bounding box uses per-cell slice dimensions when available.
_SourceGeometry? _geometryForModule(
  TileModuleDef module, {
  required Map<String, AtlasSliceDef> tileSliceById,
}) {
  final bounds = PrefabVisualBoundsResolver.resolvePlatformModule(
    module,
    tileSlicesById: tileSliceById,
  );
  if (bounds == null) return null;
  return _SourceGeometry(
    widthPx: bounds.widthPx,
    heightPx: bounds.heightPx,
    snapUnitPx: module.tileSize,
  );
}
