import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  test('hashash strike active window matches attack frames 9-10', () {
    const enemyCatalog = EnemyCatalog();
    final ability = AbilityCatalog.shared.resolve('hashash.strike');
    expect(ability, isNotNull);
    final strike = ability!;

    final renderAnim = enemyCatalog.get(EnemyId.hashash).renderAnim;
    final strikeFrames = renderAnim.frameCountsByKey[AnimKey.strike];
    final strikeStepSeconds = renderAnim.stepTimeSecondsByKey[AnimKey.strike];

    expect(strikeFrames, 13);
    expect(strikeStepSeconds, closeTo(0.06, 1e-9));

    const tickHz = 60;
    final ticksPerFrame = (strikeStepSeconds! * tickHz).round();
    expect(ticksPerFrame, 4);
    expect(strike.windupTicks % ticksPerFrame, 0);
    expect(strike.activeTicks % ticksPerFrame, 0);

    final activeStartFrame1Based = (strike.windupTicks ~/ ticksPerFrame) + 1;
    final activeFramesCount = strike.activeTicks ~/ ticksPerFrame;
    final activeEndFrame1Based = activeStartFrame1Based + activeFramesCount - 1;

    expect(activeStartFrame1Based, 9);
    expect(activeEndFrame1Based, 10);
  });

  test('hashash spawn animation uses row 12 with 8 frames', () {
    const enemyCatalog = EnemyCatalog();
    final archetype = enemyCatalog.get(EnemyId.hashash);
    final renderAnim = archetype.renderAnim;

    expect(archetype.animProfile.supportsSpawn, isTrue);
    expect(archetype.spawnAnimSeconds, closeTo(0.96, 1e-9));
    expect(renderAnim.rowByKey[AnimKey.spawn], 11);
    expect(renderAnim.frameCountsByKey[AnimKey.spawn], 8);
    expect(renderAnim.stepTimeSecondsByKey[AnimKey.spawn], closeTo(0.12, 1e-9));
  });
}
