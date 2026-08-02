import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/generated_artifact_plan.dart';

void main() {
  test('drift inspection is sorted, exact, and write-free', () async {
    final root = Directory.systemTemp.createTempSync('generated_plan_drift_');
    addTearDown(() => root.deleteSync(recursive: true));
    final aPath = _path(root, 'a.dart');
    final bPath = _path(root, 'nested/b.dart');
    final orphanPath = _path(root, 'orphan.dart');
    File(aPath).writeAsBytesSync(const <int>[0xFF]);
    File(orphanPath).writeAsStringSync('// owned-generator-marker\n');
    final before = File(aPath).readAsBytesSync();
    final source = <GeneratedArtifact>[
      GeneratedArtifact(path: bPath, content: 'b\n'),
      GeneratedArtifact(path: aPath, content: 'a\n'),
    ];
    final plan = GeneratedArtifactPlan(
      source,
      ownershipMarker: 'owned-generator-marker',
      ownershipSearchRoots: <String>[root.path],
    );
    source.clear();

    final drift = await plan.inspectDrift();

    expect(plan.artifacts.map((artifact) => artifact.path), <String>[
      aPath,
      bPath,
    ]);
    expect(
      drift.map((item) => (item.path, item.kind, item.code)),
      <(String, GeneratedArtifactDriftKind, String)>[
        (
          _displayPath(aPath),
          GeneratedArtifactDriftKind.stale,
          'generated_output_stale',
        ),
        (
          _displayPath(bPath),
          GeneratedArtifactDriftKind.missing,
          'generated_output_missing',
        ),
        (
          _displayPath(orphanPath),
          GeneratedArtifactDriftKind.unexpected,
          'generated_output_unexpected',
        ),
      ],
    );
    expect(File(aPath).readAsBytesSync(), before);
    expect(File(bPath).existsSync(), isFalse);
  });

  test(
    'write uses rendered plan and makes the next exact check clean',
    () async {
      final root = Directory.systemTemp.createTempSync('generated_plan_write_');
      addTearDown(() => root.deleteSync(recursive: true));
      final plan = GeneratedArtifactPlan(<GeneratedArtifact>[
        GeneratedArtifact(path: _path(root, 'z.dart'), content: 'z\n'),
        GeneratedArtifact(path: _path(root, 'nested/a.dart'), content: 'a\n'),
      ]);

      await plan.writeAll();

      expect(File(_path(root, 'z.dart')).readAsStringSync(), 'z\n');
      expect(File(_path(root, 'nested/a.dart')).readAsStringSync(), 'a\n');
      expect(await plan.inspectDrift(), isEmpty);
    },
  );

  test('empty and duplicate output paths fail before filesystem access', () {
    expect(
      () => GeneratedArtifactPlan(const <GeneratedArtifact>[
        GeneratedArtifact(path: '', content: ''),
      ]),
      throwsArgumentError,
    );
    expect(
      () => GeneratedArtifactPlan(const <GeneratedArtifact>[
        GeneratedArtifact(path: 'same.dart', content: 'a'),
        GeneratedArtifact(path: 'same.dart', content: 'b'),
      ]),
      throwsArgumentError,
    );
  });
}

String _path(Directory root, String relative) =>
    '${root.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

String _displayPath(String path) => path.replaceAll('\\', '/');
