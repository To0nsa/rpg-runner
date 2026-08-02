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

/// Failure raised after a generated-output transaction has attempted rollback.
final class GeneratedArtifactWriteException implements Exception {
  const GeneratedArtifactWriteException({
    required this.cause,
    required this.rollbackFailures,
    this.outputsCommitted = false,
  });

  final Object cause;
  final List<String> rollbackFailures;

  /// Whether every target was replaced before cleanup failed.
  final bool outputsCommitted;

  bool get rollbackComplete => !outputsCommitted && rollbackFailures.isEmpty;

  @override
  String toString() {
    final state = outputsCommitted
        ? 'All generated outputs were committed, but transaction cleanup failed.'
        : rollbackFailures.isEmpty
        ? 'The generated-output transaction was rolled back.'
        : 'Generated-output rollback was incomplete.';
    final rollback = rollbackFailures.isEmpty
        ? ''
        : outputsCommitted
        ? ' Cleanup failures: ${rollbackFailures.join('; ')}.'
        : ' Rollback failures: ${rollbackFailures.join('; ')}.';
    return 'GeneratedArtifactWriteException: $cause $state$rollback';
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
    final canonicalPaths = <String>{};
    for (var index = 0; index < this.artifacts.length; index += 1) {
      final artifact = this.artifacts[index];
      if (artifact.path.trim().isEmpty) {
        throw ArgumentError.value(artifact.path, 'artifacts', 'Empty path.');
      }
      if (!canonicalPaths.add(_canonicalAbsolutePath(artifact.path))) {
        throw ArgumentError.value(
          artifact.path,
          'artifacts',
          'Generated output paths must be canonically unique.',
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

  /// Replaces all outputs as one rollback-safe transaction.
  ///
  /// Every complete output is first flushed to a uniquely named sibling file,
  /// keeping staging and replacement on the target volume. Existing outputs
  /// move to sibling backups before staged files are installed. Any staging,
  /// replacement, or verification failure restores all original targets.
  Future<void> writeAll() async {
    final transactionId = _nextTransactionId();
    final entries = <_GeneratedArtifactTransactionEntry>[
      for (var index = 0; index < artifacts.length; index += 1)
        _GeneratedArtifactTransactionEntry(
          artifact: artifacts[index],
          transactionId: transactionId,
          index: index,
        ),
    ];

    try {
      for (final entry in entries) {
        await entry.target.parent.create(recursive: true);
        await _requireTransactionPathAvailable(entry.staged);
        await _requireTransactionPathAvailable(entry.backup);
        await entry.staged.writeAsBytes(entry.expectedBytes, flush: true);
      }

      for (final entry in entries) {
        final targetType = await FileSystemEntity.type(
          entry.target.path,
          followLinks: false,
        );
        if (targetType == FileSystemEntityType.file) {
          await entry.target.rename(entry.backup.path);
          entry.wasBackedUp = true;
        } else if (targetType != FileSystemEntityType.notFound) {
          throw FileSystemException(
            'Generated output target is not a regular file.',
            entry.target.path,
          );
        }
      }

      for (final entry in entries) {
        await entry.staged.rename(entry.target.path);
        entry.wasCommitted = true;
      }

      for (final entry in entries) {
        final written = await entry.target.readAsBytes();
        if (!_bytesEqual(written, entry.expectedBytes)) {
          throw StateError(
            'Generated output verification failed for '
            '${_canonicalDisplayPath(entry.target.path)}.',
          );
        }
      }
    } on Object catch (error, stackTrace) {
      final rollbackFailures = await _rollbackTransaction(entries);
      Error.throwWithStackTrace(
        GeneratedArtifactWriteException(
          cause: error,
          rollbackFailures: List<String>.unmodifiable(rollbackFailures),
        ),
        stackTrace,
      );
    }

    final cleanupFailures = await _cleanupCommittedTransaction(entries);
    if (cleanupFailures.isNotEmpty) {
      throw GeneratedArtifactWriteException(
        cause: StateError('Could not remove every transaction backup.'),
        rollbackFailures: List<String>.unmodifiable(cleanupFailures),
        outputsCommitted: true,
      );
    }
  }
}

int _transactionSerial = 0;

String _nextTransactionId() =>
    '$pid-${DateTime.now().microsecondsSinceEpoch}-${_transactionSerial++}';

final class _GeneratedArtifactTransactionEntry {
  _GeneratedArtifactTransactionEntry({
    required GeneratedArtifact artifact,
    required String transactionId,
    required int index,
  }) : target = File(artifact.path),
       expectedBytes = List<int>.unmodifiable(utf8.encode(artifact.content)),
       staged = File('${artifact.path}.generator-$transactionId-$index.tmp'),
       backup = File('${artifact.path}.generator-$transactionId-$index.bak');

  final File target;
  final List<int> expectedBytes;
  final File staged;
  final File backup;
  bool wasBackedUp = false;
  bool wasCommitted = false;
}

Future<void> _requireTransactionPathAvailable(File file) async {
  final type = await FileSystemEntity.type(file.path, followLinks: false);
  if (type != FileSystemEntityType.notFound) {
    throw FileSystemException(
      'Generated-output transaction path already exists.',
      file.path,
    );
  }
}

Future<List<String>> _rollbackTransaction(
  List<_GeneratedArtifactTransactionEntry> entries,
) async {
  final failures = <String>[];
  for (final entry in entries.reversed) {
    if (entry.wasCommitted) {
      try {
        if (await entry.target.exists()) await entry.target.delete();
      } on Object catch (error) {
        failures.add(
          '${_canonicalDisplayPath(entry.target.path)} delete: $error',
        );
      }
    }
    if (entry.wasBackedUp) {
      try {
        if (await entry.target.exists()) {
          throw StateError('replacement target still exists');
        }
        await entry.backup.rename(entry.target.path);
        entry.wasBackedUp = false;
      } on Object catch (error) {
        failures.add(
          '${_canonicalDisplayPath(entry.target.path)} restore: $error',
        );
      }
    }
  }
  for (final entry in entries) {
    try {
      if (await entry.staged.exists()) await entry.staged.delete();
    } on Object catch (error) {
      failures.add(
        '${_canonicalDisplayPath(entry.staged.path)} cleanup: $error',
      );
    }
  }
  return failures;
}

Future<List<String>> _cleanupCommittedTransaction(
  List<_GeneratedArtifactTransactionEntry> entries,
) async {
  final failures = <String>[];
  for (final entry in entries) {
    for (final file in <File>[entry.staged, entry.backup]) {
      try {
        if (await file.exists()) await file.delete();
      } on Object catch (error) {
        failures.add('${_canonicalDisplayPath(file.path)}: $error');
      }
    }
  }
  return failures;
}

String _canonicalAbsolutePath(String path) {
  final normalized = File(path).absolute.uri
      .normalizePath()
      .toFilePath(windows: Platform.isWindows)
      .replaceAll('\\', '/');
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
  final normalized = File(path).absolute.uri
      .normalizePath()
      .toFilePath(windows: Platform.isWindows)
      .replaceAll('\\', '/');
  final root = Directory.current.absolute.uri
      .normalizePath()
      .toFilePath(windows: Platform.isWindows)
      .replaceAll('\\', '/');
  final foldedNormalized = Platform.isWindows
      ? normalized.toLowerCase()
      : normalized;
  final foldedRoot = Platform.isWindows ? root.toLowerCase() : root;
  return foldedNormalized.startsWith('$foldedRoot/')
      ? normalized.substring(root.length + 1)
      : normalized;
}
