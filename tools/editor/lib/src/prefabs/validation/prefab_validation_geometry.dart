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
  if (module.cells.isEmpty || module.tileSize <= 0) {
    return null;
  }

  final tileSize = module.tileSize.toDouble();
  double? minLeft;
  double? minTop;
  double? maxRight;
  double? maxBottom;
  for (final cell in module.cells) {
    final slice = tileSliceById[cell.sliceId];
    final width = math.max(1, slice?.width ?? module.tileSize).toDouble();
    final height = math.max(1, slice?.height ?? module.tileSize).toDouble();
    final left = cell.gridX * tileSize;
    final top = cell.gridY * tileSize;
    final right = left + width;
    final bottom = top + height;

    minLeft = minLeft == null ? left : math.min(minLeft, left);
    minTop = minTop == null ? top : math.min(minTop, top);
    maxRight = maxRight == null ? right : math.max(maxRight, right);
    maxBottom = maxBottom == null ? bottom : math.max(maxBottom, bottom);
  }

  if (minLeft == null ||
      minTop == null ||
      maxRight == null ||
      maxBottom == null) {
    return null;
  }

  final widthPx = (maxRight - minLeft).round();
  final heightPx = (maxBottom - minTop).round();
  if (widthPx <= 0 || heightPx <= 0) {
    return null;
  }

  return _SourceGeometry(
    widthPx: widthPx,
    heightPx: heightPx,
    snapUnitPx: module.tileSize,
  );
}
