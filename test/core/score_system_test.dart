import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/tuning/v0_score_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('score increases deterministically per tick', () {
    final core = GameCore(
      seed: 1,
      cameraTuning: noAutoscrollCameraTuning,
      scoreTuning: const V0ScoreTuning(timeScorePerSecond: 60),
    );

    expect(core.score, 0);

    core.stepOneTick();
    expect(core.score, 1);

    core.stepOneTick();
    expect(core.score, 2);
  });

  test('score does not increase on the death tick', () {
    final core = GameCore(
      seed: 1,
      cameraTuning: noAutoscrollCameraTuning,
      scoreTuning: const V0ScoreTuning(timeScorePerSecond: 60),
    );

    core.setPlayerPosXY(-1000, core.playerPosY);
    core.stepOneTick();

    expect(core.gameOver, isTrue);
    expect(core.score, 0);
  });
}
