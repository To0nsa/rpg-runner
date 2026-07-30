import '../prefabs/models/models.dart';

/// Rectangle-era prefab payload retained only by the one-time migration path.
///
/// Normal authoring models must not depend on this type once prefab schema v3
/// becomes active. Keeping the legacy record here lets the read-only migration
/// checker retain its exact input semantics while normal prefab collision moves
/// to polygon source.
final class LegacyPrefabDef {
  LegacyPrefabDef({
    this.prefabKey = '',
    required this.id,
    required this.revision,
    required this.status,
    required this.kind,
    required this.visualSource,
    required this.anchorXPx,
    required this.anchorYPx,
    required Iterable<PrefabColliderDef> colliders,
    required Iterable<String> tags,
  }) : colliders = List<PrefabColliderDef>.unmodifiable(colliders),
       tags = List<String>.unmodifiable(tags);

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

  LegacyPrefabDef copyWith({String? prefabKey}) => LegacyPrefabDef(
    prefabKey: prefabKey ?? this.prefabKey,
    id: id,
    revision: revision,
    status: status,
    kind: kind,
    visualSource: visualSource,
    anchorXPx: anchorXPx,
    anchorYPx: anchorYPx,
    colliders: colliders,
    tags: tags,
  );
}

/// Minimal aggregate input required by the deterministic migration planner.
final class LegacyPrefabData {
  LegacyPrefabData({
    required this.schemaVersion,
    required Iterable<AtlasSliceDef> prefabSlices,
    required Iterable<LegacyPrefabDef> prefabs,
  }) : prefabSlices = List<AtlasSliceDef>.unmodifiable(prefabSlices),
       prefabs = List<LegacyPrefabDef>.unmodifiable(prefabs);

  final int schemaVersion;
  final List<AtlasSliceDef> prefabSlices;
  final List<LegacyPrefabDef> prefabs;

  LegacyPrefabData copyWith({List<LegacyPrefabDef>? prefabs}) =>
      LegacyPrefabData(
        schemaVersion: schemaVersion,
        prefabSlices: prefabSlices,
        prefabs: prefabs ?? this.prefabs,
      );
}

/// Total order matching canonical prefab-v2 source ordering.
int compareLegacyPrefabDefs(LegacyPrefabDef left, LegacyPrefabDef right) {
  var order = left.id.compareTo(right.id);
  if (order != 0) return order;
  order = left.prefabKey.compareTo(right.prefabKey);
  if (order != 0) return order;
  order = left.revision.compareTo(right.revision);
  if (order != 0) return order;
  order = left.status.index.compareTo(right.status.index);
  if (order != 0) return order;
  order = left.kind.index.compareTo(right.kind.index);
  if (order != 0) return order;
  order = _compareVisualSource(left.visualSource, right.visualSource);
  if (order != 0) return order;
  order = left.anchorXPx.compareTo(right.anchorXPx);
  if (order != 0) return order;
  order = left.anchorYPx.compareTo(right.anchorYPx);
  if (order != 0) return order;
  order = _compareStrings(left.tags, right.tags);
  if (order != 0) return order;
  return _compareColliders(left.colliders, right.colliders);
}

int _compareVisualSource(PrefabVisualSource left, PrefabVisualSource right) {
  var order = left.type.index.compareTo(right.type.index);
  if (order != 0) return order;
  order = left.sliceId.compareTo(right.sliceId);
  return order != 0 ? order : left.moduleId.compareTo(right.moduleId);
}

int _compareStrings(List<String> left, List<String> right) {
  var order = left.length.compareTo(right.length);
  if (order != 0) return order;
  for (var index = 0; index < left.length; index++) {
    order = left[index].compareTo(right[index]);
    if (order != 0) return order;
  }
  return 0;
}

int _compareColliders(
  List<PrefabColliderDef> left,
  List<PrefabColliderDef> right,
) {
  var order = left.length.compareTo(right.length);
  if (order != 0) return order;
  for (var index = 0; index < left.length; index++) {
    final leftCollider = left[index];
    final rightCollider = right[index];
    order = leftCollider.offsetY.compareTo(rightCollider.offsetY);
    if (order != 0) return order;
    order = leftCollider.offsetX.compareTo(rightCollider.offsetX);
    if (order != 0) return order;
    order = leftCollider.width.compareTo(rightCollider.width);
    if (order != 0) return order;
    order = leftCollider.height.compareTo(rightCollider.height);
    if (order != 0) return order;
  }
  return 0;
}
