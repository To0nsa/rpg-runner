import 'package:flutter/services.dart';

/// Shared presentation uses canonical game asset keys. The independent editor
/// consumes the root game's bundled art through its package dependency.
final class EditorGameAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(
    key.startsWith('assets/') ? 'packages/rpg_runner/$key' : key,
  );
}
