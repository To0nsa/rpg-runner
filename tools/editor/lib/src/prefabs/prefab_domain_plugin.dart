import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'prefab_domain_models.dart';
import 'prefab_models.dart';
import 'prefab_store.dart';
import 'prefab_validation.dart';

class PrefabDomainPlugin implements AuthoringDomainPlugin {
  const PrefabDomainPlugin({PrefabStore store = const PrefabStore()})
    : _store = store;

  static const String pluginId = 'prefabs';
  static const String replacePrefabDataCommandKind = 'replace_prefab_data';
  static const String _levelAssetsPath = 'assets/images/level';

  final PrefabStore _store;

  @override
  String get id => pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    final loadResult = await _store.loadWithReport(workspace.rootPath);
    final atlasImagePaths = _discoverAtlasImages(workspace);
    final atlasImageSizes = _readAtlasImageSizes(
      workspace,
      atlasImagePaths: atlasImagePaths,
    );
    return PrefabDocument(
      data: loadResult.data,
      atlasImagePaths: List<String>.unmodifiable(atlasImagePaths),
      atlasImageSizes: Map<String, Size>.unmodifiable(atlasImageSizes),
      migrationHints: List<String>.unmodifiable(loadResult.migrationHints),
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
      return const ExportResult(
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
        beforeContent: _readIfExists(workspace.resolve(prefabRelativePath)),
        afterContent: canonical.prefabContents,
      ),
      _PrefabFileWrite(
        relativePath: tileRelativePath,
        beforeContent: _readIfExists(workspace.resolve(tileRelativePath)),
        afterContent: canonical.tileContents,
      ),
    ];

    final changed = writes
        .where((write) => write.beforeContent != write.afterContent)
        .toList(growable: false);
    if (changed.isEmpty) {
      return const PendingChanges();
    }

    final fileDiffs = changed
        .map(
          (write) => PendingFileDiff(
            relativePath: write.relativePath,
            editCount: 1,
            unifiedDiff: _buildUnifiedDiff(write),
          ),
        )
        .toList(growable: false);

    return PendingChanges(
      changedEntryIds: fileDiffs.map((diff) => diff.relativePath).toList(),
      fileDiffs: fileDiffs,
    );
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

  bool _canonicalDataEquals(PrefabData a, PrefabData b) {
    final encodedA = _store.serializeCanonicalFiles(a);
    final encodedB = _store.serializeCanonicalFiles(b);
    return encodedA.prefabContents == encodedB.prefabContents &&
        encodedA.tileContents == encodedB.tileContents;
  }

  String? _readIfExists(String absolutePath) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
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

  List<String> _splitLines(String content) {
    final normalized = content.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  List<String> _discoverAtlasImages(EditorWorkspace workspace) {
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

  Map<String, Size> _readAtlasImageSizes(
    EditorWorkspace workspace, {
    required List<String> atlasImagePaths,
  }) {
    final result = <String, Size>{};
    for (final relativePath in atlasImagePaths) {
      final file = File(workspace.resolve(relativePath));
      if (!file.existsSync()) {
        continue;
      }
      final size = _readPngSize(file);
      if (size == null) {
        continue;
      }
      result[relativePath] = size;
    }
    return result;
  }

  Size? _readPngSize(File file) {
    final bytes = file.readAsBytesSync();
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
