import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';
import '../prefabs/models/models.dart';

const int chunkSchemaVersion = 1;
const String chunkStatusActive = 'active';
const String chunkStatusDeprecated = 'deprecated';
const String chunkDifficultyEasy = 'easy';
const String chunkDifficultyNormal = 'normal';
const String chunkDifficultyHard = 'hard';
const String groundProfileKindFlat = 'flat';
const String groundGapTypePit = 'pit';
const int defaultLockedChunkHeight = 270;
const int defaultRuntimeGroundTopY = 224;

enum ChunkDifficulty { easy, normal, hard }

enum ChunkStatus { active, deprecated }

enum GroundProfileKind { flat }

@immutable
class ChunkKey {
  const ChunkKey(this.value);

  final String value;

  bool get isEmpty => value.isEmpty;

  bool get isValid => _chunkKeyPattern.hasMatch(value);

  static final RegExp _chunkKeyPattern = RegExp(r'^[a-z0-9_]+$');
}

@immutable
class GroundGapType {
  const GroundGapType._(this.value);

  final String value;

  static const GroundGapType pit = GroundGapType._(groundGapTypePit);
  static const List<GroundGapType> values = <GroundGapType>[pit];

  static GroundGapType parse(Object? raw) {
    final normalized = _normalizedString(raw, fallback: groundGapTypePit);
    for (final candidate in values) {
      if (candidate.value == normalized) {
        return candidate;
      }
    }
    return GroundGapType._(normalized);
  }
}

ChunkDifficulty parseChunkDifficulty(String raw) {
  switch (raw) {
    case chunkDifficultyEasy:
      return ChunkDifficulty.easy;
    case chunkDifficultyHard:
      return ChunkDifficulty.hard;
    case chunkDifficultyNormal:
    default:
      return ChunkDifficulty.normal;
  }
}

ChunkStatus parseChunkStatus(String raw) {
  switch (raw) {
    case chunkStatusDeprecated:
      return ChunkStatus.deprecated;
    case chunkStatusActive:
    default:
      return ChunkStatus.active;
  }
}

GroundProfileKind parseGroundProfileKind(String raw) {
  switch (raw) {
    case groundProfileKindFlat:
    default:
      return GroundProfileKind.flat;
  }
}

int lockedChunkHeightForViewportHeight(int runtimeViewportHeight) {
  return runtimeViewportHeight > 0
      ? runtimeViewportHeight
      : defaultLockedChunkHeight;
}

