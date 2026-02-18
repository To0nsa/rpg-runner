import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('snapshot preserves explicit authored ground surface spans', () {
    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: 220),
      groundSegments: <StaticGroundSegment>[
        StaticGroundSegment(
          minX: 10,
          maxX: 50,
          topY: 220,
          chunkIndex: 4,
          localSegmentIndex: 1,
        ),
        StaticGroundSegment(
          minX: 80,
          maxX: 140,
          topY: 220,
          chunkIndex: 4,
          localSegmentIndex: 2,
        ),
      ],
      groundGaps: <StaticGroundGap>[StaticGroundGap(minX: 50, maxX: 80)],
    );

    final core = GameCore(
      levelDefinition: testFieldLevel(
        staticWorldGeometry: geometry,
        tuning: const CoreTuning(
          camera: noAutoscrollCameraTuning,
          track: TrackTuning(enabled: false),
        ),
      ),
      playerCharacter: testPlayerCharacter,
      seed: 1,
    );
    final snapshot = core.buildSnapshot();

    expect(snapshot.groundSurfaces, hasLength(2));

    final first = snapshot.groundSurfaces[0];
    expect(first.minX, 10);
    expect(first.maxX, 50);
    expect(first.topY, 220);
    expect(first.chunkIndex, 4);
    expect(first.localSegmentIndex, 1);

    final second = snapshot.groundSurfaces[1];
    expect(second.minX, 80);
    expect(second.maxX, 140);
    expect(second.topY, 220);
    expect(second.chunkIndex, 4);
    expect(second.localSegmentIndex, 2);
  });

  test(
    'snapshot derives plane-minus-gap surfaces when no segments authored',
    () {
      const geometry = StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: 300),
        groundGaps: <StaticGroundGap>[
          StaticGroundGap(minX: 100, maxX: 120),
          StaticGroundGap(minX: 150, maxX: 170),
        ],
      );

      final core = GameCore(
        levelDefinition: testFieldLevel(
          staticWorldGeometry: geometry,
          tuning: const CoreTuning(
            camera: noAutoscrollCameraTuning,
            track: TrackTuning(enabled: false),
          ),
        ),
        playerCharacter: testPlayerCharacter,
        seed: 7,
      );
      final snapshot = core.buildSnapshot();

      expect(snapshot.groundSurfaces, hasLength(3));

      final first = snapshot.groundSurfaces[0];
      expect(first.minX, double.negativeInfinity);
      expect(first.maxX, 100);
      expect(first.topY, 300);
      expect(first.chunkIndex, StaticSolid.groundChunk);
      expect(first.localSegmentIndex, 0);

      final second = snapshot.groundSurfaces[1];
      expect(second.minX, 120);
      expect(second.maxX, 150);
      expect(second.topY, 300);
      expect(second.chunkIndex, StaticSolid.groundChunk);
      expect(second.localSegmentIndex, 1);

      final third = snapshot.groundSurfaces[2];
      expect(third.minX, 170);
      expect(third.maxX, double.infinity);
      expect(third.topY, 300);
      expect(third.chunkIndex, StaticSolid.groundChunk);
      expect(third.localSegmentIndex, 2);
    },
  );
}
