import 'dart:convert';
import 'dart:io';

/// One deterministic generated file rendered fully in memory.
final class GeneratedArtifact {
  const GeneratedArtifact({required this.path, required this.content});

  final String path;
  final String content;
}

/// Exact committed-output mismatch kind reported by generator dry-run.
enum GeneratedArtifactDriftKind { missing, stale, unexpected, unreadable }

/// One stable generated-output diagnostic.
final class GeneratedArtifactDrift
    implements Comparable<GeneratedArtifactDrift> {
  const GeneratedArtifactDrift({
    required this.path,
    required this.kind,
    this.detail,
  });

  final String path;
  final GeneratedArtifactDriftKind kind;
  final String? detail;

  String get code => switch (kind) {
    GeneratedArtifactDriftKind.missing => 'generated_output_missing',
    GeneratedArtifactDriftKind.stale => 'generated_output_stale',
    GeneratedArtifactDriftKind.unexpected => 'generated_output_unexpected',
    GeneratedArtifactDriftKind.unreadable => 'generated_output_unreadable',
  };

  String get message => switch (kind) {
    GeneratedArtifactDriftKind.missing =>
      'Expected generated output is missing.',
    GeneratedArtifactDriftKind.stale =>
      'Committed generated output differs from the in-memory render.',
    GeneratedArtifactDriftKind.unexpected =>
      'File carries this generator ownership marker but is not an expected output.',
    GeneratedArtifactDriftKind.unreadable =>
      'Generated output could not be read${detail == null ? '.' : ': $detail'}',
  };

  @override
  int compareTo(GeneratedArtifactDrift other) {
    final pathOrder = path.compareTo(other.path);
    return pathOrder != 0 ? pathOrder : kind.index.compareTo(other.kind.index);
  }
}

/// Immutable, canonically ordered plan for generator comparison and writes.
final class GeneratedArtifactPlan {
  GeneratedArtifactPlan(
    Iterable<GeneratedArtifact> artifacts, {
    this.ownershipMarker,
    Iterable<String> ownershipSearchRoots = const <String>[],
  }) : ownershipSearchRoots = List<String>.unmodifiable(
         ownershipSearchRoots.toSet().toList()..sort(),
       ),
       artifacts = List<GeneratedArtifact>.unmodifiable(
         List<GeneratedArtifact>.of(artifacts)
           ..sort((left, right) => left.path.compareTo(right.path)),
       ) {
    for (var index = 0; index < this.artifacts.length; index += 1) {
      final artifact = this.artifacts[index];
      if (artifact.path.trim().isEmpty) {
        throw ArgumentError.value(artifact.path, 'artifacts', 'Empty path.');
      }
      if (index > 0 && this.artifacts[index - 1].path == artifact.path) {
        throw ArgumentError.value(
          artifact.path,
          'artifacts',
          'Generated output paths must be unique.',
        );
      }
    }
  }

  final List<GeneratedArtifact> artifacts;
  final String? ownershipMarker;
  final List<String> ownershipSearchRoots;

  /// Compares every expected file byte-for-byte without writing.
  Future<List<GeneratedArtifactDrift>> inspectDrift() async {
    final drift = <GeneratedArtifactDrift>[];
    for (final artifact in artifacts) {
      final file = File(artifact.path);
      if (!await file.exists()) {
        drift.add(
          GeneratedArtifactDrift(
            path: _canonicalDisplayPath(artifact.path),
            kind: GeneratedArtifactDriftKind.missing,
          ),
        );
        continue;
      }
      try {
        final current = await file.readAsBytes();
        final expected = utf8.encode(artifact.content);
        if (!_bytesEqual(current, expected)) {
          drift.add(
            GeneratedArtifactDrift(
              path: _canonicalDisplayPath(artifact.path),
              kind: GeneratedArtifactDriftKind.stale,
            ),
          );
        }
      } on Object catch (error) {
        drift.add(
          GeneratedArtifactDrift(
            path: _canonicalDisplayPath(artifact.path),
            kind: GeneratedArtifactDriftKind.unreadable,
            detail: error.toString(),
          ),
        );
      }
    }
    final marker = ownershipMarker;
    if (marker != null && marker.isNotEmpty) {
      final expectedPaths = artifacts
          .map((artifact) => _canonicalAbsolutePath(artifact.path))
          .toSet();
      final candidates = <String>[];
      for (final rootPath in ownershipSearchRoots) {
        final root = Directory(rootPath);
        if (!await root.exists()) continue;
        await for (final entity in root.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) candidates.add(entity.path);
        }
      }
      candidates.sort();
      for (final path in candidates) {
        if (expectedPaths.contains(_canonicalAbsolutePath(path))) continue;
        try {
          if ((await File(path).readAsString()).contains(marker)) {
            drift.add(
              GeneratedArtifactDrift(
                path: _canonicalDisplayPath(path),
                kind: GeneratedArtifactDriftKind.unexpected,
              ),
            );
          }
        } on Object {
          // An unrelated unreadable file is outside this generator's known
          // ownership. Expected-file read failures are reported above.
        }
      }
    }
    drift.sort();
    return List<GeneratedArtifactDrift>.unmodifiable(drift);
  }

  /// Writes the already-rendered artifacts in canonical path order.
  Future<void> writeAll() async {
    for (final artifact in artifacts) {
      final file = File(artifact.path);
      await file.parent.create(recursive: true);
      await file.writeAsString(artifact.content);
    }
  }
}

String _canonicalAbsolutePath(String path) {
  final normalized = File(path).absolute.path.replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _canonicalDisplayPath(String path) {
  final normalized = File(path).absolute.path.replaceAll('\\', '/');
  final root = Directory.current.absolute.path.replaceAll('\\', '/');
  final foldedNormalized = Platform.isWindows
      ? normalized.toLowerCase()
      : normalized;
  final foldedRoot = Platform.isWindows ? root.toLowerCase() : root;
  return foldedNormalized.startsWith('$foldedRoot/')
      ? normalized.substring(root.length + 1)
      : normalized;
}
