import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('snapshot includes static solids for rendering', () {
    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: 255),
      solids: <StaticSolid>[
        StaticSolid(
          minX: 10,
          minY: 20,
          maxX: 30,
          maxY: 40,
          sides: StaticSolid.sideAll,
          oneWayTop: false,
        ),
      ],
    );

    final core = GameCore(
      seed: 1,
      staticWorldGeometry: geometry,
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
    );
    final snapshot = core.buildSnapshot();

    expect(snapshot.staticSolids, hasLength(1));
    final s = snapshot.staticSolids.single;
    expect(s.minX, 10);
    expect(s.minY, 20);
    expect(s.maxX, 30);
    expect(s.maxY, 40);
    expect(s.sides, StaticSolid.sideAll);
    expect(s.oneWayTop, isFalse);
  });
}
