import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/migration/polygon_authoring_migration_check.dart';
import 'package:runner_editor/src/migration/polygon_authoring_target_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/workspace/workspace_file_io.dart';

void main() {
  test(
    'repository check builds and strictly validates all targets in memory',
    () {
      final check = PolygonAuthoringMigrationCheck.fromRepository(
        _repoRootPath(),
      );

      expect(check.hasBlockers, isFalse);
      expect(check.targetFiles, hasLength(9));
      expect(check.revisionRecords, hasLength(107));
      expect(check.revisionRecords.where((record) => record.changed), isEmpty);
      expect(check.impactRecords, hasLength(99));
      expect(
        check.impactRecords.fold<int>(
          0,
          (sum, record) => sum + record.placementCount,
        ),
        50,
      );
      for (final target in check.targetFiles) {
        expect(target.hasPendingChange, isTrue, reason: target.sourcePath);
        expect(target.afterSha256, hasLength(64));
        if (target.sourceKind == 'prefabs') {
          expect(
            PolygonAuthoringTargetCodec.encodePrefabV3(
              PolygonAuthoringTargetCodec.decodePrefabV3(
                target.canonicalContents,
                sourcePath: target.sourcePath,
              ),
            ),
            target.canonicalContents,
          );
        } else {
          expect(
            PolygonAuthoringTargetCodec.encodeChunkV2(
              PolygonAuthoringTargetCodec.decodeChunkV2(
                target.canonicalContents,
                sourcePath: target.sourcePath,
              ),
            ),
            target.canonicalContents,
          );
        }
      }

      final report = check.toCanonicalJson();
      final decoded = jsonDecode(report) as Map<String, Object?>;
      final summary = decoded['summary']! as Map<String, Object?>;
      expect(decoded['reportVersion'], 1);
      expect(decoded['mode'], 'check');
      expect(decoded['status'], 'ready');
      expect(summary['sourceFileCount'], 9);
      expect(summary['targetFileCount'], 9);
      expect(summary['pendingMigrationFileCount'], 9);
      expect(summary['revisionChangedCount'], 0);
      expect(summary['downstreamPlacementCount'], 50);
      expect((decoded['blockers']! as List<Object?>), isEmpty);
      expect(WorkspaceFileIo.fingerprint(report), '90fbd996');
    },
  );

  test('unknown prefab placement blocks every target', () {
    final fixture = _copyMigrationSources();
    try {
      final chunkFile = _firstChunkFile(fixture.path);
      final root =
          jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
      final prefabs = root['prefabs']! as List<Object?>;
      final placement = prefabs.first! as Map<String, Object?>;
      placement['prefabId'] = 'missing_prefab';
      placement['prefabKey'] = 'missing_prefab';
      chunkFile.writeAsStringSync(_canonicalJson(root));

      final check = PolygonAuthoringMigrationCheck.fromRepository(fixture.path);

      expect(check.hasBlockers, isTrue);
      expect(check.targetFiles, isEmpty);
      expect(
        check.issues.map((issue) => issue.code),
        contains('migration_unknown_prefab_reference'),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('strict target failure is reported after valid legacy planning', () {
    final fixture = _copyMigrationSources();
    try {
      final prefabFile = File(p.join(fixture.path, PrefabStore.prefabDefsPath));
      final root =
          jsonDecode(prefabFile.readAsStringSync()) as Map<String, Object?>;
      final slices = root['slices']! as List<Object?>;
      final first = slices.first! as Map<String, Object?>;
      final duplicate = jsonDecode(jsonEncode(first)) as Map<String, Object?>;
      duplicate['x'] = (duplicate['x']! as int) + 1;
      slices.insert(1, duplicate);
      prefabFile.writeAsStringSync(_canonicalJson(root));

      final check = PolygonAuthoringMigrationCheck.fromRepository(fixture.path);

      expect(check.hasBlockers, isTrue);
      expect(check.targetFiles, hasLength(8));
      expect(
        check.issues.map((issue) => issue.code),
        contains('migration_prefab_target_invalid'),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('malformed source fails before an incomplete plan is returned', () {
    final fixture = _copyMigrationSources();
    try {
      final chunkFile = _firstChunkFile(fixture.path);
      final root =
          jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
      root['width'] = 600.0;
      chunkFile.writeAsStringSync(jsonEncode(root));

      expect(
        () => PolygonAuthoringMigrationCheck.fromRepository(fixture.path),
        throwsA(
          isA<PolygonAuthoringMigrationCheckException>()
              .having(
                (error) => error.code,
                'code',
                'migration_chunk_source_invalid',
              )
              .having(
                (error) => error.message,
                'message',
                contains('width must be an integer'),
              ),
        ),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });
}

Directory _copyMigrationSources() {
  final sourceRoot = _repoRootPath();
  final targetRoot = Directory.systemTemp.createTempSync(
    'polygon_migration_check_',
  );
  final sourcePrefab = File(
    p.join(sourceRoot, p.normalize(PrefabStore.prefabDefsPath)),
  );
  final targetPrefab = File(
    p.join(targetRoot.path, p.normalize(PrefabStore.prefabDefsPath)),
  )..parent.createSync(recursive: true);
  sourcePrefab.copySync(targetPrefab.path);

  final sourceChunkDirectory = Directory(
    p.join(sourceRoot, 'assets', 'authoring', 'level', 'chunks'),
  );
  for (final source
      in sourceChunkDirectory.listSync(recursive: true).whereType<File>()) {
    if (p.extension(source.path).toLowerCase() != '.json') continue;
    final relativePath = p.relative(source.path, from: sourceRoot);
    final target = File(p.join(targetRoot.path, relativePath))
      ..parent.createSync(recursive: true);
    source.copySync(target.path);
  }
  return targetRoot;
}

File _firstChunkFile(String rootPath) {
  final files =
      Directory(
          p.join(rootPath, 'assets', 'authoring', 'level', 'chunks', 'forest'),
        ).listSync().whereType<File>().toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  return files.firstWhere((file) {
    final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final prefabs = root['prefabs'];
    return prefabs is List<Object?> && prefabs.isNotEmpty;
  });
}

String _canonicalJson(Map<String, Object?> json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

String _repoRootPath() {
  final cwd = p.normalize(Directory.current.path);
  if (p.basename(cwd).toLowerCase() == 'editor' &&
      p.basename(p.dirname(cwd)).toLowerCase() == 'tools') {
    return p.normalize(p.join(cwd, '..', '..'));
  }
  return cwd;
}
