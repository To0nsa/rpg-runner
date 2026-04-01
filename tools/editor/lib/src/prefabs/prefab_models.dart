import 'package:flutter/foundation.dart';

const int prefabSchemaVersionV1 = 1;
const int prefabSchemaVersionV2 = 2;
const int currentPrefabSchemaVersion = prefabSchemaVersionV2;

enum AtlasSliceKind { prefab, tile }

enum PrefabKind { obstacle, platform, unknown }

enum PrefabStatus { active, deprecated, unknown }

enum PrefabVisualSourceType { atlasSlice, platformModule, unknown }

PrefabKind parsePrefabKind(String raw) {
  switch (raw.trim()) {
    case 'obstacle':
      return PrefabKind.obstacle;
    case 'platform':
      return PrefabKind.platform;
    default:
      return PrefabKind.unknown;
  }
}

PrefabStatus parsePrefabStatus(String raw) {
  switch (raw.trim()) {
    case 'active':
      return PrefabStatus.active;
    case 'deprecated':
      return PrefabStatus.deprecated;
    default:
      return PrefabStatus.unknown;
  }
}

PrefabVisualSourceType parsePrefabVisualSourceType(String raw) {
  switch (raw.trim()) {
    case 'atlas_slice':
      return PrefabVisualSourceType.atlasSlice;
    case 'platform_module':
      return PrefabVisualSourceType.platformModule;
    default:
      return PrefabVisualSourceType.unknown;
  }
}

extension PrefabKindJson on PrefabKind {
  String get jsonValue {
    switch (this) {
      case PrefabKind.obstacle:
        return 'obstacle';
      case PrefabKind.platform:
        return 'platform';
      case PrefabKind.unknown:
        return 'unknown';
    }
  }
}

extension PrefabStatusJson on PrefabStatus {
  String get jsonValue {
    switch (this) {
      case PrefabStatus.active:
        return 'active';
      case PrefabStatus.deprecated:
        return 'deprecated';
      case PrefabStatus.unknown:
        return 'unknown';
    }
  }
}

extension PrefabVisualSourceTypeJson on PrefabVisualSourceType {
  String get jsonValue {
    switch (this) {
      case PrefabVisualSourceType.atlasSlice:
        return 'atlas_slice';
      case PrefabVisualSourceType.platformModule:
        return 'platform_module';
      case PrefabVisualSourceType.unknown:
        return 'unknown';
    }
  }
}

