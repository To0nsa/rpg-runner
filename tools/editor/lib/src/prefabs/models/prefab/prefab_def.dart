import 'package:flutter/foundation.dart';

import '../shared/model_json_utils.dart';
import '../shared/prefab_enums.dart';
import 'prefab_collider_def.dart';
import 'prefab_visual_source.dart';

/// Authoring definition for one placeable prefab.
///
/// Anchor/collider coordinates are stored in pixels relative to the authored
/// visual source geometry.
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

  /// Backward-compatible alias for atlas-slice prefabs.
  String get sliceId => visualSource.atlasSliceId;

  /// Backward-compatible alias for module-backed platform prefabs.
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

  /// Serializes to the canonical prefab JSON payload shape.
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

  /// Parses one prefab definition, tolerating legacy `sliceId` records.
  static PrefabDef fromJson(Map<String, Object?> json) {
    final rawColliders = json['colliders'];
    final colliders = <PrefabColliderDef>[];
    if (rawColliders is List<Object?>) {
      for (final value in rawColliders) {
        final colliderJson = PrefabModelJson.asObjectMap(value);
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

    final legacySliceId = PrefabModelJson.normalizedString(json['sliceId']);
    return PrefabDef(
      prefabKey: PrefabModelJson.normalizedString(json['prefabKey']),
      id: PrefabModelJson.normalizedString(json['id']),
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      status: parsePrefabStatus(
        PrefabModelJson.normalizedString(json['status']),
      ),
      kind: parsePrefabKind(PrefabModelJson.normalizedString(json['kind'])),
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
