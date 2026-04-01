import 'dart:convert';
import 'dart:io';

const String _chunksDirectoryPath = 'assets/authoring/level/chunks';

Future<void> main(List<String> args) async {
  final showHelp = args.contains('-h') || args.contains('--help');
  if (showHelp) {
    _printUsage();
    return;
  }

  final unknownArgs = args.where((arg) => arg != '--dry-run').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknownArgs.join(', ')}');
    _printUsage();
    exitCode = 64;
    return;
  }

  final dryRun = args.contains('--dry-run');

  try {
    final issues = <_ValidationIssue>[];
    final identities = <_ChunkIdentity>[];
    final files = await _listChunkJsonFiles();

    if (files.isEmpty) {
      stdout.writeln(
        'No chunk json files found under $_chunksDirectoryPath. '
        'Validation completed.',
      );
      if (!dryRun) {
        stdout.writeln(
          'Generation output is not implemented yet; validation-only mode ran.',
        );
      }
      return;
    }

    for (final file in files) {
      final identity = await _validateChunkFile(file, issues);
      if (identity != null) {
        identities.add(identity);
      }
    }

    _collectDuplicateIdentityIssues(
      identities,
      issues,
      fieldName: 'chunkKey',
      issueCode: 'duplicate_chunk_key',
      selector: (identity) => identity.chunkKey,
    );
    _collectDuplicateIdentityIssues(
      identities,
      issues,
      fieldName: 'id',
      issueCode: 'duplicate_chunk_id',
      selector: (identity) => identity.id,
    );

    issues.sort();

    if (issues.isNotEmpty) {
      for (final issue in issues) {
        stderr.writeln('[ERROR] ${issue.code} ${issue.path}: ${issue.message}');
      }
      stderr.writeln(
        'Validation failed with ${issues.length} blocking issue(s).',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln('Validated ${files.length} chunk json file(s).');
    if (dryRun) {
      stdout.writeln('Dry-run completed with no blocking issues.');
      return;
    }
    stdout.writeln(
      'Generation output is not implemented yet; validation-only mode ran.',
    );
  } on Object catch (error) {
    stderr.writeln('Chunk generation failed: $error');
    exitCode = 1;
  }
}

Future<List<File>> _listChunkJsonFiles() async {
  final directory = Directory(_chunksDirectoryPath);
  if (!await directory.exists()) {
    return const <File>[];
  }

  final files = <File>[];
  await for (final entity in directory.list(
    recursive: false,
    followLinks: false,
  )) {
    if (entity is! File) continue;
    final path = _toRepoRelativePath(entity.path).toLowerCase();
    if (!path.endsWith('.json')) continue;
    files.add(entity);
  }

  files.sort(
    (a, b) =>
        _toRepoRelativePath(a.path).compareTo(_toRepoRelativePath(b.path)),
  );
  return files;
}

Future<_ChunkIdentity?> _validateChunkFile(
  File file,
  List<_ValidationIssue> issues,
) async {
  final path = _toRepoRelativePath(file.path);
  String raw;
  try {
    raw = await file.readAsString();
  } on Object catch (error) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'read_failed',
        message: 'Unable to read file: $error',
      ),
    );
    return null;
  }

  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on Object catch (error) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'invalid_json',
        message: 'JSON parse error: $error',
      ),
    );
    return null;
  }

  if (decoded is! Map<String, Object?>) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'invalid_root_type',
        message: 'Top-level JSON value must be an object.',
      ),
    );
    return null;
  }

  final schemaVersion = decoded['schemaVersion'];
  if (schemaVersion is! int || schemaVersion <= 0) {
    issues.add(
      _ValidationIssue(
        path: path,
        code: 'invalid_schema_version',
        message: 'schemaVersion must be a positive integer.',
      ),
    );
  }

  final chunkKey = _readRequiredString(
    map: decoded,
    path: path,
    field: 'chunkKey',
    issues: issues,
  );
  final id = _readRequiredString(
    map: decoded,
    path: path,
    field: 'id',
    issues: issues,
  );
  _readRequiredString(
    map: decoded,
    path: path,
    field: 'levelId',
    issues: issues,
  );

  return _ChunkIdentity(path: path, chunkKey: chunkKey, id: id);
}

String _readRequiredString({
  required Map<String, Object?> map,
  required String path,
  required String field,
  required List<_ValidationIssue> issues,
}) {
  final value = map[field];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  issues.add(
    _ValidationIssue(
      path: path,
      code: 'missing_$field',
      message: '$field must be a non-empty string.',
    ),
  );
  return '';
}

void _collectDuplicateIdentityIssues(
  List<_ChunkIdentity> identities,
  List<_ValidationIssue> issues, {
  required String fieldName,
  required String issueCode,
  required String Function(_ChunkIdentity identity) selector,
}) {
  final byValue = <String, List<_ChunkIdentity>>{};
  for (final identity in identities) {
    final value = selector(identity);
    if (value.isEmpty) continue;
    byValue.putIfAbsent(value, () => <_ChunkIdentity>[]).add(identity);
  }

  final sortedValues = byValue.keys.toList()..sort();
  for (final value in sortedValues) {
    final entries = byValue[value]!;
    if (entries.length < 2) continue;
    entries.sort((a, b) => a.path.compareTo(b.path));
    final joinedPaths = entries.map((entry) => entry.path).join(', ');
    for (final entry in entries) {
      issues.add(
        _ValidationIssue(
          path: entry.path,
          code: issueCode,
          message: '$fieldName "$value" is duplicated across: $joinedPaths',
        ),
      );
    }
  }
}

String _toRepoRelativePath(String path) {
  final normalizedPath = _normalizePath(path);
  final normalizedCwd = _normalizePath(Directory.current.path);
  final prefix = '$normalizedCwd/';
  if (normalizedPath.startsWith(prefix)) {
    return normalizedPath.substring(prefix.length);
  }
  return normalizedPath;
}

String _normalizePath(String path) {
  var normalized = path.replaceAll('\\', '/');
  normalized = normalized.replaceAll(RegExp(r'/+'), '/');
  if (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

void _printUsage() {
  stdout.writeln('Generate runtime chunk data from authored chunk json files.');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run tool/generate_chunk_runtime_data.dart');
  stdout.writeln('  dart run tool/generate_chunk_runtime_data.dart --dry-run');
}

class _ChunkIdentity {
  const _ChunkIdentity({
    required this.path,
    required this.chunkKey,
    required this.id,
  });

  final String path;
  final String chunkKey;
  final String id;
}

class _ValidationIssue implements Comparable<_ValidationIssue> {
  const _ValidationIssue({
    required this.path,
    required this.code,
    required this.message,
  });

  final String path;
  final String code;
  final String message;

  @override
  int compareTo(_ValidationIssue other) {
    final pathCompare = path.compareTo(other.path);
    if (pathCompare != 0) return pathCompare;
    final codeCompare = code.compareTo(other.code);
    if (codeCompare != 0) return codeCompare;
    return message.compareTo(other.message);
  }
}
