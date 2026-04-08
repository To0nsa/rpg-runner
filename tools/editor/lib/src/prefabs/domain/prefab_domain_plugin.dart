import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

import '../../domain/authoring_types.dart';
import '../../workspace/editor_workspace.dart';
import '../models/models.dart';
import 'prefab_domain_models.dart';
import '../store/prefab_store.dart';
import '../validation/prefab_validation.dart';

/// Prefab-domain `AuthoringDomainPlugin` implementation.
///
/// Owns repository load/validate/export orchestration and keeps UI routes free
/// of direct file I/O concerns.

/// Plugin entry point for prefab/tile authoring workflows.
///
/// The plugin owns repo load/validate/export orchestration, while canonical
/// ordering and migration logic stay in [PrefabStore].
class PrefabDomainPlugin implements AuthoringDomainPlugin {
  const PrefabDomainPlugin({PrefabStore store = const PrefabStore()})
    : _store = store;

  static const String pluginId = 'prefabs';

  /// Command kind accepted by [applyEdit] for replacing full prefab data.
  static const String replacePrefabDataCommandKind = 'replace_prefab_data';

  /// Workspace-relative root scanned for atlas images used by slices.
  static const String _levelAssetsPath = 'assets/images/level';

  /// Widget tests run load under fake async where some async file I/O can
  /// stall; keep a deterministic sync fallback for that environment only.
  static final bool _isFlutterTestProcess = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  final PrefabStore _store;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final loadResult = await _store.loadWithReport(workspace.rootPath);
    final prefabRelativePath = p.normalize(PrefabStore.prefabDefsPath);
    final tileRelativePath = p.normalize(PrefabStore.tileDefsPath);
    late final String? prefabBaselineContents;
    late final String? tileBaselineContents;
    late final List<String> atlasImagePaths;
    late final Map<String, Size> atlasImageSizes;

    if (_isFlutterTestProcess) {
      prefabBaselineContents = _readIfExistsSync(
        workspace.resolve(prefabRelativePath),
      );
      tileBaselineContents = _readIfExistsSync(
        workspace.resolve(tileRelativePath),
      );
      atlasImagePaths = _discoverAtlasImagesSync(workspace);
      atlasImageSizes = _readAtlasImageSizesSync(
        workspace,
        atlasImagePaths: atlasImagePaths,
      );
    } else {
      prefabBaselineContents = await _readIfExistsAsync(
        workspace.resolve(prefabRelativePath),
      );
      tileBaselineContents = await _readIfExistsAsync(
        workspace.resolve(tileRelativePath),
      );
      atlasImagePaths = await _discoverAtlasImagesAsync(workspace);
      atlasImageSizes = await _readAtlasImageSizesAsync(
        workspace,
        atlasImagePaths: atlasImagePaths,
      );
    }

