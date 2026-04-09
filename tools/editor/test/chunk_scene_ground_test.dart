import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/widgets/chunk_scene_ground.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('buildChunkGroundLayout splits solid spans around clamped gaps', () {
    const chunk = LevelChunkDef(
      chunkKey: 'chunk_ground',
      id: 'chunk_ground',
      revision: 1,
      schemaVersion: 1,
      levelId: 'field',
      tileSize: 16,
      width: 600,
      height: 270,
      difficulty: chunkDifficultyNormal,
      groundProfile: GroundProfileDef(kind: groundProfileKindFlat, topY: 224),
      groundGaps: <GroundGapDef>[
        GroundGapDef(gapId: 'gap_a', x: -16, width: 48),
        GroundGapDef(gapId: 'gap_b', x: 320, width: 160),
        GroundGapDef(gapId: 'gap_c', x: 580, width: 64),
      ],
    );

    final layout = buildChunkGroundLayout(chunk);

    expect(
      layout.solidWorldRects,
      <Rect>[
        const Rect.fromLTWH(32, 224, 288, 46),
        const Rect.fromLTWH(480, 224, 100, 46),
      ],
    );
    expect(
      layout.gapWorldRects,
      <Rect>[
        const Rect.fromLTWH(0, 224, 32, 46),
        const Rect.fromLTWH(320, 224, 160, 46),
        const Rect.fromLTWH(580, 224, 20, 46),
      ],
    );
  });

  test('resolveChunkGroundTheme prefers ground-like tiles by descending width', () {
    final theme = resolveChunkGroundTheme(const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'village_flag',
        sourceImagePath: 'assets/images/props.png',
        x: 0,
        y: 0,
        width: 48,
        height: 48,
      ),
      AtlasSliceDef(
        id: 'grass_dirt_32x32',
        sourceImagePath: 'assets/images/level/tileset/TX Tileset Ground.png',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
      ),
      AtlasSliceDef(
        id: 'grass_dirt_96x32_square',
        sourceImagePath: 'assets/images/level/tileset/TX Tileset Ground.png',
        x: 0,
        y: 32,
        width: 96,
        height: 32,
      ),
      AtlasSliceDef(
        id: 'grass_dirt_64x32',
        sourceImagePath: 'assets/images/level/tileset/TX Tileset Ground.png',
        x: 0,
        y: 64,
        width: 64,
        height: 32,
      ),
    ]);

    expect(
      theme.surfaceSlices.map((slice) => slice.id).toList(),
      <String>[
        'grass_dirt_96x32_square',
        'grass_dirt_64x32',
        'grass_dirt_32x32',
      ],
    );
    expect(theme.bodySlice?.id, 'grass_dirt_96x32_square');
    expect(theme.capHeightPx, 16);
  });
}
