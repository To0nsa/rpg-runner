import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_view_preferences.dart';

void main() {
  test(
    'view preferences are workspace isolated and retain only safe fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'level-view-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = LevelCreatorViewStore.at(directory.path);
      await store.write(
        '/workspace/one',
        const LevelCreatorReturnContext(
          levelId: 'cave',
          tab: LevelCreatorTab.flow,
          groupFilter: 'bridges',
          selectedChunkKey: 'not-persisted',
          selectedSegmentId: 'not-persisted',
          previewSeed: 999,
        ),
      );
      final restored = await store.read('/workspace/one');
      expect(restored!.levelId, 'cave');
      expect(restored.tab, LevelCreatorTab.flow);
      expect(restored.groupFilter, 'bridges');
      expect(restored.selectedChunkKey, isNull);
      expect(restored.selectedSegmentId, isNull);
      expect(restored.previewSeed, 4401);
      expect(await store.read('/workspace/two'), isNull);
      final file = directory.listSync().whereType<File>().single;
      expect((jsonDecode(await file.readAsString()) as Map).keys.toSet(), {
        'version',
        'levelId',
        'tab',
        'groupFilter',
      });
      await file.writeAsString('{incomplete');
      expect(await store.read('/workspace/one'), isNull);
    },
  );

  test('rapid preference updates finish with the most recent view', () async {
    final directory = await Directory.systemTemp.createTemp(
      'level-view-order-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = LevelCreatorViewStore.at(directory.path);
    await Future.wait([
      store.write(
        '/workspace',
        const LevelCreatorReturnContext(levelId: 'forest'),
      ),
      store.write(
        '/workspace',
        const LevelCreatorReturnContext(
          levelId: 'cave',
          tab: LevelCreatorTab.appearance,
        ),
      ),
    ]);
    expect((await store.read('/workspace'))!.levelId, 'cave');
    expect((await store.read('/workspace'))!.tab, LevelCreatorTab.appearance);
  });
}
