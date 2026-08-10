import '../models/models.dart';

/// Prefab-domain determinism helpers shared by store and reducer flows.
///
/// This is the single source for canonical ordering/normalization used by file
/// serialization and in-memory comparisons.

/// Canonical normalization and ordering rules for prefab authoring data.
///
/// These helpers are shared by store/reducer paths so serialization stays
/// deterministic for the same semantic content.
class PrefabDeterminism {
  const PrefabDeterminism._();

  /// Trims, drops empty values, de-duplicates, and lexicographically sorts tags.
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

  /// Returns atlas slices sorted with [compareSlicesByIdThenSourceRect].
  static List<AtlasSliceDef> sortSlicesByIdThenSourceRect(
    Iterable<AtlasSliceDef> slices,
  ) {
    final sorted = List<AtlasSliceDef>.from(slices)
      ..sort(compareSlicesByIdThenSourceRect);
    return sorted;
  }

  /// Total-order comparator for atlas slices.
  ///
  /// User-facing id and source image stay first, then geometry and tags provide
  /// a stable tie-breaker across semantically different slice records.
  static int compareSlicesByIdThenSourceRect(AtlasSliceDef a, AtlasSliceDef b) {
    final idCompare = a.id.compareTo(b.id);
    if (idCompare != 0) {
      return idCompare;
    }
    final sourceCompare = a.sourceImagePath.compareTo(b.sourceImagePath);
    if (sourceCompare != 0) {
      return sourceCompare;
    }
    final yCompare = a.y.compareTo(b.y);
    if (yCompare != 0) {
      return yCompare;
    }
    final xCompare = a.x.compareTo(b.x);
    if (xCompare != 0) {
      return xCompare;
    }
    final widthCompare = a.width.compareTo(b.width);
    if (widthCompare != 0) {
      return widthCompare;
    }
    final heightCompare = a.height.compareTo(b.height);
    if (heightCompare != 0) {
      return heightCompare;
    }
    return _compareStringLists(a.tags, b.tags);
  }

  /// Returns prefab-v3 records in canonical user-ID/stable-key order.
  static List<PrefabV3Def> sortPrefabV3ByIdThenKey(
    Iterable<PrefabV3Def> prefabs,
  ) {
    final sorted = List<PrefabV3Def>.from(prefabs)
      ..sort(comparePrefabV3ByIdThenKey);
    return sorted;
  }

  /// Canonical prefab-v3 file order.
  ///
  /// Equal results represent an invalid duplicate identity and are rejected by
  /// the strict source codec before serialization.
  static int comparePrefabV3ByIdThenKey(PrefabV3Def a, PrefabV3Def b) {
    final idCompare = a.id.compareTo(b.id);
    return idCompare != 0 ? idCompare : a.prefabKey.compareTo(b.prefabKey);
  }

  /// Returns modules sorted with [compareModulesByStatusIdRevision].
  static List<TileModuleDef> sortModulesByStatusIdRevision(
    Iterable<TileModuleDef> modules,
  ) {
    final sorted = List<TileModuleDef>.from(modules)
      ..sort(compareModulesByStatusIdRevision);
    return sorted;
  }

  /// Returns module cells in deterministic row/column/slice order.
  static List<TileModuleCellDef> sortModuleCellsByGridPosition(
    Iterable<TileModuleCellDef> cells,
  ) {
    final sorted = List<TileModuleCellDef>.from(cells)
      ..sort(compareModuleCellsByGridPosition);
    return sorted;
  }

  /// Canonical module-cell order: row, column, then referenced slice ID.
  static int compareModuleCellsByGridPosition(
    TileModuleCellDef a,
    TileModuleCellDef b,
  ) {
    final yCompare = a.gridY.compareTo(b.gridY);
    if (yCompare != 0) return yCompare;
    final xCompare = a.gridX.compareTo(b.gridX);
    return xCompare != 0 ? xCompare : a.sliceId.compareTo(b.sliceId);
  }

  /// Total-order comparator for modules.
  ///
  /// Status rank keeps active modules first in canonical exports; subsequent
  /// tie-breakers prevent non-deterministic ordering among structurally
  /// different modules.
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

    final revisionCompare = a.revision.compareTo(b.revision);
    if (revisionCompare != 0) {
      return revisionCompare;
    }

    final tileSizeCompare = a.tileSize.compareTo(b.tileSize);
    if (tileSizeCompare != 0) {
      return tileSizeCompare;
    }

    return _compareModuleCellLists(a.cells, b.cells);
  }

  /// Defines canonical status ordering for module export and UI defaults.
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

  /// Migrates unsupported module status values to the writable default.
  static TileModuleStatus normalizeModuleStatus(TileModuleStatus status) {
    if (status == TileModuleStatus.unknown) {
      return TileModuleStatus.active;
    }
    return status;
  }

  /// Canonical cell ordering by grid position, then tile slice id.
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

  /// Converts arbitrary text to a prefab-safe key slug.
  ///
  /// Output is lowercase ASCII with `_` separators and no leading/trailing `_`.
  static String slugToPrefabKey(String raw) {
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) {
      return '';
    }
    final replaced = lowered.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Allocates a unique prefab key derived from [id].
  ///
  /// Collision checks are case-insensitive and trim-aware to avoid near-duplicate
  /// keys such as `Tree` and `tree` coexisting.
  static String allocatePrefabKey({
    required String id,
    required Set<String> usedPrefabKeys,
  }) {
    var base = slugToPrefabKey(id);
    if (base.isEmpty) {
      base = 'prefab';
    }
    final normalizedUsedKeys = usedPrefabKeys
        .map((key) => key.trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    var candidate = base;
    var suffix = 2;
    while (normalizedUsedKeys.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  /// Allocates a duplicate-safe module id in `<source>_copy[_N]` form.
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

  static int _compareStringLists(List<String> a, List<String> b) {
    final lengthCompare = a.length.compareTo(b.length);
    if (lengthCompare != 0) {
      return lengthCompare;
    }

    for (var i = 0; i < a.length; i += 1) {
      final itemCompare = a[i].compareTo(b[i]);
      if (itemCompare != 0) {
        return itemCompare;
      }
    }
    return 0;
  }

  static int _compareModuleCellLists(
    List<TileModuleCellDef> a,
    List<TileModuleCellDef> b,
  ) {
    final lengthCompare = a.length.compareTo(b.length);
    if (lengthCompare != 0) {
      return lengthCompare;
    }

    for (var i = 0; i < a.length; i += 1) {
      final cellCompare = compareModuleCellsByGridPosition(a[i], b[i]);
      if (cellCompare != 0) {
        return cellCompare;
      }
    }
    return 0;
  }
}