@immutable
class AtlasSliceDef {
  const AtlasSliceDef({
    required this.id,
    required this.sourceImagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String sourceImagePath;
  final int x;
  final int y;
  final int width;
  final int height;

  AtlasSliceDef copyWith({
    String? id,
    String? sourceImagePath,
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    return AtlasSliceDef(
      id: id ?? this.id,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourceImagePath': sourceImagePath,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  static AtlasSliceDef fromJson(Map<String, Object?> json) {
    return AtlasSliceDef(
      id: _normalizedString(json['id']),
      sourceImagePath: _normalizedString(json['sourceImagePath']),
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class PrefabColliderDef {
  const PrefabColliderDef({
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final int offsetX;
  final int offsetY;
  final int width;
  final int height;

  PrefabColliderDef copyWith({
    int? offsetX,
    int? offsetY,
    int? width,
    int? height,
  }) {
    return PrefabColliderDef(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': width,
      'height': height,
    };
  }

  static PrefabColliderDef fromJson(Map<String, Object?> json) {
    return PrefabColliderDef(
      offsetX: (json['offsetX'] as num?)?.toInt() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class PrefabVisualSource {
  const PrefabVisualSource._({
    required this.type,
    this.sliceId = '',
    this.moduleId = '',
  });

  const PrefabVisualSource.atlasSlice(String sliceId)
    : this._(type: PrefabVisualSourceType.atlasSlice, sliceId: sliceId);

  const PrefabVisualSource.platformModule(String moduleId)
    : this._(type: PrefabVisualSourceType.platformModule, moduleId: moduleId);

  const PrefabVisualSource.unknown({String sliceId = '', String moduleId = ''})
    : this._(
        type: PrefabVisualSourceType.unknown,
        sliceId: sliceId,
        moduleId: moduleId,
      );

  final PrefabVisualSourceType type;
  final String sliceId;
  final String moduleId;

  bool get isAtlasSlice => type == PrefabVisualSourceType.atlasSlice;
  bool get isPlatformModule => type == PrefabVisualSourceType.platformModule;
  bool get isUnknown => type == PrefabVisualSourceType.unknown;

  String get atlasSliceId => isAtlasSlice ? sliceId : '';
  String get platformModuleId => isPlatformModule ? moduleId : '';
  String get referenceId => isAtlasSlice ? sliceId : moduleId;

  PrefabVisualSource copyWith({
    PrefabVisualSourceType? type,
    String? sliceId,
    String? moduleId,
  }) {
    final nextType = type ?? this.type;
    return PrefabVisualSource._(
      type: nextType,
      sliceId: nextType == PrefabVisualSourceType.atlasSlice
          ? (sliceId ?? this.sliceId)
          : '',
      moduleId: nextType == PrefabVisualSourceType.platformModule
          ? (moduleId ?? this.moduleId)
          : '',
    );
  }

  Map<String, Object?> toJson() {
    switch (type) {
      case PrefabVisualSourceType.atlasSlice:
        return <String, Object?>{'type': type.jsonValue, 'sliceId': sliceId};
      case PrefabVisualSourceType.platformModule:
        return <String, Object?>{'type': type.jsonValue, 'moduleId': moduleId};
      case PrefabVisualSourceType.unknown:
        return <String, Object?>{'type': type.jsonValue};
    }
  }

  static PrefabVisualSource fromJson(Object? raw, {String legacySliceId = ''}) {
    final json = _asObjectMap(raw);
    if (json == null) {
      if (legacySliceId.isNotEmpty) {
        return PrefabVisualSource.atlasSlice(legacySliceId);
      }
      return const PrefabVisualSource.unknown();
    }

    final type = parsePrefabVisualSourceType(_normalizedString(json['type']));
    switch (type) {
      case PrefabVisualSourceType.atlasSlice:
        final sliceId = _normalizedString(
          json['sliceId'],
          fallback: legacySliceId,
        );
        return PrefabVisualSource.atlasSlice(sliceId);
      case PrefabVisualSourceType.platformModule:
        return PrefabVisualSource.platformModule(
          _normalizedString(json['moduleId']),
        );
      case PrefabVisualSourceType.unknown:
        if (legacySliceId.isNotEmpty) {
          return PrefabVisualSource.atlasSlice(legacySliceId);
        }
        return const PrefabVisualSource.unknown();
    }
  }
}

@immutable
class PrefabDef {
  PrefabDef({
    this.prefabKey = '',
    required this.id,
    this.revision = 1,
    this.status = PrefabStatus.active,
    this.kind = PrefabKind.obstacle,
    PrefabVisualSource? visualSource,
    String? sliceId,
    required this.anchorXPx,
    required this.anchorYPx,
    required this.colliders,
    this.tags = const <String>[],
    this.zIndex = 0,
    this.snapToGrid = true,
  }) : visualSource =
           visualSource ??
           (sliceId == null
               ? const PrefabVisualSource.unknown()
               : PrefabVisualSource.atlasSlice(sliceId));

  final String prefabKey;
  final String id;
  final int revision;
  final PrefabStatus status;
  final PrefabKind kind;
  final PrefabVisualSource visualSource;
  final int anchorXPx;
  final int anchorYPx;
  final List<PrefabColliderDef> colliders;
  final List<String> tags;
  final int zIndex;
  final bool snapToGrid;

  bool get usesAtlasSlice => visualSource.isAtlasSlice;
  bool get usesPlatformModule => visualSource.isPlatformModule;
  String get sliceId => visualSource.atlasSliceId;
  String get moduleId => visualSource.platformModuleId;
  String get sourceRefId => visualSource.referenceId;

  PrefabDef copyWith({
    String? prefabKey,
    String? id,
    int? revision,
    PrefabStatus? status,
    PrefabKind? kind,
    PrefabVisualSource? visualSource,
    String? sliceId,
    int? anchorXPx,
    int? anchorYPx,
    List<PrefabColliderDef>? colliders,
    List<String>? tags,
    int? zIndex,
    bool? snapToGrid,
  }) {
    final nextVisualSource =
        visualSource ??
        (sliceId != null
            ? PrefabVisualSource.atlasSlice(sliceId)
            : this.visualSource);
    return PrefabDef(
      prefabKey: prefabKey ?? this.prefabKey,
      id: id ?? this.id,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      visualSource: nextVisualSource,
      anchorXPx: anchorXPx ?? this.anchorXPx,
      anchorYPx: anchorYPx ?? this.anchorYPx,
      colliders: colliders ?? this.colliders,
      tags: tags ?? this.tags,
      zIndex: zIndex ?? this.zIndex,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }

  PrefabDef renamed(String nextId) {
    return copyWith(id: nextId);
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'prefabKey': prefabKey,
      'id': id,
      'revision': revision,
      'status': status.jsonValue,
      'kind': kind.jsonValue,
      'visualSource': visualSource.toJson(),
      'anchorXPx': anchorXPx,
      'anchorYPx': anchorYPx,
      'colliders': colliders.map((c) => c.toJson()).toList(growable: false),
      'tags': tags,
      'zIndex': zIndex,
      'snapToGrid': snapToGrid,
    };
  }

  static PrefabDef fromJson(Map<String, Object?> json) {
    final rawColliders = json['colliders'];
    final colliders = <PrefabColliderDef>[];
    if (rawColliders is List<Object?>) {
      for (final value in rawColliders) {
        final colliderJson = _asObjectMap(value);
        if (colliderJson == null) {
          continue;
        }
        colliders.add(PrefabColliderDef.fromJson(colliderJson));
      }
    }

    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List<Object?>) {
      for (final value in rawTags) {
        if (value is! String) {
          continue;
        }
        final normalized = value.trim();
        if (normalized.isEmpty) {
          continue;
        }
        tags.add(normalized);
      }
    }

    final legacySliceId = _normalizedString(json['sliceId']);
    return PrefabDef(
      prefabKey: _normalizedString(json['prefabKey']),
      id: _normalizedString(json['id']),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      status: parsePrefabStatus(_normalizedString(json['status'])),
      kind: parsePrefabKind(_normalizedString(json['kind'])),
      visualSource: PrefabVisualSource.fromJson(
        json['visualSource'],
        legacySliceId: legacySliceId,
      ),
      anchorXPx: (json['anchorXPx'] as num?)?.toInt() ?? 0,
      anchorYPx: (json['anchorYPx'] as num?)?.toInt() ?? 0,
      colliders: colliders,
      tags: tags,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      snapToGrid: (json['snapToGrid'] as bool?) ?? true,
    );
  }
}

@immutable
class TileModuleCellDef {
  const TileModuleCellDef({
    required this.sliceId,
    required this.gridX,
    required this.gridY,
  });

  final String sliceId;
  final int gridX;
  final int gridY;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sliceId': sliceId,
      'gridX': gridX,
      'gridY': gridY,
    };
  }

  static TileModuleCellDef fromJson(Map<String, Object?> json) {
    return TileModuleCellDef(
      sliceId: _normalizedString(json['sliceId']),
      gridX: (json['gridX'] as num?)?.toInt() ?? 0,
      gridY: (json['gridY'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class TileModuleDef {
  const TileModuleDef({
    required this.id,
    required this.tileSize,
    required this.cells,
  });

  final String id;
  final int tileSize;
  final List<TileModuleCellDef> cells;

  TileModuleDef copyWith({
    String? id,
    int? tileSize,
    List<TileModuleCellDef>? cells,
  }) {
    return TileModuleDef(
      id: id ?? this.id,
      tileSize: tileSize ?? this.tileSize,
      cells: cells ?? this.cells,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'tileSize': tileSize,
      'cells': cells.map((c) => c.toJson()).toList(growable: false),
    };
  }

  static TileModuleDef fromJson(Map<String, Object?> json) {
    final rawCells = json['cells'];
    final cells = <TileModuleCellDef>[];
    if (rawCells is List<Object?>) {
      for (final value in rawCells) {
        final cellJson = _asObjectMap(value);
        if (cellJson == null) {
          continue;
        }
        cells.add(TileModuleCellDef.fromJson(cellJson));
      }
    }
    return TileModuleDef(
      id: _normalizedString(json['id']),
      tileSize: (json['tileSize'] as num?)?.toInt() ?? 16,
      cells: cells,
    );
  }
}

@immutable
class PrefabData {
  const PrefabData({
    this.schemaVersion = currentPrefabSchemaVersion,
    this.prefabSlices = const <AtlasSliceDef>[],
    this.tileSlices = const <AtlasSliceDef>[],
    this.prefabs = const <PrefabDef>[],
    this.platformModules = const <TileModuleDef>[],
  });

  final int schemaVersion;
  final List<AtlasSliceDef> prefabSlices;
  final List<AtlasSliceDef> tileSlices;
  final List<PrefabDef> prefabs;
  final List<TileModuleDef> platformModules;

  PrefabData copyWith({
    int? schemaVersion,
    List<AtlasSliceDef>? prefabSlices,
    List<AtlasSliceDef>? tileSlices,
    List<PrefabDef>? prefabs,
    List<TileModuleDef>? platformModules,
  }) {
    return PrefabData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      prefabSlices: prefabSlices ?? this.prefabSlices,
      tileSlices: tileSlices ?? this.tileSlices,
      prefabs: prefabs ?? this.prefabs,
      platformModules: platformModules ?? this.platformModules,
    );
  }
}

String _normalizedString(Object? raw, {String fallback = ''}) {
  if (raw is String) {
    return raw.trim();
  }
  return fallback;
}

Map<String, Object?>? _asObjectMap(Object? raw) {
  if (raw is! Map<Object?, Object?>) {
    return null;
  }
  final mapped = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      continue;
    }
    mapped[key] = entry.value;
  }
  return mapped;
}
