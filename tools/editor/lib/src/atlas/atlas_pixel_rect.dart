/// Immutable source-image rectangle expressed in whole pixels.
///
/// Invalid or incomplete form input must remain outside this value: origins
/// are non-negative and dimensions are always positive.
final class AtlasPixelRect {
  const AtlasPixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  }) : assert(x >= 0),
       assert(y >= 0),
       assert(width > 0),
       assert(height > 0);

  final int x;
  final int y;
  final int width;
  final int height;

  int get right => x + width;
  int get bottom => y + height;

  bool fitsWithin({required int imageWidth, required int imageHeight}) =>
      imageWidth > 0 &&
      imageHeight > 0 &&
      right <= imageWidth &&
      bottom <= imageHeight;

  @override
  bool operator ==(Object other) =>
      other is AtlasPixelRect &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'AtlasPixelRect($x, $y, $width, $height)';
}

/// Result of strict manual source-rectangle parsing.
final class AtlasPixelRectParseResult {
  const AtlasPixelRectParseResult({required this.rect, required this.error});

  final AtlasPixelRect? rect;
  final String? error;

  bool get isValid => rect != null && error == null;
}

/// Parses `X/Y/W/H` without silently clamping authored values.
AtlasPixelRectParseResult parseAtlasPixelRect({
  required String rawX,
  required String rawY,
  required String rawWidth,
  required String rawHeight,
  required int imageWidth,
  required int imageHeight,
  bool allowEmpty = true,
}) {
  final values = <String>[
    rawX.trim(),
    rawY.trim(),
    rawWidth.trim(),
    rawHeight.trim(),
  ];
  if (values.every((value) => value.isEmpty)) {
    return AtlasPixelRectParseResult(
      rect: null,
      error: allowEmpty ? null : 'Define a source rectangle first.',
    );
  }
  final parsed = values.map(int.tryParse).toList(growable: false);
  if (parsed.any((value) => value == null)) {
    return const AtlasPixelRectParseResult(
      rect: null,
      error: 'Selection X/Y/W/H must be valid integers.',
    );
  }
  final x = parsed[0]!;
  final y = parsed[1]!;
  final width = parsed[2]!;
  final height = parsed[3]!;
  if (x < 0 || y < 0) {
    return const AtlasPixelRectParseResult(
      rect: null,
      error: 'Selection X/Y must be non-negative.',
    );
  }
  if (width <= 0 || height <= 0) {
    return const AtlasPixelRectParseResult(
      rect: null,
      error: 'Selection width/height must be positive.',
    );
  }
  if (imageWidth <= 0 || imageHeight <= 0) {
    return const AtlasPixelRectParseResult(
      rect: null,
      error: 'Atlas has invalid dimensions.',
    );
  }
  final rect = AtlasPixelRect(x: x, y: y, width: width, height: height);
  if (!rect.fitsWithin(imageWidth: imageWidth, imageHeight: imageHeight)) {
    return const AtlasPixelRectParseResult(
      rect: null,
      error: 'Selection rectangle exceeds atlas bounds.',
    );
  }
  return AtlasPixelRectParseResult(rect: rect, error: null);
}
