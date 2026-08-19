import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/playtest/runner_workspace_asset_bundle.dart';

void main() {
  test(
    'reads nested workspace assets without modifying the workspace',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'runner-workspace-bundle-',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final image = File(
        '${workspace.path}${Platform.pathSeparator}assets'
        '${Platform.pathSeparator}images${Platform.pathSeparator}pixel.bin',
      );
      await image.parent.create(recursive: true);
      await image.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
      final before = await _workspaceRecord(workspace);
      final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: workspace.path);

      final first = await bundle.load('assets/images/pixel.bin');
      first.setUint8(0, 99);
      final second = await bundle.load('assets/images/pixel.bin');
      final after = await _workspaceRecord(workspace);

      expect(second.buffer.asUint8List(), <int>[1, 2, 3, 4]);
      expect(after, before);
      expect(bundle.workspaceRoot, await workspace.resolveSymbolicLinks());
      expect(
        bundle.assetRoot,
        await Directory(
          '${workspace.path}${Platform.pathSeparator}assets',
        ).resolveSymbolicLinks(),
      );
    },
  );

  test('rejects non-canonical and non-asset keys', () async {
    final workspace = await _workspace();
    addTearDown(() => workspace.delete(recursive: true));
    final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: workspace.path);

    for (final key in <String>[
      '',
      'images/pixel.bin',
      '/assets/images/pixel.bin',
      r'assets\images\pixel.bin',
      'assets/../secret.bin',
      'assets/./pixel.bin',
      'assets//pixel.bin',
      'C:/assets/pixel.bin',
      'file:///assets/pixel.bin',
    ]) {
      await expectLater(
        bundle.load(key),
        throwsA(
          isA<RunnerWorkspaceAssetException>().having(
            (error) => error.code,
            'code for $key',
            'runner_asset_key_invalid',
          ),
        ),
      );
    }
  });

  test('distinguishes missing roots, asset directories, and files', () async {
    final parent = await Directory.systemTemp.createTemp(
      'runner-workspace-errors-',
    );
    addTearDown(() => parent.delete(recursive: true));

    expect(
      () => RunnerWorkspaceAssetBundle(
        workspaceRoot:
            '${parent.path}${Platform.pathSeparator}missing-workspace',
      ),
      throwsA(
        isA<RunnerWorkspaceAssetException>().having(
          (error) => error.code,
          'code',
          'runner_workspace_root_missing',
        ),
      ),
    );
    expect(
      () => RunnerWorkspaceAssetBundle(workspaceRoot: parent.path),
      throwsA(
        isA<RunnerWorkspaceAssetException>().having(
          (error) => error.code,
          'code',
          'runner_workspace_assets_missing',
        ),
      ),
    );

    await Directory('${parent.path}${Platform.pathSeparator}assets').create();
    final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: parent.path);
    await expectLater(
      bundle.load('assets/images/missing.png'),
      throwsA(
        isA<RunnerWorkspaceAssetException>().having(
          (error) => error.code,
          'code',
          'runner_asset_missing',
        ),
      ),
    );
  });

  test('rejects a symlink that resolves outside the asset root', () async {
    final workspace = await _workspace();
    final external = await Directory.systemTemp.createTemp(
      'runner-workspace-external-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    addTearDown(() => external.delete(recursive: true));
    final secret = File('${external.path}${Platform.pathSeparator}secret.bin');
    await secret.writeAsBytes(<int>[7, 8, 9]);
    final link = Link(
      '${workspace.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}escape.bin',
    );
    try {
      await link.create(secret.path);
    } on FileSystemException {
      return;
    }
    final bundle = RunnerWorkspaceAssetBundle(workspaceRoot: workspace.path);

    await expectLater(
      bundle.load('assets/escape.bin'),
      throwsA(
        isA<RunnerWorkspaceAssetException>().having(
          (error) => error.code,
          'code',
          'runner_asset_escape',
        ),
      ),
    );
  });
}

Future<Directory> _workspace() async {
  final workspace = await Directory.systemTemp.createTemp(
    'runner-workspace-bundle-',
  );
  await Directory('${workspace.path}${Platform.pathSeparator}assets').create();
  return workspace;
}

Future<List<String>> _workspaceRecord(Directory workspace) async {
  final records = <String>[];
  await for (final entity in workspace.list(
    recursive: true,
    followLinks: false,
  )) {
    final relative = entity.path.substring(workspace.path.length);
    if (entity is File) {
      records.add('$relative|${(await entity.readAsBytes()).join(',')}');
    } else if (entity is Link) {
      records.add('$relative|link:${await entity.target()}');
    } else {
      records.add('$relative|directory');
    }
  }
  records.sort();
  return records;
}
