import 'dart:ui' show Size;

import '../domain/authoring_types.dart';
import 'prefab_models.dart';

class PrefabDocument extends AuthoringDocument {
  const PrefabDocument({
    required this.data,
    required this.atlasImagePaths,
    required this.atlasImageSizes,
    this.migrationHints = const <String>[],
  });

  final PrefabData data;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final List<String> migrationHints;

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

class PrefabScene extends EditableScene {
  const PrefabScene({
    required this.data,
    required this.atlasImagePaths,
    required this.atlasImageSizes,
    this.migrationHints = const <String>[],
  });

  final PrefabData data;
  final List<String> atlasImagePaths;
  final Map<String, Size> atlasImageSizes;
  final List<String> migrationHints;
}
