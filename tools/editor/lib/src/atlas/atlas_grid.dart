import 'atlas_pixel_rect.dart';

/// Transient auto-slice grid configuration in source-image pixels.
final class AtlasGridSettings {
  const AtlasGridSettings({
    this.cellWidth = 32,
    this.cellHeight = 32,
    this.originX = 0,
    this.originY = 0,
    this.gutterX = 0,
    this.gutterY = 0,
  }) : assert(cellWidth > 0),
       assert(cellHeight > 0),
       assert(originX >= 0),
       assert(originY >= 0),
       assert(gutterX >= 0),
       assert(gutterY >= 0);

  final int cellWidth;
  final int cellHeight;
  final int originX;
  final int originY;
  final int gutterX;
  final int gutterY;

  int get strideX => cellWidth + gutterX;
  int get strideY => cellHeight + gutterY;

  AtlasGridSettings copyWith({
    int? cellWidth,
    int? cellHeight,
    int? originX,
    int? originY,
    int? gutterX,
    int? gutterY,
  }) => AtlasGridSettings(
    cellWidth: cellWidth ?? this.cellWidth,
    cellHeight: cellHeight ?? this.cellHeight,
    originX: originX ?? this.originX,
    originY: originY ?? this.originY,
    gutterX: gutterX ?? this.gutterX,
    gutterY: gutterY ?? this.gutterY,
  );

  @override
  bool operator ==(Object other) =>
      other is AtlasGridSettings &&
      cellWidth == other.cellWidth &&
      cellHeight == other.cellHeight &&
      originX == other.originX &&
      originY == other.originY &&
      gutterX == other.gutterX &&
      gutterY == other.gutterY;

  @override
  int get hashCode =>
      Object.hash(cellWidth, cellHeight, originX, originY, gutterX, gutterY);
}

/// Complete grid cell address; partial trailing cells are never represented.
final class AtlasGridCell {
  const AtlasGridCell({required this.column, required this.row});

  final int column;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is AtlasGridCell && column == other.column && row == other.row;

  @override
  int get hashCode => Object.hash(column, row);
}

/// Deterministic half-open grid calculations shared by every atlas workflow.
abstract final class AtlasGridGeometry {
  static int completeColumnCount({
    required AtlasGridSettings settings,
    required int imageWidth,
  }) => _completeCellCount(
    available: imageWidth - settings.originX,
    cellSize: settings.cellWidth,
    gutter: settings.gutterX,
  );

  static int completeRowCount({
    required AtlasGridSettings settings,
    required int imageHeight,
  }) => _completeCellCount(
    available: imageHeight - settings.originY,
    cellSize: settings.cellHeight,
    gutter: settings.gutterY,
  );

  static AtlasGridCell? hitTest({
    required AtlasGridSettings settings,
    required int imageWidth,
    required int imageHeight,
    required double x,
    required double y,
  }) {
    if (x < settings.originX ||
        y < settings.originY ||
        x >= imageWidth ||
        y >= imageHeight) {
      return null;
    }
    final localX = x - settings.originX;
    final localY = y - settings.originY;
    final column = localX ~/ settings.strideX;
    final row = localY ~/ settings.strideY;
    final withinCellX = localX - (column * settings.strideX);
    final withinCellY = localY - (row * settings.strideY);
    if (withinCellX >= settings.cellWidth ||
        withinCellY >= settings.cellHeight) {
      return null;
    }
    if (column >=
            completeColumnCount(settings: settings, imageWidth: imageWidth) ||
        row >= completeRowCount(settings: settings, imageHeight: imageHeight)) {
      return null;
    }
    return AtlasGridCell(column: column, row: row);
  }

  static AtlasPixelRect rectForRange({
    required AtlasGridSettings settings,
    required AtlasGridCell first,
    required AtlasGridCell second,
  }) {
    final leftColumn = first.column < second.column
        ? first.column
        : second.column;
    final rightColumn = first.column > second.column
        ? first.column
        : second.column;
    final topRow = first.row < second.row ? first.row : second.row;
    final bottomRow = first.row > second.row ? first.row : second.row;
    final x = settings.originX + (leftColumn * settings.strideX);
    final y = settings.originY + (topRow * settings.strideY);
    return AtlasPixelRect(
      x: x,
      y: y,
      width:
          ((rightColumn - leftColumn) * settings.strideX) + settings.cellWidth,
      height: ((bottomRow - topRow) * settings.strideY) + settings.cellHeight,
    );
  }

  static int _completeCellCount({
    required int available,
    required int cellSize,
    required int gutter,
  }) {
    if (available < cellSize) return 0;
    return 1 + ((available - cellSize) ~/ (cellSize + gutter));
  }
}

/// Stateful drag adapter that ignores gutters and retains the last valid cell.
final class AtlasGridDragController {
  AtlasGridCell? _start;
  AtlasGridCell? _last;

  bool get isActive => _start != null;

  AtlasPixelRect? begin({
    required AtlasGridSettings settings,
    required int imageWidth,
    required int imageHeight,
    required double x,
    required double y,
  }) {
    final cell = AtlasGridGeometry.hitTest(
      settings: settings,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      x: x,
      y: y,
    );
    _start = cell;
    _last = cell;
    return cell == null
        ? null
        : AtlasGridGeometry.rectForRange(
            settings: settings,
            first: cell,
            second: cell,
          );
  }

  AtlasPixelRect? update({
    required AtlasGridSettings settings,
    required int imageWidth,
    required int imageHeight,
    required double x,
    required double y,
  }) {
    final start = _start;
    if (start == null) return null;
    final hit = AtlasGridGeometry.hitTest(
      settings: settings,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      x: x,
      y: y,
    );
    if (hit != null) _last = hit;
    return AtlasGridGeometry.rectForRange(
      settings: settings,
      first: start,
      second: _last ?? start,
    );
  }

  void end() {
    _start = null;
    _last = null;
  }
}
