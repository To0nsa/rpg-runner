import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'chunk_domain_models.dart';

class ChunkStore {
  static const String chunksDirectoryPath = 'assets/authoring/level/chunks';
  static const String levelDefsPath = 'assets/authoring/level/level_defs.json';
  static const String levelIdSourcePath =
      'packages/runner_core/lib/levels/level_id.dart';
  static const String trackTuningSourcePath =
      'packages/runner_core/lib/tuning/track_tuning.dart';

  const ChunkStore();

  Future<ChunkDocument> load(
    EditorWorkspace workspace, {
    String? preferredActiveLevelId,
  }) async {
    final loadIssues = <ValidationIssue>[];
    final chunks = <LevelChunkDef>[];
    final baselineByChunkKey = <String, ChunkSourceBaseline>{};

    final chunkFiles = _listChunkFiles(workspace);
    final discoveredLevelIds = <String>{};
    for (final file in chunkFiles) {
      final relativePath = _toWorkspaceRelativePath(workspace, file.path);
      String raw;
      try {
        raw = await file.readAsString();
      } on Object catch (error) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'chunk_read_failed',
            message: 'Failed to read chunk file: $error',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      final map = _parseJsonMap(raw);
      if (map == null) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'chunk_invalid_json',
            message: 'Chunk file is not a valid JSON object.',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      final migratedMap = _migrateChunkJson(map);
      loadIssues.addAll(
        _collectRawShapeIssues(migratedMap, sourcePath: relativePath),
      );
      var chunk = LevelChunkDef.fromJson(migratedMap);
      if (chunk.chunkKey.isEmpty) {
        chunk = chunk.copyWith(
          chunkKey: p.basenameWithoutExtension(relativePath).trim(),
        );
      }
      chunk = chunk.normalized();
      chunks.add(chunk);
      discoveredLevelIds.add(chunk.levelId);

      if (baselineByChunkKey.containsKey(chunk.chunkKey)) {
        loadIssues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_chunk_key_in_files',
            message: 'Duplicate chunkKey in source files: ${chunk.chunkKey}',
            sourcePath: relativePath,
          ),
        );
        continue;
      }

