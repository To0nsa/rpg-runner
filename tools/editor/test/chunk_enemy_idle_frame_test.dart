import 'dart:ui';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_enemy_idle_frame.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_view_utils.dart';
import 'package:runner_editor/src/chunks/chunk_marker_authoring_catalog.dart';

void main() {
  test('runtime destination aligns the scaled idle anchor to the body', () {
    final enemy = chunkMarkerEnemyCatalogEntryFor('grojib')!;
    final frame = ChunkEnemyIdleFrame.fromEnemy(
      enemy: enemy,
      workspaceRootPath: r'C:\workspace',
    )!;

    expect(frame.sourceRect, const Rect.fromLTWH(0, 0, 108, 59));
    expect(frame.renderScale, 1.5);

    final destination = frame.runtimeDestination(
      bodyPoint: const Offset(400, 300),
      sceneZoom: 2,
    );
    expect(destination.left, 169);
    expect(destination.top, 210);
    expect(destination.width, 324);
    expect(destination.height, 177);
    expect(destination.topLeft + frame.anchorPoint * 3, const Offset(400, 300));
  });

  test('thumbnail and scene projections share the Core idle frame crop', () {
    final enemy = chunkMarkerEnemyCatalogEntryFor('unocoDemon')!;
    final frame = ChunkEnemyIdleFrame.fromEnemy(
      enemy: enemy,
      workspaceRootPath: r'C:\workspace',
    )!;

    expect(frame.sourceRect, const Rect.fromLTWH(0, 0, 81, 71));
    expect(frame.renderScale, 0.5);
    expect(
      frame.absoluteSourcePath.replaceAll('\\', '/'),
      endsWith('assets/images/entities/enemies/unoco/flying.png'),
    );
    final thumbnail = frame.thumbnailDestination(
      const Rect.fromLTWH(0, 0, 100, 100),
    );
    expect(thumbnail.left, 8);
    expect(thumbnail.top, closeTo(13.185185185185183, 0.000001));
    expect(thumbnail.width, 84);
    expect(thumbnail.height, closeTo(73.62962962962963, 0.000001));
  });

  testWidgets('workspace image cache decodes the authored enemy sheet', (
    tester,
  ) async {
    final repositoryRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    final imagePath = p.join(
      repositoryRoot,
      'assets',
      'images',
      'entities',
      'enemies',
      'grojib',
      'grojib.png',
    );
    final cache = EditorUiImageCache();
    addTearDown(cache.dispose);

    final image = await tester.runAsync(() => cache.ensureLoaded(imagePath));

    expect(image, isNotNull);
    expect(image!.width, greaterThanOrEqualTo(108));
    expect(image.height, greaterThanOrEqualTo(59));
  });
}
