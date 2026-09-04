import '../models/models.dart';
import '../store/prefab_determinism.dart';

/// Resolves the platform prefab that owns a module's collision authoring.
///
/// A module may still feed several legacy/custom prefabs. Automatic lifecycle
/// synchronization is safe only for a sole owner or the conventionally named
/// `<moduleId>_platform` owner; all other variants remain independent.
abstract final class PrefabPlatformPairing {
  /// Returns the conventional human-facing prefab ID for [moduleId].
  static String defaultPrefabId(String moduleId) => '${moduleId}_platform';

  /// Returns every platform prefab that renders [moduleId] in canonical order.
  static List<PrefabV3Def> ownersForModule(
    PrefabV3FileData data,
    String moduleId,
  ) {
    final owners = data.prefabs
        .where(
          (prefab) =>
              prefab.kind == PrefabKind.platform &&
              prefab.usesPlatformModule &&
              prefab.moduleId == moduleId,
        )
        .toList(growable: false);
    owners.sort(PrefabDeterminism.comparePrefabV3ByIdThenKey);
    return owners;
  }

  /// Returns the owner that may be synchronized without choosing arbitrarily.
  static PrefabV3Def? pairedOwner(PrefabV3FileData data, String moduleId) {
    final owners = ownersForModule(data, moduleId);
    if (owners.length == 1) return owners.single;
    final conventionalId = defaultPrefabId(moduleId).toLowerCase();
    final conventional = owners
        .where((owner) => owner.id.toLowerCase() == conventionalId)
        .toList(growable: false);
    return conventional.length == 1 ? conventional.single : null;
  }

  /// Allocates a collision-owner ID without colliding with retained prefabs.
  static String allocatePrefabId({
    required String moduleId,
    required Iterable<String> usedPrefabIds,
  }) {
    final used = usedPrefabIds.map((id) => id.toLowerCase()).toSet();
    final base = defaultPrefabId(moduleId);
    if (!used.contains(base.toLowerCase())) return base;
    var suffix = 2;
    while (used.contains('${base}_$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '${base}_$suffix';
  }

  /// Maps the visual platform lifecycle to its paired gameplay owner.
  static PrefabStatus prefabStatus(TileModuleStatus status) => switch (status) {
    TileModuleStatus.active => PrefabStatus.active,
    TileModuleStatus.deprecated => PrefabStatus.deprecated,
    TileModuleStatus.unknown => PrefabStatus.unknown,
  };
}