LevelChunkDef normalizeChunkToAuthority(
  LevelChunkDef chunk, {
  required double runtimeChunkWidth,
  required int lockedChunkHeight,
  required int runtimeGroundTopY,
}) {
  return chunk
      .copyWith(
        width: runtimeChunkWidth.round(),
        height: lockedChunkHeight,
        groundProfile: chunk.groundProfile.copyWith(
          kind: groundProfileKindFlat,
          topY: runtimeGroundTopY,
        ),
      )
      .normalized();
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
  });

  final String prefabId;
  final String prefabKey;
  final int x;
  final int y;
  final int zIndex;
  final bool snapToGrid;

  String get resolvedPrefabRef => prefabKey.isNotEmpty ? prefabKey : prefabId;

  PlacedPrefabDef copyWith({
    String? prefabId,
    String? prefabKey,
    int? x,
    int? y,
    int? zIndex,
    bool? snapToGrid,
  }) {
    return PlacedPrefabDef(
      prefabId: prefabId ?? this.prefabId,
      prefabKey: prefabKey ?? this.prefabKey,
      x: x ?? this.x,
      y: y ?? this.y,
      zIndex: zIndex ?? this.zIndex,
      snapToGrid: snapToGrid ?? this.snapToGrid,
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
  return a.prefabId.compareTo(b.prefabId);
}

@immutable
class ChunkPlacedPrefabSelection {
  const ChunkPlacedPrefabSelection({
    required this.selectionKey,
    required this.ordinalAtLocation,
    required this.prefab,
  });

  final String selectionKey;
  final int ordinalAtLocation;
  final PlacedPrefabDef prefab;
}

List<ChunkPlacedPrefabSelection> buildChunkPlacedPrefabSelections(
  Iterable<PlacedPrefabDef> prefabs,
) {
  final sortedPrefabs = List<PlacedPrefabDef>.from(prefabs)
    ..sort(comparePlacedPrefabsDeterministic);
  final locationOrdinals = <String, int>{};
  return sortedPrefabs
      .map((prefab) {
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
class PlacedMarkerDef {
  const PlacedMarkerDef({
    required this.markerId,
    required this.x,
    required this.y,
  });

  final String markerId;
  final int x;
  final int y;

  PlacedMarkerDef copyWith({String? markerId, int? x, int? y}) {
    return PlacedMarkerDef(
      markerId: markerId ?? this.markerId,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'markerId': markerId, 'x': x, 'y': y};
  }

  static PlacedMarkerDef fromJson(Map<String, Object?> json) {
    return PlacedMarkerDef(
      markerId: _normalizedString(json['markerId']),
      x: _intOrDefault(json['x'], fallback: 0),
      y: _intOrDefault(json['y'], fallback: 0),
    );
  }
}

@immutable
class GroundProfileDef {
  const GroundProfileDef({this.kind = groundProfileKindFlat, this.topY = 0});

  final String kind;
  final int topY;

  GroundProfileKind get kindValue => parseGroundProfileKind(kind);

  GroundProfileDef copyWith({String? kind, int? topY}) {
    return GroundProfileDef(kind: kind ?? this.kind, topY: topY ?? this.topY);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'kind': kind, 'topY': topY};
  }

  static GroundProfileDef fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return const GroundProfileDef();
    }
    return GroundProfileDef(
      kind: _normalizedString(raw['kind'], fallback: groundProfileKindFlat),
      topY: _intOrDefault(raw['topY'], fallback: 0),
    );
  }
}

@immutable
class GroundGapDef {
  const GroundGapDef({
    required this.gapId,
    this.type = groundGapTypePit,
    required this.x,
    required this.width,
  });

  final String gapId;
  final String type;
  final int x;
  final int width;

  GroundGapType get typeValue => GroundGapType.parse(type);

  GroundGapDef copyWith({String? gapId, String? type, int? x, int? width}) {
    return GroundGapDef(
      gapId: gapId ?? this.gapId,
      type: type ?? this.type,
      x: x ?? this.x,
      width: width ?? this.width,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'gapId': gapId,
      'type': type,
      'x': x,
      'width': width,
    };
  }

  static GroundGapDef fromJson(Map<String, Object?> json) {
    return GroundGapDef(
      gapId: _normalizedString(json['gapId']),
      type: _normalizedString(json['type'], fallback: groundGapTypePit),
      x: _intOrDefault(json['x'], fallback: 0),
      width: _intOrDefault(json['width'], fallback: 0),
    );
  }
}

@immutable
class LevelChunkDef {
  const LevelChunkDef({
    required this.chunkKey,
    required this.id,
    required this.revision,
    this.schemaVersion = chunkSchemaVersion,
    required this.levelId,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.difficulty,
    this.tags = const <String>[],
    this.tileLayers = const <TileLayerDef>[],
    this.prefabs = const <PlacedPrefabDef>[],
    this.markers = const <PlacedMarkerDef>[],
    this.groundProfile = const GroundProfileDef(),
    this.groundBandZIndex = 0,
    this.groundGaps = const <GroundGapDef>[],
    this.status = chunkStatusActive,
  });

  final String chunkKey;
  final String id;
  final int revision;
  final int schemaVersion;
  final String levelId;
  final int tileSize;
  final int width;
  final int height;
  final String difficulty;
  final List<String> tags;
  final List<TileLayerDef> tileLayers;
  final List<PlacedPrefabDef> prefabs;
  final List<PlacedMarkerDef> markers;
  final GroundProfileDef groundProfile;
  /// Chunk-authored scene layer for the visible ground band preview.
  ///
  /// This is owned by chunk composition, not by prefab authoring, so a chunk
  /// can choose whether the floor sits behind props or partially buries them.
  final int groundBandZIndex;
  final List<GroundGapDef> groundGaps;
  final String status;

  ChunkKey get chunkIdentity => ChunkKey(chunkKey);

  ChunkDifficulty get difficultyValue => parseChunkDifficulty(difficulty);

  ChunkStatus get statusValue => parseChunkStatus(status);

  LevelChunkDef copyWith({
    String? chunkKey,
    String? id,
    int? revision,
    int? schemaVersion,
    String? levelId,
    int? tileSize,
    int? width,
    int? height,
    String? difficulty,
    List<String>? tags,
    List<TileLayerDef>? tileLayers,
    List<PlacedPrefabDef>? prefabs,
    List<PlacedMarkerDef>? markers,
    GroundProfileDef? groundProfile,
    int? groundBandZIndex,
    List<GroundGapDef>? groundGaps,
    String? status,
  }) {
    return LevelChunkDef(
      chunkKey: chunkKey ?? this.chunkKey,
      id: id ?? this.id,
      revision: revision ?? this.revision,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      levelId: levelId ?? this.levelId,
      tileSize: tileSize ?? this.tileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      tileLayers: tileLayers ?? this.tileLayers,
      prefabs: prefabs ?? this.prefabs,
      markers: markers ?? this.markers,
      groundProfile: groundProfile ?? this.groundProfile,
      groundBandZIndex: groundBandZIndex ?? this.groundBandZIndex,
      groundGaps: groundGaps ?? this.groundGaps,
      status: status ?? this.status,
    );
  }

  LevelChunkDef normalized() {
    final normalizedTags =
        tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final normalizedLayers = List<TileLayerDef>.from(tileLayers)
      ..sort((a, b) => a.id.compareTo(b.id));

    final normalizedPrefabs = List<PlacedPrefabDef>.from(prefabs)
      ..sort(comparePlacedPrefabsDeterministic);

    final normalizedMarkers = List<PlacedMarkerDef>.from(markers)
      ..sort((a, b) {
        final yCompare = a.y.compareTo(b.y);
        if (yCompare != 0) {
          return yCompare;
        }
        final xCompare = a.x.compareTo(b.x);
        if (xCompare != 0) {
          return xCompare;
        }
        return a.markerId.compareTo(b.markerId);
      });

    final normalizedGaps = List<GroundGapDef>.from(groundGaps)
      ..sort((a, b) {
        final xCompare = a.x.compareTo(b.x);
        if (xCompare != 0) {
          return xCompare;
        }
        final widthCompare = a.width.compareTo(b.width);
        if (widthCompare != 0) {
          return widthCompare;
        }
        return a.gapId.compareTo(b.gapId);
      });

    return copyWith(
      chunkKey: chunkKey.trim(),
      id: id.trim(),
      levelId: levelId.trim(),
      difficulty: difficulty.trim(),
      status: status.trim(),
      tags: normalizedTags,
      tileLayers: normalizedLayers,
      prefabs: normalizedPrefabs,
      markers: normalizedMarkers,
      groundGaps: normalizedGaps,
    );
  }

  Map<String, Object?> toJson() {
    final normalizedChunk = normalized();
    return <String, Object?>{
      'schemaVersion': normalizedChunk.schemaVersion,
      'chunkKey': normalizedChunk.chunkKey,
      'id': normalizedChunk.id,
      'revision': normalizedChunk.revision,
      'status': normalizedChunk.status,
      'levelId': normalizedChunk.levelId,
      'tileSize': normalizedChunk.tileSize,
      'width': normalizedChunk.width,
      'height': normalizedChunk.height,
      'difficulty': normalizedChunk.difficulty,
      'tags': normalizedChunk.tags,
      'tileLayers': normalizedChunk.tileLayers
          .map((layer) => layer.toJson())
          .toList(growable: false),
      'prefabs': normalizedChunk.prefabs
          .map((prefab) => prefab.toJson())
          .toList(growable: false),
      'markers': normalizedChunk.markers
          .map((marker) => marker.toJson())
          .toList(growable: false),
      'groundProfile': normalizedChunk.groundProfile.toJson(),
      if (normalizedChunk.groundBandZIndex != 0)
        'groundBandZIndex': normalizedChunk.groundBandZIndex,
      'groundGaps': normalizedChunk.groundGaps
          .map((gap) => gap.toJson())
          .toList(growable: false),
    };
  }

  static LevelChunkDef fromJson(Map<String, Object?> json) {
    return LevelChunkDef(
      chunkKey: _normalizedString(json['chunkKey']),
      id: _normalizedString(json['id']),
      revision: _intOrDefault(json['revision'], fallback: 1),
      schemaVersion: _intOrDefault(
        json['schemaVersion'],
        fallback: chunkSchemaVersion,
      ),
      status: _normalizedString(json['status'], fallback: chunkStatusActive),
      levelId: _normalizedString(json['levelId']),
      tileSize: _intOrDefault(json['tileSize'], fallback: 16),
      width: _intOrDefault(json['width'], fallback: 600),
      height: _intOrDefault(json['height'], fallback: defaultLockedChunkHeight),
      difficulty: _normalizedString(
        json['difficulty'],
        fallback: chunkDifficultyNormal,
      ),
      tags: _readStringList(json['tags']),
      tileLayers: _readObjectList(json['tileLayers'], TileLayerDef.fromJson),
      prefabs: _readObjectList(json['prefabs'], PlacedPrefabDef.fromJson),
      markers: _readObjectList(json['markers'], PlacedMarkerDef.fromJson),
      groundProfile: GroundProfileDef.fromJson(json['groundProfile']),
      groundBandZIndex: _intOrDefault(json['groundBandZIndex'], fallback: 0),
      groundGaps: _readObjectList(json['groundGaps'], GroundGapDef.fromJson),
    ).normalized();
  }
}

@immutable
class ChunkSourceBaseline {
  const ChunkSourceBaseline({
    required this.sourcePath,
    required this.fingerprint,
  });

  final String sourcePath;
  final String fingerprint;
}

class ChunkDocument extends AuthoringDocument {
  const ChunkDocument({
    required this.chunks,
    required this.baselineByChunkKey,
    required this.availableLevelIds,
    required this.activeLevelId,
    required this.levelOptionSource,
    required this.runtimeGridSnap,
    required this.runtimeChunkWidth,
    this.lockedChunkHeight = defaultLockedChunkHeight,
    this.runtimeGroundTopY = defaultRuntimeGroundTopY,
    this.prefabData = const PrefabData(),
    this.loadIssues = const <ValidationIssue>[],
    this.operationIssues = const <ValidationIssue>[],
  });

  final List<LevelChunkDef> chunks;
  final Map<String, ChunkSourceBaseline> baselineByChunkKey;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final String levelOptionSource;
  final double runtimeGridSnap;
  final double runtimeChunkWidth;
  final int lockedChunkHeight;
  final int runtimeGroundTopY;
  final PrefabData prefabData;
  final List<ValidationIssue> loadIssues;
  final List<ValidationIssue> operationIssues;

  ChunkDocument copyWith({
    List<LevelChunkDef>? chunks,
    Map<String, ChunkSourceBaseline>? baselineByChunkKey,
    List<String>? availableLevelIds,
    String? activeLevelId,
    bool clearActiveLevelId = false,
    String? levelOptionSource,
    double? runtimeGridSnap,
    double? runtimeChunkWidth,
    int? lockedChunkHeight,
    int? runtimeGroundTopY,
    PrefabData? prefabData,
    List<ValidationIssue>? loadIssues,
    List<ValidationIssue>? operationIssues,
    bool clearOperationIssues = false,
  }) {
    return ChunkDocument(
      chunks: chunks ?? this.chunks,
      baselineByChunkKey: baselineByChunkKey ?? this.baselineByChunkKey,
      availableLevelIds: availableLevelIds ?? this.availableLevelIds,
      activeLevelId: clearActiveLevelId
          ? null
          : (activeLevelId ?? this.activeLevelId),
      levelOptionSource: levelOptionSource ?? this.levelOptionSource,
      runtimeGridSnap: runtimeGridSnap ?? this.runtimeGridSnap,
      runtimeChunkWidth: runtimeChunkWidth ?? this.runtimeChunkWidth,
      lockedChunkHeight: lockedChunkHeight ?? this.lockedChunkHeight,
      runtimeGroundTopY: runtimeGroundTopY ?? this.runtimeGroundTopY,
      prefabData: prefabData ?? this.prefabData,
      loadIssues: loadIssues ?? this.loadIssues,
      operationIssues: clearOperationIssues
          ? const <ValidationIssue>[]
          : (operationIssues ?? this.operationIssues),
    );
  }
}

class ChunkScene extends EditableScene {
  const ChunkScene({
    required this.chunks,
    required this.availableLevelIds,
    required this.activeLevelId,
    required this.levelOptionSource,
    required this.sourcePathByChunkKey,
    required this.runtimeGridSnap,
    required this.runtimeChunkWidth,
    required this.lockedChunkHeight,
    required this.runtimeGroundTopY,
    required this.prefabData,
  });

  final List<LevelChunkDef> chunks;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final String levelOptionSource;
  final Map<String, String> sourcePathByChunkKey;
  final double runtimeGridSnap;
  final double runtimeChunkWidth;
  final int lockedChunkHeight;
  final int runtimeGroundTopY;
  final PrefabData prefabData;
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

int _compareBool(bool a, bool b) {
  if (a == b) {
    return 0;
  }
  return a ? 1 : -1;
}

List<String> _readStringList(Object? raw) {
  if (raw is! List<Object?>) {
    return const <String>[];
  }
  final values = <String>[];
  for (final value in raw) {
    final normalized = _normalizedString(value);
    if (normalized.isEmpty) {
      continue;
    }
    values.add(normalized);
  }
  return values;
}

List<T> _readObjectList<T>(
  Object? raw,
  T Function(Map<String, Object?> json) parser,
) {
  if (raw is! List<Object?>) {
    return <T>[];
  }
  final values = <T>[];
  for (final value in raw) {
    if (value is! Map<String, Object?>) {
      continue;
    }
    values.add(parser(value));
  }
  return values;
}
