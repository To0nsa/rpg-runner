import 'package:meta/meta.dart';

import '../chunk_domain_models.dart';

const int legacyChunkSchemaVersion = 1;
const String groundProfileKindFlat = 'flat';
const String groundGapTypePit = 'pit';
const int defaultLockedChunkHeight = 270;
const int defaultRuntimeGroundTopY = 224;

enum ChunkDifficulty { early, easy, normal, hard }

enum ChunkStatus { active, deprecated }

enum GroundProfileKind { flat }

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
    case chunkDifficultyEarly:
      return ChunkDifficulty.early;
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
    this.schemaVersion = legacyChunkSchemaVersion,
    required this.levelId,
    required this.tileSize,
    required this.width,
    required this.height,
    required this.difficulty,
    this.assemblyGroupId = defaultChunkAssemblyGroupId,
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
  final String assemblyGroupId;
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
    String? assemblyGroupId,
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
      assemblyGroupId: assemblyGroupId ?? this.assemblyGroupId,
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
      ..sort(comparePlacedMarkersDeterministic);

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
      assemblyGroupId: _normalizedString(
        assemblyGroupId,
        fallback: defaultChunkAssemblyGroupId,
      ),
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
      'assemblyGroupId': normalizedChunk.assemblyGroupId,
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
        fallback: legacyChunkSchemaVersion,
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
      assemblyGroupId: _normalizedString(
        json['assemblyGroupId'],
        fallback: defaultChunkAssemblyGroupId,
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
