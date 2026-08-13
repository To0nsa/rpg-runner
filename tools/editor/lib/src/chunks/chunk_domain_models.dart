import 'package:meta/meta.dart';

const String chunkStatusActive = 'active';
const String chunkStatusDeprecated = 'deprecated';
const String chunkDifficultyEarly = 'early';
const String chunkDifficultyEasy = 'easy';
const String chunkDifficultyNormal = 'normal';
const String chunkDifficultyHard = 'hard';
const String defaultChunkAssemblyGroupId = 'default';
const String markerPlacementGround = 'ground';
const String markerPlacementHighestSurfaceAtX = 'highestSurfaceAtX';
const String markerPlacementObstacleTop = 'obstacleTop';
const double defaultPrefabPlacementScale = 1.0;
const double minPrefabPlacementScale = 0.3;
const double maxPrefabPlacementScale = 3.0;
const double prefabPlacementScaleStep = 0.1;

final RegExp stableChunkAssemblyGroupPattern = RegExp(r'^[a-z][a-z0-9_]*$');

@immutable
class ChunkKey {
  const ChunkKey(this.value);

  final String value;

  bool get isEmpty => value.isEmpty;

  bool get isValid => _chunkKeyPattern.hasMatch(value);

  static final RegExp _chunkKeyPattern = RegExp(r'^[a-z0-9_]+$');
}

@immutable
class TileLayerDef {
  const TileLayerDef({
    required this.id,
    this.kind = 'visual',
    this.visible = true,
  });

  final String id;
  final String kind;
  final bool visible;

  TileLayerDef copyWith({String? id, String? kind, bool? visible}) {
    return TileLayerDef(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      visible: visible ?? this.visible,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'kind': kind, 'visible': visible};
  }

  static TileLayerDef fromJson(Map<String, Object?> json) {
    return TileLayerDef(
      id: _normalizedString(json['id']),
      kind: _normalizedString(json['kind'], fallback: 'visual'),
      visible: _boolOrDefault(json['visible'], fallback: true),
    );
  }
}

@immutable
class PlacedPrefabDef {
  const PlacedPrefabDef({
    required this.prefabId,
    this.prefabKey = '',
    required this.x,
    required this.y,
    this.zIndex = 0,
    this.snapToGrid = true,
    this.scale = defaultPrefabPlacementScale,
    this.flipX = false,
    this.flipY = false,
  });

  final String prefabId;
  final String prefabKey;
  final int x;
  final int y;
  final int zIndex;
  final bool snapToGrid;
  final double scale;
  final bool flipX;
  final bool flipY;

  String get resolvedPrefabRef => prefabKey.isNotEmpty ? prefabKey : prefabId;

  PlacedPrefabDef copyWith({
    String? prefabId,
    String? prefabKey,
    int? x,
    int? y,
    int? zIndex,
    bool? snapToGrid,
    double? scale,
    bool? flipX,
    bool? flipY,
  }) {
    return PlacedPrefabDef(
      prefabId: prefabId ?? this.prefabId,
      prefabKey: prefabKey ?? this.prefabKey,
      x: x ?? this.x,
      y: y ?? this.y,
      zIndex: zIndex ?? this.zIndex,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      scale: scale ?? this.scale,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'prefabId': prefabId,
      if (prefabKey.isNotEmpty) 'prefabKey': prefabKey,
      'x': x,
      'y': y,
      'zIndex': zIndex,
      'snapToGrid': snapToGrid,
      if (!_isDefaultPrefabPlacementScale(scale))
        'scale': _canonicalPrefabPlacementScale(scale),
      if (flipX) 'flipX': true,
      if (flipY) 'flipY': true,
    };
    return json;
  }

  static PlacedPrefabDef fromJson(Map<String, Object?> json) {
    final parsedPrefabKey = _normalizedString(json['prefabKey']);
    final parsedPrefabId = _normalizedString(
      json['prefabId'],
      fallback: parsedPrefabKey,
    );
    return PlacedPrefabDef(
      prefabId: parsedPrefabId,
      prefabKey: parsedPrefabKey,
      x: _intOrDefault(json['x'], fallback: 0),
      y: _intOrDefault(json['y'], fallback: 0),
      zIndex: _intOrDefault(json['zIndex'], fallback: 0),
      snapToGrid: _boolOrDefault(json['snapToGrid'], fallback: true),
      scale: _doubleOrDefault(
        json['scale'],
        fallback: defaultPrefabPlacementScale,
      ),
      flipX: _boolOrDefault(json['flipX'], fallback: false),
      flipY: _boolOrDefault(json['flipY'], fallback: false),
    );
  }
}

