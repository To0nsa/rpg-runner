import 'package:path/path.dart' as p;

import '../models/models.dart';
import '../store/prefab_determinism.dart';

/// Naming convention applied when a new atlas slice is created.
final class AtlasSliceIdConvention {
  const AtlasSliceIdConvention._();

  static final RegExp _snakeCasePattern = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');
  static final RegExp _variantSuffixPattern = RegExp(
    r'_(?:0[1-9]|[1-9][0-9])$',
  );
  static final RegExp _sizeSuffixPattern = RegExp(
    r'_([1-9][0-9]*)x([1-9][0-9]*)$',
  );

  /// Returns the canonical placeholder pattern for [kind].
  ///
  /// Prefab Slice identity deliberately excludes render dimensions. Tile
  /// Slice identity includes the source sheet and ends with its pixel size
  /// because the same ID also identifies an automatically created platform.
  static String pattern(AtlasSliceKind kind) => switch (kind) {
    AtlasSliceKind.prefab => '<collection>_<object>[_<descriptor>]_<nn>',
    AtlasSliceKind.tile =>
      '<collection>_<sheet>_<object>[_<descriptor>]_<nn>_<W>x<H>',
  };

  /// Resolves known source and selection values into the displayed pattern.
  ///
  /// Unknown values remain placeholders so the guide is useful before an
  /// atlas source or valid selection has been chosen.
  static String contextualPattern({
    required AtlasSliceKind kind,
    required String? sourcePath,
    int? width,
    int? height,
  }) {
    final resolvedPrefix = suggestedPrefix(kind: kind, sourcePath: sourcePath);
    final prefix = resolvedPrefix.isNotEmpty
        ? resolvedPrefix
        : switch (kind) {
            AtlasSliceKind.prefab => '<collection>_',
            AtlasSliceKind.tile => '<collection>_<sheet>_',
          };
    final base = '$prefix<object>[_<descriptor>]_<nn>';
    if (kind == AtlasSliceKind.prefab) return base;
    return '${base}_${_pixelSizeToken(width: width, height: height)}';
  }

  /// Returns a valid example using the current source and selection when known.
  ///
  /// Missing context falls back to the documented `ancient_forest` source and
  /// a 32-by-32-pixel Tile Slice so the example never contains placeholders.
  static String exampleId({
    required AtlasSliceKind kind,
    required String? sourcePath,
    int? width,
    int? height,
  }) {
    final resolvedPrefix = suggestedPrefix(kind: kind, sourcePath: sourcePath);
    final prefix = resolvedPrefix.isNotEmpty
        ? resolvedPrefix
        : kind == AtlasSliceKind.prefab
        ? 'ancient_forest_'
        : 'ancient_forest_terrain_';
    return switch (kind) {
      AtlasSliceKind.prefab => '${prefix}crate_01',
      AtlasSliceKind.tile =>
        '${prefix}grass_01_${_pixelSizeToken(width: width, height: height, fallback: '32x32')}',
    };
  }

  /// Appends or replaces a Tile Slice pixel-size suffix when the ID is ready.
  ///
  /// IDs without a final two-digit variant and invalid dimensions are returned
  /// unchanged, allowing partially typed drafts to remain stable.
  static String withTileSelectionSize({
    required String id,
    required int? width,
    required int? height,
  }) {
    if (width == null || width <= 0 || height == null || height <= 0) {
      return id;
    }
    final existingSize = _sizeSuffixPattern.firstMatch(id);
    final base = existingSize == null
        ? id
        : id.substring(0, existingSize.start);
    if (!_variantSuffixPattern.hasMatch(base)) return id;
    return '${base}_${width}x$height';
  }

