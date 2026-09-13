import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../collision/terrain/terrain_numeric.dart';
import '../collision/terrain/terrain_polygon.dart';

/// Immutable chunk-local pool, measured in whole world pixels.
///
/// Water is an overlap volume with a horizontal surface; it contributes no
/// solid edges or navigation support. Material selection is presentation only.
final class WaterRegionData {
  factory WaterRegionData({
    required String id,
    required int x,
    required int y,
    required int width,
    required int height,
    required String materialKey,
  }) {
    final key = RegExp(r'^[a-z][a-z0-9_]*$');
    if (!key.hasMatch(id) || !key.hasMatch(materialKey)) {
      throw ArgumentError(
        'Water IDs and material keys must be lowercase keys.',
      );
    }
    if (x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width >
            (terrainMaxAbsPhysicsTicks ~/ terrainPhysicsTicksPerWorldUnit) ||
        y + height >
            (terrainMaxAbsPhysicsTicks ~/ terrainPhysicsTicksPerWorldUnit)) {
      throw ArgumentError(
        'Water bounds must be positive finite pixel rectangles.',
      );
    }
    return WaterRegionData._(id, x, y, width, height, materialKey);
  }

  const WaterRegionData._(
    this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.materialKey,
  );

  final String id;
  final int x;
  final int y;
  final int width;
  final int height;
  final String materialKey;

  /// Canonical source fields; list ordering belongs to the owning chunk codec.
  Map<String, Object> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'materialKey': materialKey,
  };

  @override
  bool operator ==(Object other) =>
      other is WaterRegionData &&
      id == other.id &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height &&
      materialKey == other.materialKey;

  @override
  int get hashCode => Object.hash(id, x, y, width, height, materialKey);
}

/// Digest of ordered water source, independent of solid polygon signatures.
String waterRegionSignature(Iterable<WaterRegionData> regions) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          'water-regions-v1',
          ...regions.map((region) => region.toJson()),
        ]),
      ),
    )
    .toString();

/// Bound pool instance shared by Core overlap queries and immutable snapshots.
///
/// Bounds use 1/1024-world-unit physics ticks. The surface is [topTicks] and
/// remains fixed regardless of transparent or animated surface pixels.
final class WaterRegion {
  WaterRegion({
    required this.sourceId,
    required WaterRegionData data,
    required int worldOriginXTicks,
  }) : leftTicks =
           worldOriginXTicks + physicsCoordinateToTicks(data.x.toDouble()),
       topTicks = physicsCoordinateToTicks(data.y.toDouble()),
       rightTicks =
           worldOriginXTicks +
           physicsCoordinateToTicks((data.x + data.width).toDouble()),
       bottomTicks = physicsCoordinateToTicks(
         (data.y + data.height).toDouble(),
       ),
       materialKey = data.materialKey;

  final TerrainSourceIdentity sourceId;
  final int leftTicks;
  final int topTicks;
  final int rightTicks;
  final int bottomTicks;
  final String materialKey;
}

/// Validates canonical pool ordering, closed chunk bounds and non-overlap.
/// Shared by source decoding and runtime admission, including captured Play.
void validateWaterRegionCollection(
  List<WaterRegionData> regions, {
  required int chunkWidth,
  required int chunkHeight,
}) {
  for (var i = 0; i < regions.length; i++) {
    final region = regions[i];
    if (region.x + region.width > chunkWidth ||
        region.y + region.height > chunkHeight) {
      throw ArgumentError(
        'Water ${region.id} must fit inside the chunk bounds.',
      );
    }
    if (i > 0 && regions[i - 1].id.compareTo(region.id) >= 0) {
      throw ArgumentError('Water IDs must be unique and strictly ascending.');
    }
    for (var j = 0; j < i; j++) {
      final previous = regions[j];
      if (region.x < previous.x + previous.width &&
          region.x + region.width > previous.x &&
          region.y < previous.y + previous.height &&
          region.y + region.height > previous.y) {
        throw ArgumentError(
          'Water ${region.id} overlaps water ${previous.id}.',
        );
      }
    }
  }
}
