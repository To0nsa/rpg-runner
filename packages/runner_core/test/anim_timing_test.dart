import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/utils/anim_tuning.dart' as anim_tuning;
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

void main() {
  const renderAnim = RenderAnimSetDefinition(
    frameWidth: 1,
    frameHeight: 1,
    anchorPoint: Vec2(0, 0),
    sourcesByKey: <AnimKey, String>{
      AnimKey.idle: 'idle.png',
      AnimKey.hit: 'hit.png',
      AnimKey.death: 'death.png',
      AnimKey.spawn: 'spawn.png',
    },
    frameCountsByKey: <AnimKey, int>{
      AnimKey.idle: 1,
      AnimKey.hit: 4,
      AnimKey.death: 6,
      AnimKey.spawn: 4,
    },
    stepTimeSecondsByKey: <AnimKey, double>{
      AnimKey.idle: 0.1,
      AnimKey.hit: 0.10,
      AnimKey.death: 0.12,
      AnimKey.spawn: 0.14,
    },
  );

  test('strip duration matches the renderer frame quantization', () {
    expect(
      anim_tuning.ticksForKey(
        key: AnimKey.hit,
        frameCounts: renderAnim.frameCountsByKey,
        stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
        tickHz: 60,
      ),
      24,
    );
    expect(
      anim_tuning.ticksForKey(
        key: AnimKey.death,
        frameCounts: renderAnim.frameCountsByKey,
        stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
        tickHz: 60,
      ),
      42,
    );
    expect(
      anim_tuning.ticksForKey(
        key: AnimKey.spawn,
        frameCounts: renderAnim.frameCountsByKey,
        stepTimeSecondsByKey: renderAnim.stepTimeSecondsByKey,
        tickHz: 60,
      ),
      32,
    );
  });

  test('player lifecycle windows use render-strip timing when available', () {
    final derived = AnimTuningDerived.from(
      const AnimTuning(
        hitAnimSeconds: 0.40,
        deathAnimSeconds: 0.72,
        spawnAnimSeconds: 0.56,
      ),
      tickHz: 60,
      renderAnim: renderAnim,
    );

    expect(derived.hitAnimTicks, 24);
    expect(derived.deathAnimTicks, 42);
    expect(derived.spawnAnimTicks, 32);
  });
}
