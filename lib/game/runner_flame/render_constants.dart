import '../tuning/player_render_tuning.dart';

const int priorityBackgroundParallax = -30;
const int priorityTemporaryFloorMask = -25;
const int priorityGroundTiles = -20;
const int priorityForegroundParallax = -10;
const int priorityStaticSolids = -5;
const int priorityGhostEntities = -4;
const int priorityPlayer = -3;
const int priorityEnemies = -2;
const int priorityProjectiles = -1;
const int priorityCollectibles = -1;
const int priorityHitboxes = 1;
const int priorityActorHitboxes = 2;
const int priorityProjectileAimRay = 5;
const int priorityMeleeAimRay = 6;

const PlayerRenderTuning runnerPlayerRenderTuning = PlayerRenderTuning();
const int damageForMaxShake100 = 1500;
const int visualCueIntensityScaleBp = 10000;
