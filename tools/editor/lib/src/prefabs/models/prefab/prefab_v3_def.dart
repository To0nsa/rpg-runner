import 'package:meta/meta.dart';

import '../../../terrain_authoring/terrain_source_models.dart';
import '../shared/prefab_enums.dart';
import 'prefab_visual_source.dart';

/// Normal prefab-schema-v3 record with polygon collision source.
///
/// Collision coordinates are exact half-pixel ticks relative to the existing
/// whole-pixel prefab anchor. Construction snapshots but does not reorder the
/// supplied shapes or vertices; strict codecs and validation must diagnose
/// noncanonical source instead of silently normalizing it.
@immutable
final class PrefabV3Def {
  PrefabV3Def({
    required this.prefabKey,
    required this.id,
    required this.revision,
    required this.status,
    required this.kind,
    required this.visualSource,
    required this.anchorXPx,
    required this.anchorYPx,
    required Iterable<TerrainSourceShapeDef> collisionShapes,
    required Iterable<String> tags,
  }) : collisionShapes = List<TerrainSourceShapeDef>.unmodifiable(
         collisionShapes,
       ),
       tags = List<String>.unmodifiable(tags);

  final String prefabKey;
  final String id;
  final int revision;
  final PrefabStatus status;
  final PrefabKind kind;
  final PrefabVisualSource visualSource;
  final int anchorXPx;
  final int anchorYPx;
  final List<TerrainSourceShapeDef> collisionShapes;
  final List<String> tags;

  bool get usesAtlasSlice => visualSource.isAtlasSlice;
  bool get usesPlatformModule => visualSource.isPlatformModule;
  String get sliceId => visualSource.atlasSliceId;
  String get moduleId => visualSource.platformModuleId;
  String get sourceRefId => visualSource.referenceId;

  PrefabV3Def copyWith({
    String? prefabKey,
    String? id,
    int? revision,
    PrefabStatus? status,
    PrefabKind? kind,
    PrefabVisualSource? visualSource,
    int? anchorXPx,
    int? anchorYPx,
    Iterable<TerrainSourceShapeDef>? collisionShapes,
    Iterable<String>? tags,
  }) => PrefabV3Def(
    prefabKey: prefabKey ?? this.prefabKey,
    id: id ?? this.id,
    revision: revision ?? this.revision,
    status: status ?? this.status,
    kind: kind ?? this.kind,
    visualSource: visualSource ?? this.visualSource,
    anchorXPx: anchorXPx ?? this.anchorXPx,
    anchorYPx: anchorYPx ?? this.anchorYPx,
    collisionShapes: collisionShapes ?? this.collisionShapes,
    tags: tags ?? this.tags,
  );

  PrefabV3Def renamed(String nextId) => copyWith(id: nextId);

  Map<String, Object> toJson() => <String, Object>{
    'prefabKey': prefabKey,
    'id': id,
    'revision': revision,
    'status': status.jsonValue,
    'kind': kind.jsonValue,
    'visualSource': visualSource.toJson(),
    'anchorXPx': anchorXPx,
    'anchorYPx': anchorYPx,
    'collisionShapes': terrainSourceShapesToJson(collisionShapes),
    'tags': tags,
  };

  @override
  bool operator ==(Object other) =>
      other is PrefabV3Def &&
      prefabKey == other.prefabKey &&
      id == other.id &&
      revision == other.revision &&
      status == other.status &&
      kind == other.kind &&
      _visualSourcesEqual(visualSource, other.visualSource) &&
      anchorXPx == other.anchorXPx &&
      anchorYPx == other.anchorYPx &&
      _listsEqual(collisionShapes, other.collisionShapes) &&
      _listsEqual(tags, other.tags);

  @override
  int get hashCode => Object.hash(
    prefabKey,
    id,
    revision,
    status,
    kind,
    visualSource.type,
    visualSource.sliceId,
    visualSource.moduleId,
    anchorXPx,
    anchorYPx,
    Object.hashAll(collisionShapes),
    Object.hashAll(tags),
  );
}

bool _visualSourcesEqual(PrefabVisualSource left, PrefabVisualSource right) =>
    left.type == right.type &&
    left.sliceId == right.sliceId &&
    left.moduleId == right.moduleId;

bool _listsEqual<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
