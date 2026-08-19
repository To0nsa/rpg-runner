import 'dart:io';

import 'package:flutter/services.dart';

/// Stable workspace asset failure surfaced by the playtest host.
final class RunnerWorkspaceAssetException implements Exception {
  const RunnerWorkspaceAssetException({
    required this.code,
    required this.message,
    this.assetKey,
    this.cause,
  });

  final String code;
  final String message;
  final String? assetKey;
  final Object? cause;

  @override
  String toString() => '$code: $message';
}

/// Read-only Flutter asset bundle rooted at a repository workspace.
///
/// Only forward-slash keys beneath `assets/` are accepted. Every target is
/// resolved through the filesystem before reading, so traversal and symlink
/// escapes cannot expose files outside the canonical workspace asset root.
final class RunnerWorkspaceAssetBundle extends AssetBundle {
  factory RunnerWorkspaceAssetBundle({required String workspaceRoot}) {
    final root = Directory(workspaceRoot);
    if (!root.existsSync()) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_workspace_root_missing',
        message: 'Workspace root does not exist: ${root.absolute.path}',
      );
    }

    late final String canonicalWorkspaceRoot;
    try {
      canonicalWorkspaceRoot = root.resolveSymbolicLinksSync();
    } on FileSystemException catch (error) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_workspace_root_unreadable',
        message: 'Workspace root could not be resolved: ${root.absolute.path}',
        cause: error,
      );
    }

    final assetRoot = Directory(
      '$canonicalWorkspaceRoot${Platform.pathSeparator}assets',
    );
    if (!assetRoot.existsSync()) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_workspace_assets_missing',
        message: 'Workspace has no assets directory: ${assetRoot.path}',
      );
    }

    late final String canonicalAssetRoot;
    try {
      canonicalAssetRoot = assetRoot.resolveSymbolicLinksSync();
    } on FileSystemException catch (error) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_workspace_assets_unreadable',
        message: 'Workspace assets directory could not be resolved.',
        cause: error,
      );
    }

    return RunnerWorkspaceAssetBundle._(
      workspaceRoot: canonicalWorkspaceRoot,
      assetRoot: canonicalAssetRoot,
    );
  }

  RunnerWorkspaceAssetBundle._({
    required this.workspaceRoot,
    required this.assetRoot,
  });

  /// Canonical repository workspace path.
  final String workspaceRoot;

  /// Canonical `<workspace>/assets` path admitted by this bundle.
  final String assetRoot;

  @override
  Future<ByteData> load(String key) async {
    final segments = _validateKey(key);
    final candidate = File(
      <String>[workspaceRoot, ...segments].join(Platform.pathSeparator),
    );

    late final String canonicalTarget;
    try {
      canonicalTarget = await candidate.resolveSymbolicLinks();
    } on FileSystemException catch (error) {
      if (!await candidate.exists()) {
        throw RunnerWorkspaceAssetException(
          code: 'runner_asset_missing',
          assetKey: key,
          message: 'Workspace asset does not exist: $key',
          cause: error,
        );
      }
      throw RunnerWorkspaceAssetException(
        code: 'runner_asset_resolution_failed',
        assetKey: key,
        message: 'Workspace asset could not be resolved: $key',
        cause: error,
      );
    }

    if (!_isWithinAssetRoot(canonicalTarget)) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_asset_escape',
        assetKey: key,
        message: 'Workspace asset resolves outside the assets directory: $key',
      );
    }

    try {
      final bytes = Uint8List.fromList(
        await File(canonicalTarget).readAsBytes(),
      );
      return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    } on FileSystemException catch (error) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_asset_read_failed',
        assetKey: key,
        message: 'Workspace asset could not be read: $key',
        cause: error,
      );
    }
  }

  List<String> _validateKey(String key) {
    final uri = Uri.tryParse(key);
    final segments = key.split('/');
    final invalid =
        key.isEmpty ||
        key.contains('\\') ||
        key.contains('\u0000') ||
        key.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(key) ||
        (uri?.hasScheme ?? false) ||
        segments.isEmpty ||
        segments.first != 'assets' ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        );
    if (invalid) {
      throw RunnerWorkspaceAssetException(
        code: 'runner_asset_key_invalid',
        assetKey: key,
        message: 'Workspace asset key must be a normalized assets/... path.',
      );
    }
    return segments;
  }

  bool _isWithinAssetRoot(String target) {
    final normalizedRoot = _normalizeForComparison(assetRoot);
    final normalizedTarget = _normalizeForComparison(target);
    return normalizedTarget.startsWith(
      '$normalizedRoot${Platform.pathSeparator}',
    );
  }

  String _normalizeForComparison(String value) =>
      Platform.isWindows ? value.toLowerCase() : value;
}