int comparePlacedPrefabsDeterministic(PlacedPrefabDef a, PlacedPrefabDef b) {
  final zCompare = a.zIndex.compareTo(b.zIndex);
  if (zCompare != 0) {
    return zCompare;
  }
  final yCompare = a.y.compareTo(b.y);
  if (yCompare != 0) {
    return yCompare;
  }
  final xCompare = a.x.compareTo(b.x);
  if (xCompare != 0) {
    return xCompare;
  }
  final refCompare = a.resolvedPrefabRef.compareTo(b.resolvedPrefabRef);
  if (refCompare != 0) {
    return refCompare;
  }
  final snapCompare = _compareBool(a.snapToGrid, b.snapToGrid);
  if (snapCompare != 0) {
    return snapCompare;
  }
  final scaleCompare = a.scale.compareTo(b.scale);
  if (scaleCompare != 0) {
    return scaleCompare;
  }
  final flipXCompare = _compareBool(a.flipX, b.flipX);
  if (flipXCompare != 0) {
    return flipXCompare;
  }
  final flipYCompare = _compareBool(a.flipY, b.flipY);
  if (flipYCompare != 0) {
    return flipYCompare;
  }
  return a.prefabId.compareTo(b.prefabId);
}

int comparePlacedMarkersDeterministic(PlacedMarkerDef a, PlacedMarkerDef b) {
  final yCompare = a.y.compareTo(b.y);
  if (yCompare != 0) {
    return yCompare;
  }
  final xCompare = a.x.compareTo(b.x);
  if (xCompare != 0) {
    return xCompare;
  }
  final markerIdCompare = a.markerId.compareTo(b.markerId);
  if (markerIdCompare != 0) {
    return markerIdCompare;
  }
  final placementCompare = a.placement.compareTo(b.placement);
  if (placementCompare != 0) {
    return placementCompare;
  }
  final chanceCompare = a.chancePercent.compareTo(b.chancePercent);
  if (chanceCompare != 0) {
    return chanceCompare;
  }
  return a.salt.compareTo(b.salt);
}

@immutable
class ChunkPlacedPrefabSelection {
  const ChunkPlacedPrefabSelection({
    required this.selectionKey,
    required this.sourceIndex,
    required this.ordinalAtLocation,
    required this.prefab,
  });

  final String selectionKey;
  final int sourceIndex;
  final int ordinalAtLocation;
  final PlacedPrefabDef prefab;
}

List<ChunkPlacedPrefabSelection> buildChunkPlacedPrefabSelections(
  Iterable<PlacedPrefabDef> prefabs,
) {
  final sortedPrefabs = List<PlacedPrefabDef>.from(prefabs)
    ..sort(comparePlacedPrefabsDeterministic);
  final locationOrdinals = <String, int>{};
  return sortedPrefabs.indexed
      .map((entry) {
        final (sourceIndex, prefab) = entry;
        final locationKey = _placedPrefabLocationKey(prefab);
        final ordinal = locationOrdinals[locationKey] ?? 0;
        locationOrdinals[locationKey] = ordinal + 1;
        return ChunkPlacedPrefabSelection(
          selectionKey: buildChunkPlacedPrefabSelectionKey(
            prefab.resolvedPrefabRef,
            x: prefab.x,
            y: prefab.y,
            ordinalAtLocation: ordinal,
          ),
          sourceIndex: sourceIndex,
          ordinalAtLocation: ordinal,
          prefab: prefab,
        );
      })
      .toList(growable: false);
}

String buildChunkPlacedPrefabSelectionKey(
  String resolvedPrefabRef, {
  required int x,
  required int y,
  required int ordinalAtLocation,
}) {
  return '$resolvedPrefabRef|$x|$y|$ordinalAtLocation';
}

String _placedPrefabLocationKey(PlacedPrefabDef prefab) {
  return '${prefab.resolvedPrefabRef}|${prefab.x}|${prefab.y}';
}

@immutable
class ChunkPlacedMarkerSelection {
  const ChunkPlacedMarkerSelection({
    required this.selectionKey,
    required this.sourceIndex,
    required this.ordinalAtLocation,
    required this.marker,
  });

  final String selectionKey;
  final int sourceIndex;
  final int ordinalAtLocation;
  final PlacedMarkerDef marker;
}

