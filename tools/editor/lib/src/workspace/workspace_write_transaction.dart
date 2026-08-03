import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One complete file replacement staged by [WorkspaceWriteTransaction].
final class WorkspaceWriteArtifact {
  const WorkspaceWriteArtifact({required this.path, required this.contents});

  /// Absolute or process-relative target path.
  final String path;

  /// Exact UTF-8 text installed at [path].
  final String contents;
}

/// Failure raised after a multi-file repository write attempted recovery.
final class WorkspaceWriteTransactionException implements Exception {
  const WorkspaceWriteTransactionException({
    required this.cause,
    required this.rollbackFailures,
    required this.outputsCommitted,
  });

  final Object cause;
  final List<String> rollbackFailures;

  /// Whether every replacement passed byte verification before cleanup failed.
  final bool outputsCommitted;

  /// True only when no replacement remains after a failed write.
  bool get rollbackComplete => !outputsCommitted && rollbackFailures.isEmpty;

  @override
  String toString() {
    final state = outputsCommitted
        ? 'All outputs were committed, but transaction cleanup failed.'
        : rollbackFailures.isEmpty
        ? 'The transaction was rolled back.'
        : 'The transaction rollback was incomplete.';
    final failures = rollbackFailures.isEmpty
        ? ''
        : ' Recovery failures: ${rollbackFailures.join('; ')}.';
    return 'WorkspaceWriteTransactionException: $cause $state$failures';
  }
}

/// Installs a deterministic file set without exposing a mixed committed state.
///
/// Complete UTF-8 outputs are flushed to unique sibling files first. Existing
/// targets then move to sibling backups, replacements are installed and
/// byte-verified, and [verifyReplacements] runs while rollback is still
/// possible. [beforeReplace] is the optimistic-concurrency seam: callers must
/// perform their final source-drift check there, after staging but immediately
/// before any target moves.
final class WorkspaceWriteTransaction {
  WorkspaceWriteTransaction(Iterable<WorkspaceWriteArtifact> artifacts)
    : artifacts = List<WorkspaceWriteArtifact>.unmodifiable(
        List<WorkspaceWriteArtifact>.of(artifacts)..sort(
          (left, right) =>
              _canonicalPath(left.path).compareTo(_canonicalPath(right.path)),
        ),
      ) {
    final paths = <String>{};
    for (final artifact in this.artifacts) {
      if (artifact.path.trim().isEmpty) {
        throw ArgumentError.value(artifact.path, 'artifacts', 'Empty path.');
      }
      if (!paths.add(_canonicalPath(artifact.path))) {
        throw ArgumentError.value(
          artifact.path,
          'artifacts',
          'Transaction target paths must be canonically unique.',
        );
      }
    }
  }

  final List<WorkspaceWriteArtifact> artifacts;

  /// Applies every replacement synchronously as one rollback-safe transaction.
  ///
  /// A callback failure is treated exactly like a filesystem failure. If
  /// [verifyReplacements] rejects the installed set, all original files are
  /// restored before the exception escapes.
  void apply({
    void Function()? beforeReplace,
    void Function()? verifyReplacements,
  }) {
    if (artifacts.isEmpty) {
      beforeReplace?.call();
      verifyReplacements?.call();
      return;
    }

    final transactionId = _nextTransactionId();
    final entries = <_WorkspaceWriteTransactionEntry>[
      for (var index = 0; index < artifacts.length; index++)
        _WorkspaceWriteTransactionEntry(
          artifact: artifacts[index],
          transactionId: transactionId,
          index: index,
        ),
    ];

    try {
      for (final entry in entries) {
        entry.target.parent.createSync(recursive: true);
        _requireAvailable(entry.staged);
        _requireAvailable(entry.backup);
      }
      for (final entry in entries) {
        entry.staged.writeAsBytesSync(entry.expectedBytes, flush: true);
        _requireExpectedBytes(entry.staged, entry.expectedBytes);
      }

      beforeReplace?.call();

      for (final entry in entries) {
        final type = FileSystemEntity.typeSync(
          entry.target.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file) {
          entry.target.renameSync(entry.backup.path);
          entry.wasBackedUp = true;
        } else if (type != FileSystemEntityType.notFound) {
          throw FileSystemException(
            'Workspace transaction target is not a regular file.',
            entry.target.path,
          );
        }
      }

      for (final entry in entries) {
        entry.staged.renameSync(entry.target.path);
        entry.wasCommitted = true;
      }
      for (final entry in entries) {
        _requireExpectedBytes(entry.target, entry.expectedBytes);
      }
      verifyReplacements?.call();
    } on Object catch (error, stackTrace) {
      final failures = _rollback(entries);
      Error.throwWithStackTrace(
        WorkspaceWriteTransactionException(
          cause: error,
          rollbackFailures: List<String>.unmodifiable(failures),
          outputsCommitted: false,
        ),
        stackTrace,
      );
    }

    final cleanupFailures = _cleanup(entries);
    if (cleanupFailures.isNotEmpty) {
      throw WorkspaceWriteTransactionException(
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

final class _WorkspaceWriteTransactionEntry {
  _WorkspaceWriteTransactionEntry({
    required WorkspaceWriteArtifact artifact,
    required String transactionId,
    required int index,
  }) : target = File(artifact.path),
       expectedBytes = List<int>.unmodifiable(utf8.encode(artifact.contents)),
       staged = File('${artifact.path}.authoring-$transactionId-$index.tmp'),
       backup = File('${artifact.path}.authoring-$transactionId-$index.bak');

  final File target;
  final List<int> expectedBytes;
  final File staged;
  final File backup;
  bool wasBackedUp = false;
  bool wasCommitted = false;
}

void _requireAvailable(File file) {
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw FileSystemException(
      'Workspace transaction path already exists.',
      file.path,
    );
  }
}

void _requireExpectedBytes(File file, List<int> expected) {
  final actual = file.readAsBytesSync();
  if (_bytesEqual(actual, expected)) return;
  throw StateError(
    'Workspace transaction byte verification failed for ${file.path}.',
  );
}

List<String> _rollback(List<_WorkspaceWriteTransactionEntry> entries) {
  final failures = <String>[];
  for (final entry in entries.reversed) {
    if (entry.wasCommitted) {
      try {
        if (entry.target.existsSync()) entry.target.deleteSync();
      } on Object catch (error) {
        failures.add('${entry.target.path} delete: $error');
      }
    }
    if (entry.wasBackedUp) {
      try {
        if (entry.target.existsSync()) {
          throw StateError('Replacement target still exists.');
        }
        entry.backup.renameSync(entry.target.path);
        entry.wasBackedUp = false;
      } on Object catch (error) {
        failures.add('${entry.target.path} restore: $error');
      }
    }
  }
  for (final entry in entries) {
    try {
      if (entry.staged.existsSync()) entry.staged.deleteSync();
    } on Object catch (error) {
      failures.add('${entry.staged.path} cleanup: $error');
    }
  }
  return failures;
}

List<String> _cleanup(List<_WorkspaceWriteTransactionEntry> entries) {
  final failures = <String>[];
  for (final entry in entries) {
    for (final file in <File>[entry.staged, entry.backup]) {
      try {
        if (file.existsSync()) file.deleteSync();
      } on Object catch (error) {
        failures.add('${file.path}: $error');
      }
    }
  }
  return failures;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _canonicalPath(String path) {
  final normalized = p
      .normalize(File(path).absolute.path)
      .replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
