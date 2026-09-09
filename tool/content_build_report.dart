import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cancellation and source conflict are admitted only before replacement.
final class ContentBuildInterruption implements Exception {
  const ContentBuildInterruption(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

/// Exact authoring/image generation used by the root content generator.
///
/// The directory sets intentionally cover excluded source as well as included
/// dependencies. Additions, deletions, image edits, and generator-code edits all
/// invalidate a successful build; timestamps are never content authority.
final class ContentBuildSnapshot {
  ContentBuildSnapshot._(this._root, this.fingerprint, this.files, this._bytes);
  final String _root;
  final String fingerprint;
  final Map<String, String> files;
  final Map<String, Uint8List> _bytes;

  bool contains(String path) => _bytes.containsKey(path);
  String readString(String path) => utf8.decode(readBytes(path));
  Uint8List readBytes(String path) {
    final bytes = _bytes[path];
    if (bytes == null) {
      throw FileSystemException(
        'Input was absent from this Build snapshot.',
        path,
      );
    }
    return Uint8List.fromList(bytes);
  }

  static const sourceRoots = <String, String>{
    'assets/authoring/level': '.json',
    'assets/images/level/atlases': '.png',
    'assets/images/parallax': '.png',
    'tool': '.dart',
    'packages/runner_content_pipeline/lib': '.dart',
    'packages/terrain_materials/lib': '.dart',
    'packages/runner_core/lib': '.dart',
  };

  static const _generatedInputs = {
    'packages/runner_core/lib/track/authored_chunk_patterns.dart',
    'packages/runner_core/lib/track/staged_authored_terrain.dart',
    'packages/runner_core/lib/levels/level_id.dart',
    'packages/runner_core/lib/levels/level_registry.dart',
  };

  static Future<ContentBuildSnapshot> capture({String? workspaceRoot}) async {
    final root = await Directory(workspaceRoot ?? Directory.current.path)
        .resolveSymbolicLinks();
    final paths = <String>{};
    for (final entry in sourceRoots.entries) {
      final directory = Directory('$root/${entry.key}');
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is Link) {
          throw ContentBuildInterruption(
            'build_source_link',
            'Build inputs must use regular repository paths: ${_relative(entity.path, root)}.',
          );
        }
        if (entity is File && entity.path.endsWith(entry.value)) {
          paths.add(entity.path);
        }
      }
    }
    for (final relative in const [
      'pubspec.yaml',
      'pubspec.lock',
      'packages/runner_core/pubspec.yaml',
      'packages/runner_content_pipeline/pubspec.yaml',
      'packages/terrain_materials/pubspec.yaml',
    ]) {
      if (await File('$root/$relative').exists()) paths.add('$root/$relative');
    }
    final files = <String, String>{};
    final capturedBytes = <String, Uint8List>{};
    final ordered = paths.toList()..sort();
    for (final path in ordered) {
      final canonical = await File(path).resolveSymbolicLinks();
      if (!_within(root, canonical)) {
        throw const ContentBuildInterruption(
          'build_source_escape',
          'A build input resolves outside the repository.',
        );
      }
      final relative = _relative(path, root);
      if (_generatedInputs.contains(relative)) continue;
      final bytes = await File(canonical).readAsBytes();
      files[relative] = sha256.convert(bytes).toString();
      capturedBytes[relative] = bytes;
    }
    return ContentBuildSnapshot._(
      root,
      sha256.convert(utf8.encode(jsonEncode(files))).toString(),
      Map.unmodifiable(files),
      Map.unmodifiable(capturedBytes),
    );
  }

  Future<void> verifyCurrent() async {
    final current = await capture(workspaceRoot: _root);
    if (current.fingerprint != fingerprint) {
      throw const ContentBuildInterruption(
        'build_source_drift',
        'Saved authoring sources or images changed during Build. Save or reload the affected content and retry.',
      );
    }
  }
}

/// Versioned JSON-line protocol consumed by the editor without parsing prose.
final class ContentBuildReporter {
  ContentBuildReporter({required this.machineReadable, required this.dryRun});
  final bool machineReadable;
  final bool dryRun;
  String? inputFingerprint;
  List<Map<String, Object?>> levels = const [];
  List<Map<String, Object?>> changes = const [];
  List<String> outputs = const [];

  void log(String message) {
    if (!machineReadable) stdout.writeln(message);
  }

  void phase(String phase) {
    if (machineReadable) {
      stdout.writeln(
        jsonEncode({
          'protocolVersion': 1,
          'type': 'progress',
          'phase': phase,
          if (outputs.isNotEmpty) 'outputs': outputs,
        }),
      );
    }
  }

  void finish(
    String outcome, {
    List<Map<String, Object?>> issues = const [],
    bool outputsCommitted = false,
    bool rollbackComplete = false,
    List<String> transactionFailures = const [],
  }) {
    if (!machineReadable) return;
    stdout.writeln(
      jsonEncode({
        'protocolVersion': 1,
        'type': 'result',
        'outcome': outcome,
        'dryRun': dryRun,
        'inputFingerprint': inputFingerprint,
        'levels': levels,
        'changes': changes,
        'outputs': outputs,
        'issues': issues,
        'outputsCommitted': outputsCommitted,
        'rollbackComplete': rollbackComplete,
        'transactionFailures': transactionFailures,
      }),
    );
  }
}

String _relative(String path, String root) =>
    path.substring(root.length + 1).replaceAll('\\', '/');
bool _within(String root, String path) {
  final canonicalRoot = root.replaceAll('\\', '/');
  final canonicalPath = path.replaceAll('\\', '/');
  return Platform.isWindows
      ? canonicalPath.toLowerCase().startsWith(
          '${canonicalRoot.toLowerCase()}/',
        )
      : canonicalPath.startsWith('$canonicalRoot/');
}
