import 'dart:ui' show Offset;

import 'atlas_pixel_rect.dart';

/// Transient selection state shared by atlas authoring workflows.
final class AtlasSelectionState {
  const AtlasSelectionState({
    this.selectedSourcePath,
    this.zoom = 2,
    this.startImagePixels,
    this.currentImagePixels,
  });

  final String? selectedSourcePath;
  final double zoom;
  final Offset? startImagePixels;
  final Offset? currentImagePixels;

  AtlasPixelRect? get selectionRect {
    final start = startImagePixels;
    final current = currentImagePixels;
    if (start == null || current == null) return null;
    final left = (start.dx < current.dx ? start.dx : current.dx).floor();
    final top = (start.dy < current.dy ? start.dy : current.dy).floor();
    final right = (start.dx > current.dx ? start.dx : current.dx).ceil();
    final bottom = (start.dy > current.dy ? start.dy : current.dy).ceil();
    if (right <= left || bottom <= top) return null;
    return AtlasPixelRect(
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  AtlasSelectionState withSelectedSourcePath(String? path) =>
      AtlasSelectionState(
        selectedSourcePath: path,
        zoom: zoom,
        startImagePixels: startImagePixels,
        currentImagePixels: currentImagePixels,
      );

  AtlasSelectionState withZoom(double value) => AtlasSelectionState(
    selectedSourcePath: selectedSourcePath,
    zoom: value,
    startImagePixels: startImagePixels,
    currentImagePixels: currentImagePixels,
  );

  AtlasSelectionState withDrag(Offset start, Offset current) =>
      AtlasSelectionState(
        selectedSourcePath: selectedSourcePath,
        zoom: zoom,
        startImagePixels: start,
        currentImagePixels: current,
      );

  AtlasSelectionState withRect(AtlasPixelRect rect) => withDrag(
    Offset(rect.x.toDouble(), rect.y.toDouble()),
    Offset(rect.right.toDouble(), rect.bottom.toDouble()),
  );

  AtlasSelectionState clearedSelection() =>
      AtlasSelectionState(selectedSourcePath: selectedSourcePath, zoom: zoom);
}

/// Converts viewport coordinates into bounded source-image pixels.
Offset atlasImagePosition({
  required Offset localPosition,
  required double zoom,
  required int imageWidth,
  required int imageHeight,
}) => Offset(
  (localPosition.dx / zoom).clamp(0, imageWidth.toDouble()),
  (localPosition.dy / zoom).clamp(0, imageHeight.toDouble()),
);
