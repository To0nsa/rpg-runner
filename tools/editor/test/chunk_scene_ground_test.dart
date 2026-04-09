import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/widgets/chunk_scene_ground.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';

void main() {
  test(
    'buildChunkGroundLayoutWithFillDepth splits solid spans around clamped gaps',
    () {
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

    final layout = buildChunkGroundLayoutWithFillDepth(chunk, fillDepth: 15);

    expect(
      layout.solidWorldRects,
      <Rect>[
        const Rect.fromLTWH(32, 224, 288, 15),
        const Rect.fromLTWH(480, 224, 100, 15),
      ],
    );
    expect(
      layout.gapWorldRects,
      <Rect>[
        const Rect.fromLTWH(0, 224, 32, 15),
        const Rect.fromLTWH(320, 224, 160, 15),
        const Rect.fromLTWH(580, 224, 20, 15),
      ],
    );
    },
  );

  test('buildChunkGroundLayoutWithFillDepth clamps overlarge depth to viewport', () {
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
    );

    final layout = buildChunkGroundLayoutWithFillDepth(chunk, fillDepth: 80);

    expect(
      layout.solidWorldRects,
      <Rect>[const Rect.fromLTWH(0, 224, 600, 46)],
    );
    expect(layout.gapWorldRects, isEmpty);
  });

  test('resolveChunkGroundMaterialSpec mirrors runtime ground assets', () {
    expect(
      resolveChunkGroundMaterialSpec('field').sourceImagePath,
      'assets/images/parallax/field/Field Layer 09.png',
    );
    expect(
      resolveChunkGroundMaterialSpec('forest').sourceImagePath,
      'assets/images/parallax/forest/Forest Layer 04.png',
    );
    expect(
      resolveChunkGroundMaterialSpec('unknown').sourceImagePath,
      'assets/images/parallax/field/Field Layer 09.png',
    );
  });
}
