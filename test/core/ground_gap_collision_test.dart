import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/contracts/render_contract.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void _tick(GameCore core) {
  core.stepOneTick();
}

void main() {
  test('ground collision ignores gaps between segments', () {
    const topY = groundTopY * 1.0;
    const r = 8.0;

    final core = GameCore(
      seed: 1,
      tickHz: defaultTickHz,
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
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
      playerCharacter: PlayerCharacterRegistry.eloise.copyWith(
        catalog: PlayerCatalog(colliderWidth: r * 2, colliderHeight: r * 2),
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
