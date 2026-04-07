import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../domain/authoring_types.dart';
import 'prefab_models.dart';

/// Plugin-owned immutable snapshot for the prefab authoring domain.
///
/// [data] is the authoritative editable model. Atlas metadata is kept on the
/// document so validation and scene projection can resolve source image bounds
/// without re-scanning disk on each operation.
@immutable
class PrefabDocument extends AuthoringDocument {
  PrefabDocument({
    required this.data,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    List<String> migrationHints = const <String>[],
  }) : atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       migrationHints = List<String>.unmodifiable(migrationHints);

  final PrefabData data;

  /// Discovered atlas image paths under the prefab level asset directory.
  final List<String> atlasImagePaths;

  /// Pixel dimensions keyed by atlas image path.
  final Map<String, Size> atlasImageSizes;

  /// Load/migration notices that should remain attached to this document until
  /// the next repository reload.
  final List<String> migrationHints;

  /// Returns a new immutable snapshot with selected fields replaced.
  PrefabDocument copyWith({
    PrefabData? data,
    List<String>? atlasImagePaths,
    Map<String, Size>? atlasImageSizes,
    List<String>? migrationHints,
  }) {
    return PrefabDocument(
      data: data ?? this.data,
      atlasImagePaths: atlasImagePaths ?? this.atlasImagePaths,
      atlasImageSizes: atlasImageSizes ?? this.atlasImageSizes,
      migrationHints: migrationHints ?? this.migrationHints,
    );
  }
}

/// UI-facing scene projection for prefab editing routes.
///
/// Carries only the data needed by prefab creator pages; export baseline and
/// repository write concerns stay in plugin/store layers.
@immutable
class PrefabScene extends EditableScene {
  PrefabScene({
    required this.data,
    required List<String> atlasImagePaths,
    required Map<String, Size> atlasImageSizes,
    List<String> migrationHints = const <String>[],
  }) : atlasImagePaths = List<String>.unmodifiable(atlasImagePaths),
       atlasImageSizes = Map<String, Size>.unmodifiable(atlasImageSizes),
       migrationHints = List<String>.unmodifiable(migrationHints);

  final PrefabData data;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final List<String> migrationHints;
}
