import 'package:flutter/foundation.dart';

enum AtlasSliceKind { prefab, tile }

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
      id: (json['id'] as String?)?.trim() ?? '',
      sourceImagePath: (json['sourceImagePath'] as String?)?.trim() ?? '',
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
class PrefabDef {
  const PrefabDef({
    required this.id,
    required this.sliceId,
    required this.anchorXPx,
    required this.anchorYPx,
    required this.colliders,
    this.tags = const <String>[],
    this.zIndex = 0,
    this.snapToGrid = true,
  });

  final String id;
  final String sliceId;
  final int anchorXPx;
  final int anchorYPx;
  final List<PrefabColliderDef> colliders;
  final List<String> tags;
  final int zIndex;
  final bool snapToGrid;

  PrefabDef copyWith({
    String? id,
    String? sliceId,
    int? anchorXPx,
    int? anchorYPx,
    List<PrefabColliderDef>? colliders,
    List<String>? tags,
    int? zIndex,
    bool? snapToGrid,
  }) {
    return PrefabDef(
      id: id ?? this.id,
      sliceId: sliceId ?? this.sliceId,
      anchorXPx: anchorXPx ?? this.anchorXPx,
      anchorYPx: anchorYPx ?? this.anchorYPx,
      colliders: colliders ?? this.colliders,
      tags: tags ?? this.tags,
      zIndex: zIndex ?? this.zIndex,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sliceId': sliceId,
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
        if (value is Map<String, Object?>) {
          colliders.add(PrefabColliderDef.fromJson(value));
        }
      }
    }
    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List<Object?>) {
      for (final value in rawTags) {
        if (value is String) {
          final normalized = value.trim();
          if (normalized.isNotEmpty) {
            tags.add(normalized);
          }
        }
      }
    }
    return PrefabDef(
      id: (json['id'] as String?)?.trim() ?? '',
      sliceId: (json['sliceId'] as String?)?.trim() ?? '',
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
      sliceId: (json['sliceId'] as String?)?.trim() ?? '',
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
        if (value is Map<String, Object?>) {
          cells.add(TileModuleCellDef.fromJson(value));
        }
      }
    }
    return TileModuleDef(
      id: (json['id'] as String?)?.trim() ?? '',
      tileSize: (json['tileSize'] as num?)?.toInt() ?? 16,
      cells: cells,
    );
  }
}

@immutable
class PrefabData {
  const PrefabData({
    this.schemaVersion = 1,
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
