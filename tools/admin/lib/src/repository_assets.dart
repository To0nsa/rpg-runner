import 'dart:io';

import 'package:flutter/services.dart';

/// Reuses canonical repository artwork, with resolved-path containment and no file writes.
/// Tool-owned Flutter assets (fonts/manifests) still come from the application bundle.
class RepositoryAssets extends CachingAssetBundle {
  RepositoryAssets(this.repository);
  final String repository;
  @override
  Future<ByteData> load(String key) async {
    if (!key.startsWith('assets/images/')) return rootBundle.load(key);
    if (key.contains('\\') ||
        key.split('/').any((part) => part == '..' || part.isEmpty)) {
      throw const FormatException('Invalid image path.');
    }
    final directory = await Directory('$repository/assets/images')
        .resolveSymbolicLinks();
    final target = await File('$repository/$key').resolveSymbolicLinks();
    final prefix = '$directory${Platform.pathSeparator}';
    if (!(Platform.isWindows
        ? target.toLowerCase().startsWith(prefix.toLowerCase())
        : target.startsWith(prefix))) {
      throw const FormatException(
        'Image escaped the repository artwork directory.',
      );
    }
    final file = File(target);
    if (await file.length() > 32 * 1024 * 1024) {
      throw const FormatException('Image is too large.');
    }
    final bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}