  /// Returns the normalized reusable atlas collection prefix for [sourcePath].
  ///
  /// Canonical atlas paths use the directory immediately below `atlases`.
  /// Retained noncanonical paths fall back to the image's parent directory.
  static String collectionPrefix(String? sourcePath) {
    if (sourcePath == null) return '';
    final normalizedPath = p.normalize(sourcePath.trim());
    if (normalizedPath.isEmpty || normalizedPath == '.') return '';
    final parts = p.split(normalizedPath);
    final atlasRootIndex = parts.lastIndexWhere(
      (part) => part.toLowerCase() == 'atlases',
    );
    final rawCollection =
        atlasRootIndex >= 0 && atlasRootIndex + 2 < parts.length
        ? parts[atlasRootIndex + 1]
        : p.basename(p.dirname(normalizedPath));
    final collection = PrefabDeterminism.slugToPrefabKey(rawCollection);
    return collection.isEmpty ? '' : '${collection}_';
  }

  /// Returns the suggested editable prefix for [kind] and [sourcePath].
  ///
  /// Tile slices add the source filename stem after the collection so slices
  /// from different sheets remain distinguishable.
  static String suggestedPrefix({
    required AtlasSliceKind kind,
    required String? sourcePath,
  }) {
    final collection = collectionPrefix(sourcePath);
    if (kind != AtlasSliceKind.tile || sourcePath == null) return collection;
    final normalizedPath = p.normalize(sourcePath.trim());
    if (normalizedPath.isEmpty || normalizedPath == '.') return collection;
    final sheet = PrefabDeterminism.slugToPrefabKey(
      p.basenameWithoutExtension(normalizedPath),
    );
    return sheet.isEmpty ? collection : '$collection${sheet}_';
  }

  /// Returns a user-facing issue when [id] violates the creation convention.
  ///
  /// Valid IDs use lowercase ASCII snake case, begin with the kind-specific
  /// source prefix, and contain an object and two-digit variant. Tile Slice
  /// IDs additionally end with the selected rectangle's pixel dimensions.
  static String? validate({
    required AtlasSliceKind kind,
    required String id,
    required String sourceImagePath,
    int? width,
    int? height,
  }) {
    if (id.isEmpty || id != id.trim()) {
      return 'Slice ID must be non-empty with no surrounding whitespace.';
    }

    final prefix = suggestedPrefix(kind: kind, sourcePath: sourceImagePath);
    if (prefix.isNotEmpty && id == prefix) {
      return 'Add an object name after "$prefix".';
    }
    if (!_snakeCasePattern.hasMatch(id)) {
      return 'Use lowercase snake_case with ASCII letters and numbers.';
    }
    if (prefix.isNotEmpty && !id.startsWith(prefix)) {
      return 'Start the Slice ID with the source prefix "$prefix".';
    }

    var baseBeforeVariant = id;
    if (kind == AtlasSliceKind.tile) {
      final sizeMatch = _sizeSuffixPattern.firstMatch(id);
      if (sizeMatch == null) {
        return width == null || height == null
            ? 'End the Tile Slice ID with a pixel-size suffix such as '
                  '"_32x32".'
            : 'End the Tile Slice ID with its pixel size '
                  '"_${width}x$height".';
      }
      final encodedWidth = int.parse(sizeMatch.group(1)!);
      final encodedHeight = int.parse(sizeMatch.group(2)!);
      if (width != null &&
          height != null &&
          (encodedWidth != width || encodedHeight != height)) {
        return 'The Tile Slice ID size must match the selection: '
            '"_${width}x$height".';
      }
      baseBeforeVariant = id.substring(0, sizeMatch.start);
    }

    final variantMatch = _variantSuffixPattern.firstMatch(baseBeforeVariant);
    if (variantMatch == null) {
      return kind == AtlasSliceKind.tile
          ? 'Add a two-digit variant from _01 to _99 before the size.'
          : 'End the Prefab Slice ID with a two-digit variant from _01 to _99.';
    }
    if (variantMatch.start <= prefix.length) {
      return prefix.isEmpty
          ? 'Add an object name before the variant.'
          : 'Add an object name after "$prefix" and before the variant.';
    }
    return null;
  }

  static String _pixelSizeToken({
    required int? width,
    required int? height,
    String fallback = '<W>x<H>',
  }) => width != null && width > 0 && height != null && height > 0
      ? '${width}x$height'
      : fallback;
}
