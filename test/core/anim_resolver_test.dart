import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/anim/anim_resolver.dart';
import 'package:rpg_runner/core/enemies/death_behavior.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  group('AnimResolver', () {
    const profile = AnimProfile(
      minMoveSpeed: 0.1,
      runSpeedThresholdX: 2.0,
      supportsWalk: true,
      supportsJumpFall: true,
      supportsDash: true,
      supportsCast: true,
      supportsRanged: true,
      supportsSpawn: true,
      supportsStun: true,
      directionalStrike: true,
    );

    test('spawn window is relative to spawnStartTick', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(
          tick: 102,
          hp: 1,
          grounded: true,
          spawnStartTick: 100,
          spawnAnimTicks: 5,
        ),
      );

      expect(result.anim, AnimKey.spawn);
      expect(result.animFrame, 2);
    });

    test('hp<=0 uses deathStartTick, not stale lastDamageTick', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.enemy(
          tick: 50,
          hp: 0,
          deathPhase: DeathPhase.none,
          deathStartTick: 40,
          lastDamageTick: 5,
        ),
      );

      expect(result.anim, AnimKey.death);
      expect(result.animFrame, 10);
    });

    test('hp<=0 without deathStartTick falls back to frame 0', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.enemy(
          tick: 50,
          hp: 0,
          deathPhase: DeathPhase.none,
          deathStartTick: -1,
          lastDamageTick: 10,
        ),
      );

      expect(result.anim, AnimKey.death);
      expect(result.animFrame, 0);
    });

    test('unknown active-action key falls through to locomotion', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(
          tick: 20,
          hp: 1,
          grounded: true,
          activeActionAnim: AnimKey.hit,
          activeActionFrame: 7,
        ),
      );

      expect(result.anim, AnimKey.idle);
      expect(result.animFrame, 20);
    });

    test('explicit one-off action keys remain allowed', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(
          tick: 20,
          hp: 1,
          grounded: true,
          activeActionAnim: AnimKey.parry,
          activeActionFrame: 3,
        ),
      );

      expect(result.anim, AnimKey.parry);
      expect(result.animFrame, 3);
    });

    test('future start tick is clamped to non-negative frame', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.enemy(
          tick: 10,
          hp: 1,
          deathPhase: DeathPhase.deathAnim,
          deathStartTick: 20,
        ),
      );

      expect(result.anim, AnimKey.death);
      expect(result.animFrame, 0);
    });

    test('jump frame uses global tick origin', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(tick: 31, hp: 1, grounded: false, velY: -10),
      );

      expect(result.anim, AnimKey.jump);
      expect(result.animFrame, 31);
    });

    test('fall frame uses global tick origin', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(tick: 32, hp: 1, grounded: false, velY: 10),
      );

      expect(result.anim, AnimKey.fall);
      expect(result.animFrame, 32);
    });

    test('idle frame uses global tick origin', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(tick: 33, hp: 1, grounded: true, velX: 0.0),
      );

      expect(result.anim, AnimKey.idle);
      expect(result.animFrame, 33);
    });

    test('walk frame uses global tick origin', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(tick: 34, hp: 1, grounded: true, velX: 1.0),
      );

      expect(result.anim, AnimKey.walk);
      expect(result.animFrame, 34);
    });

    test('run frame uses global tick origin', () {
      final result = AnimResolver.resolve(
        profile,
        AnimSignals.player(tick: 35, hp: 1, grounded: true, velX: 3.0),
      );

      expect(result.anim, AnimKey.run);
      expect(result.animFrame, 35);
    });
  });
}
