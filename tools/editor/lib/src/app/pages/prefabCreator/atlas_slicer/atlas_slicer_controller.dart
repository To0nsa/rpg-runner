import 'package:flutter/material.dart';

import '../../../../prefabs/models/atlas/atlas_slice_kind.dart';

/// Atlas-slicer geometry shared by the current prefab-v3 catalog workspace.
class AtlasSlicerController {
  const AtlasSlicerController();

  Offset toImagePosition({
    required AtlasSlicerState state,
    required Offset localPosition,
    required Size imageSize,
  }) {
    final x = (localPosition.dx / state.zoom).clamp(0.0, imageSize.width);
    final y = (localPosition.dy / state.zoom).clamp(0.0, imageSize.height);
    return Offset(x, y);
  }

  Rect? selectionRectInImagePixels(AtlasSlicerState state) {
    final start = state.selectionStartImagePx;
    final current = state.selectionCurrentImagePx;
    if (start == null || current == null) {
      return null;
    }
    final rect = Rect.fromPoints(start, current);
    final left = rect.left.floorToDouble();
    final top = rect.top.floorToDouble();
    final right = rect.right.ceilToDouble();
    final bottom = rect.bottom.ceilToDouble();
    final width = right - left;
    final height = bottom - top;
    if (width <= 0 || height <= 0) {
      return null;
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  AtlasSlicerSelectionInputResult clampedSelectionFromInputs({
    required Size atlasSize,
    required String rawX,
    required String rawY,
    required String rawW,
    required String rawH,
  }) {
    final x = int.tryParse(rawX.trim());
    final y = int.tryParse(rawY.trim());
    final w = int.tryParse(rawW.trim());
    final h = int.tryParse(rawH.trim());
    if (x == null || y == null || w == null || h == null) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection X/Y/W/H must be valid integers.',
      );
    }
    if (w <= 0 || h <= 0) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection width/height must be positive.',
      );
    }
    final maxWidth = atlasSize.width.toInt();
    final maxHeight = atlasSize.height.toInt();
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Atlas has invalid size.',
      );
    }
    final clampedX = x.clamp(0, maxWidth - 1);
    final clampedY = y.clamp(0, maxHeight - 1);
    final availableWidth = maxWidth - clampedX;
    final availableHeight = maxHeight - clampedY;
    final clampedW = w.clamp(1, availableWidth);
    final clampedH = h.clamp(1, availableHeight);
    return AtlasSlicerSelectionInputResult(
      rect: Rect.fromLTWH(
        clampedX.toDouble(),
        clampedY.toDouble(),
        clampedW.toDouble(),
        clampedH.toDouble(),
      ),
      error: null,
    );
  }

  AtlasSlicerSelectionInputResult strictSelectionFromInputs({
    required Size atlasSize,
    required String rawX,
    required String rawY,
    required String rawW,
    required String rawH,
  }) {
    final hasAnyInput =
        rawX.trim().isNotEmpty ||
        rawY.trim().isNotEmpty ||
        rawW.trim().isNotEmpty ||
        rawH.trim().isNotEmpty;
    if (!hasAnyInput) {
      return const AtlasSlicerSelectionInputResult(rect: null, error: null);
    }

    final x = int.tryParse(rawX.trim());
    final y = int.tryParse(rawY.trim());
    final w = int.tryParse(rawW.trim());
    final h = int.tryParse(rawH.trim());
    if (x == null || y == null || w == null || h == null) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection X/Y/W/H must be valid integers.',
      );
    }
    if (w <= 0 || h <= 0) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection width/height must be positive.',
      );
    }
    final maxWidth = atlasSize.width.toInt();
    final maxHeight = atlasSize.height.toInt();
    if (x < 0 || y < 0 || x >= maxWidth || y >= maxHeight) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection X/Y must stay inside atlas bounds.',
      );
    }
    if (x + w > maxWidth || y + h > maxHeight) {
      return const AtlasSlicerSelectionInputResult(
        rect: null,
        error: 'Selection rectangle exceeds atlas bounds.',
      );
    }
    return AtlasSlicerSelectionInputResult(
      rect: Rect.fromLTWH(
        x.toDouble(),
        y.toDouble(),
        w.toDouble(),
        h.toDouble(),
      ),
      error: null,
    );
  }
}

@immutable
class AtlasSlicerState {
  const AtlasSlicerState({
    this.selectedAtlasPath,
    this.selectedSliceKind = AtlasSliceKind.prefab,
    this.zoom = 2.0,
    this.selectionStartImagePx,
    this.selectionCurrentImagePx,
  });

  final String? selectedAtlasPath;
  final AtlasSliceKind selectedSliceKind;
  final double zoom;
  final Offset? selectionStartImagePx;
  final Offset? selectionCurrentImagePx;

  AtlasSlicerState withSelectedAtlasPath(String? path) {
    return AtlasSlicerState(
      selectedAtlasPath: path,
      selectedSliceKind: selectedSliceKind,
      zoom: zoom,
      selectionStartImagePx: selectionStartImagePx,
      selectionCurrentImagePx: selectionCurrentImagePx,
    );
  }

  AtlasSlicerState withSelectedSliceKind(AtlasSliceKind kind) {
    return AtlasSlicerState(
      selectedAtlasPath: selectedAtlasPath,
      selectedSliceKind: kind,
      zoom: zoom,
      selectionStartImagePx: selectionStartImagePx,
      selectionCurrentImagePx: selectionCurrentImagePx,
    );
  }

  AtlasSlicerState withZoom(double nextZoom) {
    return AtlasSlicerState(
      selectedAtlasPath: selectedAtlasPath,
      selectedSliceKind: selectedSliceKind,
      zoom: nextZoom,
      selectionStartImagePx: selectionStartImagePx,
      selectionCurrentImagePx: selectionCurrentImagePx,
    );
  }

  AtlasSlicerState withSelection(Offset start, Offset current) {
    return AtlasSlicerState(
      selectedAtlasPath: selectedAtlasPath,
      selectedSliceKind: selectedSliceKind,
      zoom: zoom,
      selectionStartImagePx: start,
      selectionCurrentImagePx: current,
    );
  }

  AtlasSlicerState withSelectionRect(Rect rect) {
    return withSelection(rect.topLeft, rect.bottomRight);
  }

  AtlasSlicerState clearedSelection() {
    return AtlasSlicerState(
      selectedAtlasPath: selectedAtlasPath,
      selectedSliceKind: selectedSliceKind,
      zoom: zoom,
    );
  }
}

class AtlasSlicerSelectionInputResult {
  const AtlasSlicerSelectionInputResult({
    required this.rect,
    required this.error,
  });

  final Rect? rect;
  final String? error;
}
