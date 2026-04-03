import 'prefab_models.dart';

class PrefabDeterminism {
  const PrefabDeterminism._();

  static List<String> normalizeTags(List<String> tags) {
    final normalized =
        tags
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return normalized;
  }

  static List<PrefabDef> sortPrefabsByIdThenKey(Iterable<PrefabDef> prefabs) {
    final sorted = List<PrefabDef>.from(prefabs)
      ..sort(comparePrefabsByIdThenKey);
    return sorted;
  }

  static int comparePrefabsByIdThenKey(PrefabDef a, PrefabDef b) {
    final idCompare = a.id.compareTo(b.id);
    if (idCompare != 0) {
      return idCompare;
    }
    return a.prefabKey.compareTo(b.prefabKey);
  }

  static List<TileModuleDef> sortModulesByStatusIdRevision(
    Iterable<TileModuleDef> modules,
  ) {
    final sorted = List<TileModuleDef>.from(modules)
      ..sort(compareModulesByStatusIdRevision);
    return sorted;
  }

  static int compareModulesByStatusIdRevision(
    TileModuleDef a,
    TileModuleDef b,
  ) {
    final statusCompare = moduleStatusRank(
      a.status,
    ).compareTo(moduleStatusRank(b.status));
    if (statusCompare != 0) {
      return statusCompare;
    }
    final idCompare = a.id.compareTo(b.id);
    if (idCompare != 0) {
      return idCompare;
    }
    return a.revision.compareTo(b.revision);
  }

  static int moduleStatusRank(TileModuleStatus status) {
    switch (status) {
      case TileModuleStatus.active:
        return 0;
      case TileModuleStatus.deprecated:
        return 1;
      case TileModuleStatus.unknown:
        return 2;
    }
  }

  static TileModuleStatus normalizeModuleStatus(TileModuleStatus status) {
    if (status == TileModuleStatus.unknown) {
      return TileModuleStatus.active;
    }
    return status;
  }

  static List<PrefabColliderDef> sortColliders(
    Iterable<PrefabColliderDef> colliders,
  ) {
    final sorted = List<PrefabColliderDef>.from(colliders)
      ..sort((a, b) {
        final offsetYCompare = a.offsetY.compareTo(b.offsetY);
        if (offsetYCompare != 0) {
          return offsetYCompare;
        }
        final offsetXCompare = a.offsetX.compareTo(b.offsetX);
        if (offsetXCompare != 0) {
          return offsetXCompare;
        }
        final widthCompare = a.width.compareTo(b.width);
        if (widthCompare != 0) {
          return widthCompare;
        }
        return a.height.compareTo(b.height);
      });
    return sorted;
  }

  static List<TileModuleCellDef> sortModuleCellsByGridThenSlice(
    Iterable<TileModuleCellDef> cells,
  ) {
    final sorted = List<TileModuleCellDef>.from(cells)
      ..sort((a, b) {
        final yCompare = a.gridY.compareTo(b.gridY);
        if (yCompare != 0) {
          return yCompare;
        }
        final xCompare = a.gridX.compareTo(b.gridX);
        if (xCompare != 0) {
          return xCompare;
        }
        return a.sliceId.compareTo(b.sliceId);
      });
    return sorted;
  }

  static String slugToPrefabKey(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String allocatePrefabKey({
    required String id,
    required Set<String> usedPrefabKeys,
  }) {
    var base = slugToPrefabKey(id);
    if (base.isEmpty) {
      base = 'prefab';
    }
    var candidate = base;
    var suffix = 2;
    while (usedPrefabKeys.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  static String allocateDuplicateModuleId({
    required String sourceId,
    required Set<String> usedModuleIds,
  }) {
    final base = sourceId.trim().isEmpty ? 'module' : sourceId.trim();
    var candidate = '${base}_copy';
    var suffix = 2;
    while (usedModuleIds.contains(candidate)) {
      candidate = '${base}_copy_$suffix';
      suffix += 1;
    }
    return candidate;
  }
}
