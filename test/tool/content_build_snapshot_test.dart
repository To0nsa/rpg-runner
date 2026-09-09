import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_build_report.dart';

void main() {
  test(
    'snapshot freezes exact saved bytes and detects image and file-set drift',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'content_build_snapshot_',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      File source(String path, List<int> bytes) {
        final file = File('${root.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes);
        return file;
      }

      final json = source('assets/authoring/level/level_defs.json', [123, 125]);
      final image = source('assets/images/parallax/theme/layer_00.png', [
        1,
        2,
        3,
      ]);
      final generated = source(
        'packages/runner_core/lib/levels/level_id.dart',
        [1],
      );
      final snapshot = await ContentBuildSnapshot.capture(
        workspaceRoot: root.path,
      );
      expect(
        snapshot.readString('assets/authoring/level/level_defs.json'),
        '{}',
      );
      final copied = snapshot.readBytes(
        'assets/images/parallax/theme/layer_00.png',
      );
      copied[0] = 99;
      expect(snapshot.readBytes('assets/images/parallax/theme/layer_00.png'), [
        1,
        2,
        3,
      ]);
      generated.writeAsBytesSync([2]);
      await snapshot.verifyCurrent();
      image.writeAsBytesSync([4, 5, 6]);
      await expectLater(
        snapshot.verifyCurrent(),
        throwsA(isA<ContentBuildInterruption>()),
      );
      image.writeAsBytesSync([1, 2, 3]);
      await snapshot.verifyCurrent();
      final added = source('assets/authoring/level/chunks/draft/new.json', [
        123,
        125,
      ]);
      await expectLater(
        snapshot.verifyCurrent(),
        throwsA(isA<ContentBuildInterruption>()),
      );
      added.deleteSync();
      json.deleteSync();
      expect(
        snapshot.readString('assets/authoring/level/level_defs.json'),
        '{}',
      );
      await expectLater(
        snapshot.verifyCurrent(),
        throwsA(isA<ContentBuildInterruption>()),
      );
    },
  );
}