    return PrefabDocument(
      data: loadResult.data,
      atlasImagePaths: List<String>.unmodifiable(atlasImagePaths),
      atlasImageSizes: Map<String, Size>.unmodifiable(atlasImageSizes),
      migrationHints: List<String>.unmodifiable(loadResult.migrationHints),
      prefabBaselineContents: prefabBaselineContents,
      tileBaselineContents: tileBaselineContents,
    );
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) {
    final prefabDocument = _asPrefabDocument(document);
    final issues = validatePrefabDataIssues(
      data: prefabDocument.data,
      atlasImageSizes: prefabDocument.atlasImageSizes,
    );
    return issues
        .map(
          (issue) => ValidationIssue(
            severity: ValidationSeverity.error,
            code: issue.code,
            message: issue.message,
          ),
        )
        .toList(growable: false);
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) {
    final prefabDocument = _asPrefabDocument(document);
    return PrefabScene(
      data: prefabDocument.data,
      atlasImagePaths: prefabDocument.atlasImagePaths,
      atlasImageSizes: prefabDocument.atlasImageSizes,
      migrationHints: prefabDocument.migrationHints,
    );
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final prefabDocument = _asPrefabDocument(document);
    if (command.kind != replacePrefabDataCommandKind) {
      return prefabDocument;
    }
    final rawData = command.payload['data'];
    if (rawData is! PrefabData) {
      return prefabDocument;
    }
    if (_canonicalDataEquals(prefabDocument.data, rawData)) {
      return prefabDocument;
    }
    return prefabDocument.copyWith(data: rawData, migrationHints: const []);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    final prefabDocument = _asPrefabDocument(document);
    final blockingIssues = validate(
      prefabDocument,
    ).where((issue) => issue.severity == ValidationSeverity.error).toList();
    if (blockingIssues.isNotEmpty) {
      throw StateError(
        'Cannot export prefabs while validation has '
        '${blockingIssues.length} blocking issue(s).',
      );
    }

    final pending = describePendingChanges(workspace, document: prefabDocument);
    if (!pending.hasChanges) {
      return ExportResult(
        applied: false,
        artifacts: <ExportArtifact>[
          ExportArtifact(
            title: 'prefab_summary.md',
            content:
                '# Prefab Export\n\nchangedFiles: 0\n\nNo prefab/tile edits detected.',
          ),
        ],
      );
    }

    await _store.save(workspace.rootPath, data: prefabDocument.data);
    final summary = _buildSummary(pending.fileDiffs);
    return ExportResult(
      applied: true,
      artifacts: <ExportArtifact>[
        ExportArtifact(title: 'prefab_summary.md', content: summary),
      ],
    );
  }

  @override
  /// Builds deterministic pending file diffs against load-time baselines.
  ///
  /// Baseline content comes from [PrefabDocument] instead of re-reading files,
  /// so this path avoids synchronous disk I/O during editor interactions.
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final prefabDocument = _asPrefabDocument(document);
    final canonical = _store.serializeCanonicalFiles(prefabDocument.data);

    final prefabRelativePath = p.normalize(PrefabStore.prefabDefsPath);
    final tileRelativePath = p.normalize(PrefabStore.tileDefsPath);
    final writes = <_PrefabFileWrite>[
      _PrefabFileWrite(
        relativePath: prefabRelativePath,
        beforeContent: prefabDocument.prefabBaselineContents,
        afterContent: canonical.prefabContents,
      ),
      _PrefabFileWrite(
        relativePath: tileRelativePath,
        beforeContent: prefabDocument.tileBaselineContents,
        afterContent: canonical.tileContents,
      ),
    ];

    final changed = writes
        .where((write) => write.beforeContent != write.afterContent)
        .toList(growable: false);
    if (changed.isEmpty) {
      return PendingChanges.empty;
    }

    final fileDiffs = changed
        .map(
          (write) => PendingFileDiff(
            relativePath: write.relativePath,
            editCount: _estimateEditCount(
              beforeContent: write.beforeContent,
              afterContent: write.afterContent,
            ),
            unifiedDiff: _buildUnifiedDiff(write),
          ),
        )
        .toList(growable: false);

    return PendingChanges(fileDiffs: fileDiffs);
  }

  PrefabDocument _asPrefabDocument(AuthoringDocument document) {
    if (document is! PrefabDocument) {
      throw StateError(
        'PrefabDomainPlugin expected PrefabDocument but got '
        '${document.runtimeType}.',
      );
    }
    return document;
  }

  /// Compares semantic prefab payloads via canonical serialized output.
  bool _canonicalDataEquals(PrefabData a, PrefabData b) {
    final encodedA = _store.serializeCanonicalFiles(a);
    final encodedB = _store.serializeCanonicalFiles(b);
    return encodedA.prefabContents == encodedB.prefabContents &&
        encodedA.tileContents == encodedB.tileContents;
  }

  /// Reads a file when present and returns null for missing paths.
  Future<String?> _readIfExistsAsync(String absolutePath) async {
    final file = File(absolutePath);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  /// Test-only sync variant used when async file I/O stalls under fake async.
  String? _readIfExistsSync(String absolutePath) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }

  /// Lightweight line-based edit estimate for UI summaries.
  ///
  /// This is intentionally approximate and not a patch-accurate hunk count.
  int _estimateEditCount({
    required String? beforeContent,
    required String afterContent,
  }) {
    final beforeLines = _splitLines(beforeContent ?? '');
    final afterLines = _splitLines(afterContent);
    final sharedLength = beforeLines.length < afterLines.length
        ? beforeLines.length
        : afterLines.length;

    var changedAtSharedIndices = 0;
    for (var i = 0; i < sharedLength; i += 1) {
      if (beforeLines[i] != afterLines[i]) {
        changedAtSharedIndices += 1;
      }
    }

    final insertedOrRemoved = (beforeLines.length - afterLines.length).abs();
    final estimated = changedAtSharedIndices + insertedOrRemoved;
    return estimated <= 0 ? 1 : estimated;
  }

  String _buildSummary(List<PendingFileDiff> fileDiffs) {
    final lines = <String>[
      '# Prefab Export',
      '',
      'changedFiles: ${fileDiffs.length}',
      '',
      '## Files',
      ...fileDiffs.map((diff) => '- ${diff.relativePath}'),
    ];
    return lines.join('\n');
  }

  String _buildUnifiedDiff(_PrefabFileWrite write) {
    final path = write.relativePath.replaceAll('\\', '/');
    final before = write.beforeContent ?? '';
    final after = write.afterContent;
    final beforeLines = _splitLines(before);
    final afterLines = _splitLines(after);
    final lines = <String>[
      'diff --git a/$path b/$path',
      '--- a/$path',
      '+++ b/$path',
      '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      ...beforeLines.map((line) => '-$line'),
      ...afterLines.map((line) => '+$line'),
    ];
    return lines.join('\n');
  }

  /// Splits content into lines with normalized newlines and no trailing blank
  /// line artifact from terminal `\n`.
  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  /// Discovers all PNG atlas files under the level asset tree.
  Future<List<String>> _discoverAtlasImagesAsync(
    EditorWorkspace workspace,
  ) async {
    final levelAssets = Directory(workspace.resolve(_levelAssetsPath));
    if (!await levelAssets.exists()) {
      return const <String>[];
    }

    final pngPaths = <String>[];
    await for (final entity in levelAssets.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.png') {
        continue;
      }
      final relative = p.normalize(
        p.relative(entity.path, from: workspace.rootPath),
      );
      pngPaths.add(relative.replaceAll('\\', '/'));
    }
    pngPaths.sort();
    return pngPaths;
  }

  /// Test-only sync variant used when async file I/O stalls under fake async.
  List<String> _discoverAtlasImagesSync(EditorWorkspace workspace) {
    final levelAssets = Directory(workspace.resolve(_levelAssetsPath));
    if (!levelAssets.existsSync()) {
      return const <String>[];
    }

    final pngPaths = <String>[];
    for (final entity in levelAssets.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final ext = p.extension(entity.path).toLowerCase();
      if (ext != '.png') {
        continue;
      }
      final relative = p.normalize(
        p.relative(entity.path, from: workspace.rootPath),
      );
      pngPaths.add(relative.replaceAll('\\', '/'));
    }
    pngPaths.sort();
    return pngPaths;
  }

  /// Reads atlas image dimensions keyed by relative image path.
  Future<Map<String, Size>> _readAtlasImageSizesAsync(
    EditorWorkspace workspace, {
    required List<String> atlasImagePaths,
  }) async {
    final result = <String, Size>{};
    for (final relativePath in atlasImagePaths) {
      final file = File(workspace.resolve(relativePath));
      if (!await file.exists()) {
        continue;
      }
      final size = await _readPngSizeAsync(file);
      if (size == null) {
        continue;
      }
      result[relativePath] = size;
    }
    return result;
  }

  /// Test-only sync variant used when async file I/O stalls under fake async.
  Map<String, Size> _readAtlasImageSizesSync(
    EditorWorkspace workspace, {
    required List<String> atlasImagePaths,
  }) {
    final result = <String, Size>{};
    for (final relativePath in atlasImagePaths) {
      final file = File(workspace.resolve(relativePath));
      if (!file.existsSync()) {
        continue;
      }
      final size = _readPngSizeSync(file);
      if (size == null) {
        continue;
      }
      result[relativePath] = size;
    }
    return result;
  }

  /// Reads PNG dimensions from the header only.
  ///
  /// Uses the first 24 bytes (signature + IHDR width/height offsets) to avoid
  /// loading full files for metadata checks.
  Future<Size?> _readPngSizeAsync(File file) async {
    final handle = await file.open(mode: FileMode.read);
    try {
      final bytes = await handle.read(24);
      if (bytes.length < 24) {
        return null;
      }
      if (!_hasPngSignature(bytes)) {
        return null;
      }
      final width = _readUint32BigEndian(bytes, 16);
      final height = _readUint32BigEndian(bytes, 20);
      if (width <= 0 || height <= 0) {
        return null;
      }
      return Size(width.toDouble(), height.toDouble());
    } finally {
      await handle.close();
    }
  }

  /// Test-only sync variant used when async file I/O stalls under fake async.
  Size? _readPngSizeSync(File file) {
    final handle = file.openSync(mode: FileMode.read);
    try {
      final bytes = handle.readSync(24);
      if (bytes.length < 24) {
        return null;
      }
      if (!_hasPngSignature(bytes)) {
        return null;
      }
      final width = _readUint32BigEndian(bytes, 16);
      final height = _readUint32BigEndian(bytes, 20);
      if (width <= 0 || height <= 0) {
        return null;
      }
      return Size(width.toDouble(), height.toDouble());
    } finally {
      handle.closeSync();
    }
  }

  bool _hasPngSignature(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i += 1) {
      if (bytes[i] != signature[i]) {
        return false;
      }
    }
    return true;
  }

  int _readUint32BigEndian(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}

class _PrefabFileWrite {
  const _PrefabFileWrite({
    required this.relativePath,
    required this.beforeContent,
    required this.afterContent,
  });

  final String relativePath;
  final String? beforeContent;
  final String afterContent;
}