List<ChunkPlacedMarkerSelection> buildChunkPlacedMarkerSelections(
  Iterable<PlacedMarkerDef> markers,
) {
  final sortedMarkers = List<PlacedMarkerDef>.from(markers)
    ..sort(comparePlacedMarkersDeterministic);
  final locationOrdinals = <String, int>{};
  return sortedMarkers.indexed
      .map((entry) {
        final (sourceIndex, marker) = entry;
        final locationKey = _placedMarkerLocationKey(marker);
        final ordinal = locationOrdinals[locationKey] ?? 0;
        locationOrdinals[locationKey] = ordinal + 1;
        return ChunkPlacedMarkerSelection(
          selectionKey: buildChunkPlacedMarkerSelectionKey(
            marker.markerId,
            x: marker.x,
            y: marker.y,
            ordinalAtLocation: ordinal,
          ),
          sourceIndex: sourceIndex,
          ordinalAtLocation: ordinal,
          marker: marker,
        );
      })
      .toList(growable: false);
}

String buildChunkPlacedMarkerSelectionKey(
  String markerId, {
  required int x,
  required int y,
  required int ordinalAtLocation,
}) {
  return '$markerId|$x|$y|$ordinalAtLocation';
}

String _placedMarkerLocationKey(PlacedMarkerDef marker) {
  return '${marker.markerId}|${marker.x}|${marker.y}';
}

@immutable
class PlacedMarkerDef {
  const PlacedMarkerDef({
    required this.markerId,
    required this.x,
    required this.y,
    this.chancePercent = 100,
    this.salt = 0,
    this.placement = markerPlacementGround,
  });

  final String markerId;
  final int x;
  final int y;
  final int chancePercent;
  final int salt;
  final String placement;

  PlacedMarkerDef copyWith({
    String? markerId,
    int? x,
    int? y,
    int? chancePercent,
    int? salt,
    String? placement,
  }) {
    return PlacedMarkerDef(
      markerId: markerId ?? this.markerId,
      x: x ?? this.x,
      y: y ?? this.y,
      chancePercent: chancePercent ?? this.chancePercent,
      salt: salt ?? this.salt,
      placement: placement ?? this.placement,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'markerId': markerId,
      'x': x,
      'y': y,
      'chancePercent': chancePercent,
      'salt': salt,
      'placement': placement,
    };
  }

  static PlacedMarkerDef fromJson(Map<String, Object?> json) {
    return PlacedMarkerDef(
      markerId: _normalizedString(json['markerId']),
      x: _intOrDefault(json['x'], fallback: 0),
      y: _intOrDefault(json['y'], fallback: 0),
      chancePercent: _intOrDefault(json['chancePercent'], fallback: 100),
      salt: _intOrDefault(json['salt'], fallback: 0),
      placement: _normalizedString(
        json['placement'],
        fallback: markerPlacementGround,
      ),
    );
  }
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    final normalized = raw.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}

int _intOrDefault(Object? raw, {required int fallback}) {
  if (raw is num) {
    return raw.toInt();
  }
  return fallback;
}

bool _boolOrDefault(Object? raw, {required bool fallback}) {
  if (raw is bool) {
    return raw;
  }
  return fallback;
}

double _doubleOrDefault(Object? raw, {required double fallback}) {
  if (raw is num) {
    return raw.toDouble();
  }
  return fallback;
}

double canonicalPrefabPlacementScale(double value) {
  return _canonicalPrefabPlacementScale(value);
}

bool isPrefabPlacementScaleInRange(double value) {
  return value >= minPrefabPlacementScale && value <= maxPrefabPlacementScale;
}

bool isPrefabPlacementScaleStepAligned(double value) {
  final aligned =
      (value / prefabPlacementScaleStep).roundToDouble() *
      prefabPlacementScaleStep;
  return (value - aligned).abs() < 1e-9;
}

double clampPrefabPlacementScale(double value) {
  if (value < minPrefabPlacementScale) {
    return minPrefabPlacementScale;
  }
  if (value > maxPrefabPlacementScale) {
    return maxPrefabPlacementScale;
  }
  return value;
}

double stepPrefabPlacementScale(double value) {
  final aligned =
      (value / prefabPlacementScaleStep).roundToDouble() *
      prefabPlacementScaleStep;
  return _canonicalPrefabPlacementScale(aligned);
}

double normalizePrefabPlacementScale(
  double value, {
  double fallback = defaultPrefabPlacementScale,
}) {
  if (!value.isFinite) {
    return fallback;
  }
  return stepPrefabPlacementScale(clampPrefabPlacementScale(value));
}

bool _isDefaultPrefabPlacementScale(double value) {
  return (value - defaultPrefabPlacementScale).abs() < 1e-9;
}

double _canonicalPrefabPlacementScale(double value) {
  return double.parse(value.toStringAsFixed(2));
}

int _compareBool(bool a, bool b) {
  if (a == b) {
    return 0;
  }
  return a ? 1 : -1;
}
