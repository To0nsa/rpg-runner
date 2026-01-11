/// Shared player animation definitions (Core-owned, renderer consumes).
library;

import '../../snapshots/enums.dart';

const int playerAnimFrameWidth = 100;
const int playerAnimFrameHeight = 64;

const int playerAnimIdleFrames = 4;
const double playerAnimIdleStepSeconds = 0.14;

const int playerAnimRunFrames = 7;
const double playerAnimRunStepSeconds = 0.08;

const int playerAnimJumpFrames = 6;
const double playerAnimJumpStepSeconds = 0.10;

const int playerAnimFallFrames = 3;
const double playerAnimFallStepSeconds = 0.10;

const int playerAnimAttackFrames = 6;
const double playerAnimAttackStepSeconds = 0.06;

const int playerAnimCastFrames = 5;
const double playerAnimCastStepSeconds = 0.08;

const int playerAnimDashFrames = 4;
const double playerAnimDashStepSeconds = 0.05;

const int playerAnimHitFrames = 4;
const double playerAnimHitStepSeconds = 0.10;

const int playerAnimDeathFrames = 6;
const double playerAnimDeathStepSeconds = 0.12;

// Spawn reuses idle timing/frames until a dedicated strip exists.
const int playerAnimSpawnFrames = playerAnimIdleFrames;
const double playerAnimSpawnStepSeconds = playerAnimIdleStepSeconds;

const Map<AnimKey, int> playerAnimFrameCountsByKey = <AnimKey, int>{
  AnimKey.idle: playerAnimIdleFrames,
  AnimKey.run: playerAnimRunFrames,
  AnimKey.jump: playerAnimJumpFrames,
  AnimKey.fall: playerAnimFallFrames,
  AnimKey.attack: playerAnimAttackFrames,
  AnimKey.cast: playerAnimCastFrames,
  AnimKey.dash: playerAnimDashFrames,
  AnimKey.hit: playerAnimHitFrames,
  AnimKey.death: playerAnimDeathFrames,
  AnimKey.spawn: playerAnimSpawnFrames,
};

const Map<AnimKey, double> playerAnimStepTimeSecondsByKey = <AnimKey, double>{
  AnimKey.idle: playerAnimIdleStepSeconds,
  AnimKey.run: playerAnimRunStepSeconds,
  AnimKey.jump: playerAnimJumpStepSeconds,
  AnimKey.fall: playerAnimFallStepSeconds,
  AnimKey.attack: playerAnimAttackStepSeconds,
  AnimKey.cast: playerAnimCastStepSeconds,
  AnimKey.dash: playerAnimDashStepSeconds,
  AnimKey.hit: playerAnimHitStepSeconds,
  AnimKey.death: playerAnimDeathStepSeconds,
  AnimKey.spawn: playerAnimSpawnStepSeconds,
};

const double playerAnimHitSeconds =
    playerAnimHitFrames * playerAnimHitStepSeconds;
const double playerAnimCastSeconds =
    playerAnimCastFrames * playerAnimCastStepSeconds;
const double playerAnimAttackSeconds =
    playerAnimAttackFrames * playerAnimAttackStepSeconds;
const double playerAnimDeathSeconds =
    playerAnimDeathFrames * playerAnimDeathStepSeconds;
const double playerAnimSpawnSeconds =
    playerAnimSpawnFrames * playerAnimSpawnStepSeconds;
