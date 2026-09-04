import 'package:path/path.dart' as p;

import '../store/prefab_determinism.dart';

/// Naming convention applied when a new Prefab Slice is created.
final class PrefabSliceIdConvention {
  const PrefabSliceIdConvention._();

  static final RegExp _snakeCasePattern = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');
  static final RegExp _variantSuffixPattern = RegExp(
    r'_(?:0[1-9]|[1-9][0-9])$',
  );

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

  /// Returns a user-facing issue when [id] violates the creation convention.
  ///
  /// Valid IDs use lowercase ASCII snake case, begin with their atlas
  /// collection, contain an object name, and end in `_01` through `_99`.
  static String? validate({
    required String id,
    required String sourceImagePath,
  }) {
    if (id.isEmpty || id != id.trim()) {
      return 'Slice ID must be non-empty with no surrounding whitespace.';
    }

    final prefix = collectionPrefix(sourceImagePath);
    if (prefix.isNotEmpty && id == prefix) {
      return 'Add an object name after "$prefix" and before the variant suffix.';
    }
    if (!_snakeCasePattern.hasMatch(id)) {
      return 'Use lowercase snake_case with ASCII letters and numbers.';
    }

    if (prefix.isNotEmpty && !id.startsWith(prefix)) {
      return 'Start the Slice ID with the atlas collection prefix "$prefix".';
    }

    final suffixMatch = _variantSuffixPattern.firstMatch(id);
    if (suffixMatch == null) {
      return 'End the Slice ID with a two-digit variant from _01 to _99.';
    }

    final objectStart = prefix.length;
    if (suffixMatch.start <= objectStart) {
      return prefix.isEmpty
          ? 'Add an object name before the variant suffix.'
          : 'Add an object name after "$prefix" and before the variant suffix.';
    }
    return null;
  }
}
