/// Pure-Dart workspace-relative paths shared by stores and offline tools.
///
/// Keeping these constants outside Flutter-backed store graphs lets migration
/// and validation commands remain runnable on the standalone Dart VM.
abstract final class RepositoryAuthoringPaths {
  static const String prefabDefinitions =
      'assets/authoring/level/prefab_defs.json';
  static const String chunksDirectory = 'assets/authoring/level/chunks';
}
