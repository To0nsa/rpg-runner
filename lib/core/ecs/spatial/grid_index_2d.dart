import '../../math/vec2.dart';

class CellAabb {
  const CellAabb({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  /// World space minimum X coordinate of the cell.
  final double minX;

  /// World space minimum Y coordinate of the cell.
  final double minY;

  /// World space maximum X coordinate of the cell.
  final double maxX;

  /// World space maximum Y coordinate of the cell.
  final double maxY;
}

/// Generic 2D grid math + hashing utility.
///
/// This is intentionally reusable for both:
/// - dynamic broadphase buckets (Milestone 9), and
/// - future nav/cost grids (later milestone).
///
/// IMPORTANT (determinism):
/// - `cellKey(cx, cy)` must be stable and must not use Dart `hashCode`.
class GridIndex2D {
  GridIndex2D({required this.cellSize}) : invCellSize = 1.0 / cellSize;

  /// The width/height of a single square grid cell in world units.
  final double cellSize;

  /// Precomputed `1.0 / cellSize` to avoid divisions in tight loops.
  final double invCellSize;

  /// Converts world X coordinate to grid cell X index.
  /// Uses floor() to handle negative coordinates correctly.
  int worldToCellX(double x) => (x * invCellSize).floor();

  /// Converts world Y coordinate to grid cell Y index.
  int worldToCellY(double y) => (y * invCellSize).floor();

  /// returns the top-left (min) world position of the cell at [cx], [cy].
  Vec2 cellToWorldMin(int cx, int cy) => Vec2(cx * cellSize, cy * cellSize);

  CellAabb cellAabb(int cx, int cy) {
    final minX = cx * cellSize;
    final minY = cy * cellSize;
    return CellAabb(
      minX: minX,
      minY: minY,
      maxX: minX + cellSize,
      maxY: minY + cellSize,
    );
  }

  /// Packs signed (cx, cy) into a single int key (two 32-bit lanes).
  ///
  /// The key is constructed by placing `cy` in the upper 32 bits and `cx` in the
  /// lower 32 bits.
  ///
  /// **Platform Note**: This logic relies on Dart's 64-bit integers (VM/Native).
  /// On the web, where `int` is a double and bitwise operations are 32-bit,
  /// this will lose data (collisions) for keys requiring >32 bits.
  /// For cross-platform safety use a String key or customized class, or ensure
  /// coordinates fit in 16 bits (packed to 32).
  int cellKey(int cx, int cy) {
    // Mask to 32 bits to treat as unsigned for packing, then shift.
    return ((cy & 0xFFFFFFFF) << 32) | (cx & 0xFFFFFFFF);
  }

  /// Iterates 4 neighbors (or 8 if [diagonal] is true) around [cx], [cy].
  ///
  /// Order is guaranteed for determinism:
  /// 1. Cardinals: N, W, E, S
  /// 2. Diagonals (if enabled): NW, NE, SW, SE
  void forNeighbors(
    int cx,
    int cy, {
    bool diagonal = false,
    required void Function(int nx, int ny) visit,
  }) {
    // Stable order (N, W, E, S), then diagonals (NW, NE, SW, SE).
    visit(cx, cy - 1); // North
    visit(cx - 1, cy); // West
    visit(cx + 1, cy); // East
    visit(cx, cy + 1); // South

    if (!diagonal) return;
    
    visit(cx - 1, cy - 1); // NW
    visit(cx + 1, cy - 1); // NE
    visit(cx - 1, cy + 1); // SW
    visit(cx + 1, cy + 1); // SE
  }
}

