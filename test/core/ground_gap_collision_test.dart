import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/collision/static_world_geometry.dart';
import 'package:walkscape_runner/core/contracts/render_contract.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/tuning/player/player_movement_tuning.dart';
import 'package:walkscape_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void _tick(GameCore core) {
  core.stepOneTick();
}

void main() {
  test('ground collision ignores gaps between segments', () {
    const topY = groundTopY * 1.0;
    const r = 8.0;

    final core = GameCore.withTunings(
      seed: 1,
      tickHz: defaultTickHz,
      cameraTuning: noAutoscrollCameraTuning,
      trackTuning: const TrackTuning(enabled: false),
      playerCatalog: const PlayerCatalog(colliderWidth: r * 2, colliderHeight: r * 2),
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: topY),
        groundSegments: <StaticGroundSegment>[
          StaticGroundSegment(
            minX: 0,
            maxX: 120,
            topY: groundTopY * 1.0,
            chunkIndex: 0,
            localSegmentIndex: 0,
          ),
          StaticGroundSegment(
            minX: 200,
            maxX: 320,
            topY: groundTopY * 1.0,
            chunkIndex: 0,
            localSegmentIndex: 1,
          ),
        ],
        groundGaps: <StaticGroundGap>[
          StaticGroundGap(minX: 120, maxX: 200),
        ],
      ),
    );

    core.setPlayerPosXY(160, groundTopY - r - 60);
    core.setPlayerVelXY(0, 0);

    _tick(core);
    expect(core.playerGrounded, isFalse);

    for (var i = 0; i < 30; i += 1) {
      _tick(core);
    }

    expect(core.playerGrounded, isFalse);
    expect(core.playerPosY, greaterThan(groundTopY - r));
  });
}
