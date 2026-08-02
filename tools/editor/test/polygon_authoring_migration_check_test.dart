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

      expect(check.sourceState, PolygonAuthoringMigrationSourceState.legacy);
      expect(check.legacyPlan, isNotNull);
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
      expect(decoded['reportVersion'], 2);
      expect(decoded['mode'], 'check');
      expect(decoded['sourceState'], 'legacy');
      expect(decoded['status'], 'ready');
      expect(summary['sourceFileCount'], 9);
      expect(summary['targetFileCount'], 9);
      expect(summary['pendingMigrationFileCount'], 9);
      expect(summary['revisionChangedCount'], 0);
      expect(summary['downstreamPlacementCount'], 50);
      expect((decoded['blockers']! as List<Object?>), isEmpty);
      expect(WorkspaceFileIo.fingerprint(report), '4c1243df');
    },
  );

  test('current repository is a strictly validated canonical no-op', () {
    final fixture = _copyMigrationSources();
    try {
      _promoteFixtureToCurrent(fixture.path);
      final before = _sourceDigests(fixture.path);

      final check = PolygonAuthoringMigrationCheck.fromRepository(fixture.path);

      expect(check.sourceState, PolygonAuthoringMigrationSourceState.current);
      expect(check.legacyPlan, isNull);
      expect(check.hasBlockers, isFalse);
      expect(check.sourceFiles, hasLength(9));
      expect(check.targetFiles, hasLength(9));
      expect(
        check.targetFiles.where((target) => target.hasPendingChange),
        isEmpty,
      );
      expect(check.revisionRecords, hasLength(107));
      expect(check.impactRecords, hasLength(99));
      expect(
        check.impactRecords.fold<int>(
          0,
          (sum, record) => sum + record.placementCount,
        ),
        50,
      );
      expect(check.auditSourceDigests(_sourceDigests(fixture.path)), isEmpty);
      expect(_sourceDigests(fixture.path), before);

      final decoded =
          jsonDecode(check.toCanonicalJson()) as Map<String, Object?>;
      expect(WorkspaceFileIo.fingerprint(check.toCanonicalJson()), '2da9f6ab');
      final summary = decoded['summary']! as Map<String, Object?>;
      expect(decoded['reportVersion'], 2);
      expect(decoded['sourceState'], 'current');
      expect(decoded['status'], 'ready');
      expect(summary['pendingMigrationFileCount'], 0);
      expect((decoded['prefabs']! as List<Object?>), isEmpty);
      expect((decoded['chunks']! as List<Object?>), isEmpty);
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('partially converted repository fails as a mixed generation', () {
    final fixture = _copyMigrationSources();
    try {
      final legacy = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      final prefabTarget = legacy.targetFiles.singleWhere(
        (target) => target.sourceKind == 'prefabs',
      );
      File(
        p.join(fixture.path, p.normalize(prefabTarget.sourcePath)),
      ).writeAsStringSync(prefabTarget.canonicalContents);

      expect(
        () => PolygonAuthoringMigrationCheck.fromRepository(fixture.path),
        throwsA(
          isA<PolygonAuthoringMigrationCheckException>().having(
            (error) => error.code,
            'code',
            'migration_mixed_schema_generation',
          ),
        ),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('legacy and current chunk files cannot coexist', () {
    final fixture = _copyMigrationSources();
    try {
      final legacy = PolygonAuthoringMigrationCheck.fromRepository(
        fixture.path,
      );
      final chunkTarget = legacy.targetFiles.firstWhere(
        (target) => target.sourceKind == 'chunk',
      );
      File(
        p.join(fixture.path, p.normalize(chunkTarget.sourcePath)),
      ).writeAsStringSync(chunkTarget.canonicalContents);

      expect(
        () => PolygonAuthoringMigrationCheck.fromRepository(fixture.path),
        throwsA(
          isA<PolygonAuthoringMigrationCheckException>().having(
            (error) => error.code,
            'code',
            'migration_mixed_schema_generation',
          ),
        ),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('noncanonical current bytes fail before a no-op check is returned', () {
    final fixture = _copyMigrationSources();
    try {
      _promoteFixtureToCurrent(fixture.path);
      final chunkFile = _chunkFiles(fixture.path).first;
      chunkFile.writeAsStringSync('${chunkFile.readAsStringSync()}\n');

      expect(
        () => PolygonAuthoringMigrationCheck.fromRepository(fixture.path),
        throwsA(
          isA<PolygonAuthoringMigrationCheckException>().having(
            (error) => error.code,
            'code',
            'migration_current_source_noncanonical',
          ),
        ),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('current geometry is re-reviewed by the Core authority', () {
    final fixture = _copyMigrationSources();
    try {
      _promoteFixtureToCurrent(fixture.path);
      final chunkFile = _terrainChunkFile(fixture.path);
      final root =
          jsonDecode(chunkFile.readAsStringSync()) as Map<String, Object?>;
      final shapes = root['collisionShapes']! as List<Object?>;
      final shape = shapes.first! as Map<String, Object?>;
      shape['vertices'] = <Map<String, Object>>[
        <String, Object>{'x': 0, 'y': 0},
        <String, Object>{'x': 10, 'y': 10},
        <String, Object>{'x': 0, 'y': 10},
        <String, Object>{'x': 10, 'y': 0},
      ];
      chunkFile.writeAsStringSync(_canonicalJson(root));

      final check = PolygonAuthoringMigrationCheck.fromRepository(fixture.path);

      expect(check.hasBlockers, isTrue);
      expect(check.targetFiles, isEmpty);
      expect(
        check.issues.map((issue) => issue.code),
        contains('migration_current_geometry_self_intersection'),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

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

void _promoteFixtureToCurrent(String rootPath) {
  final legacy = PolygonAuthoringMigrationCheck.fromRepository(rootPath);
  expect(legacy.sourceState, PolygonAuthoringMigrationSourceState.legacy);
  expect(legacy.hasBlockers, isFalse);
  for (final target in legacy.targetFiles) {
    File(
      p.join(rootPath, p.normalize(target.sourcePath)),
    ).writeAsStringSync(target.canonicalContents);
  }
}

Map<String, String> _sourceDigests(String rootPath) => <String, String>{
  PrefabStore.prefabDefsPath: WorkspaceFileIo.sha256Digest(
    File(
      p.join(rootPath, p.normalize(PrefabStore.prefabDefsPath)),
    ).readAsStringSync(),
  ),
  for (final file in _chunkFiles(rootPath))
    p.relative(file.path, from: rootPath): WorkspaceFileIo.sha256Digest(
      file.readAsStringSync(),
    ),
};

List<File> _chunkFiles(String rootPath) {
  final files =
      Directory(p.join(rootPath, 'assets', 'authoring', 'level', 'chunks'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.extension(file.path).toLowerCase() == '.json')
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  return files;
}

File _terrainChunkFile(String rootPath) =>
    _chunkFiles(rootPath).firstWhere((file) {
      final root = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final shapes = root['collisionShapes'];
      return shapes is List<Object?> && shapes.isNotEmpty;
    });

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
