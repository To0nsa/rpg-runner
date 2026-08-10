import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';
import 'package:path/path.dart' as path;

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final repositoryRoot = _findRepositoryRoot();
    final revision = Process.runSync('git', const <String>[
      'rev-parse',
      'HEAD',
    ], workingDirectory: repositoryRoot.path);
    final status = Process.runSync('git', const <String>[
      'status',
      '--porcelain',
      '--untracked-files=all',
    ], workingDirectory: repositoryRoot.path);
    if (revision.exitCode != 0 || status.exitCode != 0) {
      throw StateError('Could not read benchmark repository identity.');
    }
    final report = <String, dynamic>{
      ...?data,
      'revision': (revision.stdout as String).trim(),
      'dirty': (status.stdout as String).trim().isNotEmpty,
      'driverOs': Platform.operatingSystem,
      'driverOsVersion': Platform.operatingSystemVersion,
      'driverRuntime': Platform.version,
    };
    await writeResponseData(
      report,
      testOutputFilename: 'slopes_phase4_polygon_interaction',
      destinationDirectory: path.join(repositoryRoot.path, '.tmp'),
    );
  },
);

Directory _findRepositoryRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (Directory(path.join(current.path, '.git')).existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Could not locate repository root from ${Directory.current.path}.',
      );
    }
    current = parent;
  }
}