      baselineByChunkKey[chunk.chunkKey] = ChunkSourceBaseline(
        sourcePath: relativePath,
        fingerprint: _fingerprint(raw),
      );
    }

    final levelOptions = _resolveLevelOptions(
      workspace,
      discoveredLevelIds: discoveredLevelIds,
    );
    final activeLevelId = _resolveActiveLevelId(
      options: levelOptions.options,
      preferredLevelId: preferredActiveLevelId,
    );
    final runtimeAuthority = _loadRuntimeAuthority(workspace);

    final sortedChunks = List<LevelChunkDef>.from(chunks)
      ..sort(_compareChunksForMemory);
    final sortedLevelIds = List<String>.from(levelOptions.options)..sort();

    return ChunkDocument(
      chunks: sortedChunks,
      baselineByChunkKey: Map<String, ChunkSourceBaseline>.unmodifiable(
        baselineByChunkKey,
      ),
      availableLevelIds: List<String>.unmodifiable(sortedLevelIds),
      activeLevelId: activeLevelId,
      levelOptionSource: levelOptions.source,
      runtimeGridSnap: runtimeAuthority.gridSnap,
      runtimeChunkWidth: runtimeAuthority.chunkWidth,
      loadIssues: List<ValidationIssue>.unmodifiable(loadIssues),
    );
  }

  ChunkSavePlan buildSavePlan(
    EditorWorkspace workspace, {
    required ChunkDocument document,
  }) {
    final encoder = const JsonEncoder.withIndent('  ');
    final normalizedChunks = document.chunks.map((chunk) => chunk.normalized());
    final sortedChunks = normalizedChunks.toList(growable: false)
      ..sort(_compareChunksForMemory);

    final writes = <ChunkFileWrite>[];
    for (final chunk in sortedChunks) {
      final baseline = document.baselineByChunkKey[chunk.chunkKey];
      final relativePath = baseline?.sourcePath ?? _defaultChunkPath(chunk);
      final file = File(workspace.resolve(relativePath));
      final beforeContent = file.existsSync() ? file.readAsStringSync() : null;
      final afterContent = '${encoder.convert(chunk.toJson())}\n';

      if (beforeContent == afterContent) {
        continue;
      }

      writes.add(
        ChunkFileWrite(
          chunkKey: chunk.chunkKey,
          chunkId: chunk.id,
          relativePath: p.normalize(relativePath),
          beforeContent: beforeContent,
          afterContent: afterContent,
        ),
      );
    }

    _ensureNoCaseInsensitivePathCollision(writes);

    return ChunkSavePlan(
      writes: List<ChunkFileWrite>.unmodifiable(writes),
      changedChunkKeys: List<String>.unmodifiable(
        writes.map((write) => write.chunkKey).toList(growable: false),
      ),
    );
  }

  Future<void> save(
    EditorWorkspace workspace, {
    required ChunkDocument document,
    required ChunkSavePlan savePlan,
  }) async {
    if (savePlan.writes.isEmpty) {
      return;
    }

    _verifyNoSourceDrift(
      workspace,
      document: document,
      writes: savePlan.writes,
    );

    for (final write in savePlan.writes) {
      final targetFile = File(workspace.resolve(write.relativePath));
      _atomicWrite(targetFile, write.afterContent);
    }
  }

  List<File> _listChunkFiles(EditorWorkspace workspace) {
    final chunkDirectory = Directory(workspace.resolve(chunksDirectoryPath));
    if (!chunkDirectory.existsSync()) {
      return const <File>[];
    }
    final files =
        chunkDirectory
            .listSync(recursive: false, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Map<String, Object?>? _parseJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object {
      return null;
    }
    return null;
  }

  Map<String, Object?> _migrateChunkJson(Map<String, Object?> raw) {
    // Migration hook scaffold for future schema upgrades.
    return raw;
  }

  List<ValidationIssue> _collectRawShapeIssues(
    Map<String, Object?> raw, {
    required String sourcePath,
  }) {
    final issues = <ValidationIssue>[];
    void add(String code, String message) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: code,
          message: message,
          sourcePath: sourcePath,
        ),
      );
    }

    final schemaVersion = raw['schemaVersion'];
    if (schemaVersion is! int || schemaVersion <= 0) {
      add(
        'invalid_schema_version',
        'schemaVersion must be a positive integer in source JSON.',
      );
    }

    final chunkKey = raw['chunkKey'];
    if (chunkKey is! String || chunkKey.trim().isEmpty) {
      add('missing_chunk_key', 'chunkKey must be a non-empty string.');
    } else if (!RegExp(r'^[a-z0-9_]+$').hasMatch(chunkKey.trim())) {
      add(
        'malformed_chunk_key',
        'chunkKey must contain only lowercase letters, digits, and underscore.',
      );
    }

    final revision = raw['revision'];
    if (revision is! int || revision <= 0) {
      add(
        'invalid_revision',
        'revision must be a positive integer in source JSON.',
      );
    }

    _validateStringArray(
      raw['tags'],
      fieldName: 'tags',
      sourcePath: sourcePath,
      issues: issues,
    );

    _validateObjectArray(
      raw['tileLayers'],
      fieldName: 'tileLayers',
      arrayCode: 'malformed_tile_layers_array',
      entryCode: 'malformed_tile_layers_entry',
      sourcePath: sourcePath,
      issues: issues,
    );
    _validateObjectArray(
      raw['prefabs'],
      fieldName: 'prefabs',
      arrayCode: 'malformed_prefabs_array',
      entryCode: 'malformed_prefabs_entry',
      sourcePath: sourcePath,
      issues: issues,
    );
    _validateObjectArray(
      raw['markers'],
      fieldName: 'markers',
      arrayCode: 'malformed_markers_array',
      entryCode: 'malformed_markers_entry',
      sourcePath: sourcePath,
      issues: issues,
    );

    final groundProfile = raw['groundProfile'];
    if (groundProfile is! Map<String, Object?>) {
      add(
        'invalid_ground_profile',
        'groundProfile must be an object in source JSON.',
      );
    } else {
      final kind = groundProfile['kind'];
      if (kind is! String || kind.trim().isEmpty) {
        add(
          'invalid_ground_profile_kind',
          'groundProfile.kind must be a non-empty string.',
        );
      }
      final topY = groundProfile['topY'];
      if (topY is! int) {
        add(
          'invalid_ground_profile_top_y',
          'groundProfile.topY must be an integer.',
        );
      }
    }

    final groundGaps = raw['groundGaps'];
    if (groundGaps is! List<Object?>) {
      add(
        'malformed_ground_gaps_entries',
        'groundGaps must be an array in source JSON.',
      );
      return issues;
    }
    for (var i = 0; i < groundGaps.length; i += 1) {
      final entry = groundGaps[i];
      if (entry is! Map<String, Object?>) {
        add(
          'malformed_ground_gaps_entries',
          'groundGaps[$i] must be an object.',
        );
        continue;
      }
      if (entry['gapId'] is! String ||
          (entry['gapId'] as String).trim().isEmpty) {
        add(
          'missing_gap_id',
          'groundGaps[$i].gapId must be a non-empty string.',
        );
      }
      if (entry['type'] is! String ||
          (entry['type'] as String).trim().isEmpty) {
        add(
          'invalid_gap_type',
          'groundGaps[$i].type must be a non-empty string.',
        );
      }
      if (entry['x'] is! int) {
        add('invalid_gap_x', 'groundGaps[$i].x must be an integer.');
      }
      if (entry['width'] is! int) {
        add('invalid_gap_width', 'groundGaps[$i].width must be an integer.');
      }
    }

    return issues;
  }

  _LevelOptionsResult _resolveLevelOptions(
    EditorWorkspace workspace, {
    required Set<String> discoveredLevelIds,
  }) {
    final fromLevelDefs = _extractLevelOptionsFromLevelDefs(workspace);
    if (fromLevelDefs.isNotEmpty) {
      return _LevelOptionsResult(
        options: fromLevelDefs,
        source: 'level_defs_json',
      );
    }

    final fromEnum = _extractLevelOptionsFromLevelEnum(workspace);
    if (fromEnum.isNotEmpty) {
      return _LevelOptionsResult(
        options: fromEnum,
        source: 'core_level_id_enum',
      );
    }

    final fallback = discoveredLevelIds.toList(growable: false)..sort();
    return _LevelOptionsResult(
      options: fallback,
      source: 'discovered_chunk_level_ids',
    );
  }

  List<String> _extractLevelOptionsFromLevelDefs(EditorWorkspace workspace) {
    final file = File(workspace.resolve(levelDefsPath));
    if (!file.existsSync()) {
      return const <String>[];
    }
    final map = _parseJsonMap(file.readAsStringSync());
    if (map == null) {
      return const <String>[];
    }

    final levelIds = <String>{};
    final rawLevels = map['levels'];
    if (rawLevels is List<Object?>) {
      for (final value in rawLevels) {
        if (value is! Map<String, Object?>) {
          continue;
        }
        final id = _normalizedString(value['id']);
        if (id.isNotEmpty) {
          levelIds.add(id);
        }
      }
    }

    final rawLevelIds = map['levelIds'];
    if (rawLevelIds is List<Object?>) {
      for (final value in rawLevelIds) {
        final id = _normalizedString(value);
        if (id.isNotEmpty) {
          levelIds.add(id);
        }
      }
    }

    final options = levelIds.toList(growable: false)..sort();
    return options;
  }

  List<String> _extractLevelOptionsFromLevelEnum(EditorWorkspace workspace) {
    final file = File(workspace.resolve(levelIdSourcePath));
    if (!file.existsSync()) {
      return const <String>[];
    }
    final source = file.readAsStringSync();
    final enumMatch = RegExp(
      r'enum\s+LevelId\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(source);
    if (enumMatch == null) {
      return const <String>[];
    }
    final enumBody = enumMatch.group(1) ?? '';
    final values =
        enumBody
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .where((value) => !value.startsWith('//'))
            .map((value) => value.split(' ').first.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return values;
  }

  String? _resolveActiveLevelId({
    required List<String> options,
    required String? preferredLevelId,
  }) {
    if (options.isEmpty) {
      return null;
    }
    if (preferredLevelId != null && options.contains(preferredLevelId)) {
      return preferredLevelId;
    }
    return options.first;
  }

  _RuntimeTrackAuthority _loadRuntimeAuthority(EditorWorkspace workspace) {
    final file = File(workspace.resolve(trackTuningSourcePath));
    if (!file.existsSync()) {
      return const _RuntimeTrackAuthority(chunkWidth: 600.0, gridSnap: 16.0);
    }
    final source = file.readAsStringSync();
    final chunkWidth = _extractDoubleDefault(
      source,
      pattern: RegExp(r'this\.chunkWidth\s*=\s*([0-9]+(?:\.[0-9]+)?)'),
      fallback: 600.0,
    );
    final gridSnap = _extractDoubleDefault(
      source,
      pattern: RegExp(r'this\.gridSnap\s*=\s*([0-9]+(?:\.[0-9]+)?)'),
      fallback: 16.0,
    );
    return _RuntimeTrackAuthority(chunkWidth: chunkWidth, gridSnap: gridSnap);
  }

  double _extractDoubleDefault(
    String source, {
    required RegExp pattern,
    required double fallback,
  }) {
    final match = pattern.firstMatch(source);
    if (match == null) {
      return fallback;
    }
    final raw = match.group(1);
    if (raw == null) {
      return fallback;
    }
    return double.tryParse(raw) ?? fallback;
  }

  /// Deterministic filename policy:
  /// - Existing chunks preserve their baseline source path, including rename.
  /// - New chunks are created as `<slug(chunkKey)>.json` under chunks directory.
  String _defaultChunkPath(LevelChunkDef chunk) {
    final fileName = '${_slugify(chunk.chunkKey)}.json';
    return p.normalize(p.join(chunksDirectoryPath, fileName));
  }

  void _verifyNoSourceDrift(
    EditorWorkspace workspace, {
    required ChunkDocument document,
    required List<ChunkFileWrite> writes,
  }) {
    for (final write in writes) {
      final baseline = document.baselineByChunkKey[write.chunkKey];
      if (baseline == null) {
        continue;
      }
      final baselineFile = File(workspace.resolve(baseline.sourcePath));
      if (!baselineFile.existsSync()) {
        throw StateError(
          'Source drift detected for ${write.chunkKey}: '
          '${baseline.sourcePath} no longer exists. Reload before export.',
        );
      }
      final currentFingerprint = _fingerprint(baselineFile.readAsStringSync());
      if (currentFingerprint != baseline.fingerprint) {
        throw StateError(
          'Source drift detected for ${write.chunkKey} at ${baseline.sourcePath}. '
          'Reload before export.',
        );
      }
    }
  }

  void _atomicWrite(File targetFile, String content) {
    final parent = targetFile.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    final tempFile = File('${targetFile.path}.tmp');
    final backupFile = File('${targetFile.path}.bak.tmp');
    final hadOriginal = targetFile.existsSync();

    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    if (backupFile.existsSync()) {
      backupFile.deleteSync();
    }

    tempFile.writeAsStringSync(content);
    try {
      if (hadOriginal) {
        targetFile.renameSync(backupFile.path);
      }
      tempFile.renameSync(targetFile.path);
      if (backupFile.existsSync()) {
        backupFile.deleteSync();
      }
    } on Object {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      if (backupFile.existsSync()) {
        if (targetFile.existsSync()) {
          targetFile.deleteSync();
        }
        backupFile.renameSync(targetFile.path);
      }
      rethrow;
    }
  }

  void _ensureNoCaseInsensitivePathCollision(List<ChunkFileWrite> writes) {
    final seen = <String, ChunkFileWrite>{};
    for (final write in writes) {
      final lowerPath = write.relativePath.toLowerCase();
      final existing = seen[lowerPath];
      if (existing == null) {
        seen[lowerPath] = write;
        continue;
      }
      throw StateError(
        'Case-insensitive filename collision: '
        '${existing.relativePath} (${existing.chunkKey}) vs '
        '${write.relativePath} (${write.chunkKey}).',
      );
    }
  }

  String _toWorkspaceRelativePath(
    EditorWorkspace workspace,
    String absolutePath,
  ) {
    final normalizedAbsolute = p.normalize(absolutePath);
    final normalizedRoot = p.normalize(workspace.rootPath);
    if (p.isWithin(normalizedRoot, normalizedAbsolute)) {
      return p.normalize(p.relative(normalizedAbsolute, from: normalizedRoot));
    }
    return normalizedAbsolute;
  }
}

class ChunkSavePlan {
  const ChunkSavePlan({required this.writes, required this.changedChunkKeys});

  final List<ChunkFileWrite> writes;
  final List<String> changedChunkKeys;

  bool get hasChanges => writes.isNotEmpty;
}

class ChunkFileWrite {
  const ChunkFileWrite({
    required this.chunkKey,
    required this.chunkId,
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String chunkKey;
  final String chunkId;
  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}

class _LevelOptionsResult {
  const _LevelOptionsResult({required this.options, required this.source});

  final List<String> options;
  final String source;
}

class _RuntimeTrackAuthority {
  const _RuntimeTrackAuthority({
    required this.chunkWidth,
    required this.gridSnap,
  });

  final double chunkWidth;
  final double gridSnap;
}

int _compareChunksForMemory(LevelChunkDef a, LevelChunkDef b) {
  final levelCompare = a.levelId.compareTo(b.levelId);
  if (levelCompare != 0) {
    return levelCompare;
  }
  final idCompare = a.id.compareTo(b.id);
  if (idCompare != 0) {
    return idCompare;
  }
  return a.chunkKey.compareTo(b.chunkKey);
}

String _normalizedString(Object? raw) {
  if (raw is String) {
    return raw.trim();
  }
  return '';
}

String _slugify(String raw) {
  final lower = raw.toLowerCase().trim();
  if (lower.isEmpty) {
    return 'chunk';
  }
  final slug = lower.replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  if (slug.isEmpty) {
    return 'chunk';
  }
  return slug;
}

String _fingerprint(String input) {
  const int offsetBasis = 0x811C9DC5;
  const int prime = 0x01000193;
  var hash = offsetBasis;
  final bytes = utf8.encode(input);
  for (final value in bytes) {
    hash ^= value;
    hash = (hash * prime) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

void _validateObjectArray(
  Object? raw, {
  required String fieldName,
  required String arrayCode,
  required String entryCode,
  required String sourcePath,
  required List<ValidationIssue> issues,
}) {
  if (raw is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: arrayCode,
        message: '$fieldName must be an array in source JSON.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }
  for (var i = 0; i < raw.length; i += 1) {
    if (raw[i] is Map<String, Object?>) {
      continue;
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: entryCode,
        message: '$fieldName[$i] must be an object in source JSON.',
        sourcePath: sourcePath,
      ),
    );
  }
}

void _validateStringArray(
  Object? raw, {
  required String fieldName,
  required String sourcePath,
  required List<ValidationIssue> issues,
}) {
  if (raw is! List<Object?>) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'malformed_${_codeKeyForField(fieldName)}_array',
        message: '$fieldName must be an array of strings in source JSON.',
        sourcePath: sourcePath,
      ),
    );
    return;
  }
  for (var i = 0; i < raw.length; i += 1) {
    if (raw[i] is String) {
      continue;
    }
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'malformed_${_codeKeyForField(fieldName)}_entry',
        message: '$fieldName[$i] must be a string in source JSON.',
        sourcePath: sourcePath,
      ),
    );
  }
}

String _codeKeyForField(String fieldName) {
  return fieldName.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
  );
}
