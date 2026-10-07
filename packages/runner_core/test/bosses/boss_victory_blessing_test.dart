import 'package:runner_core/bosses/boss_victory_blessing_system.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/death_state_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/interactions/level_blessing.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/track/chunk_pattern_tier.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('easy restores 20 percent once, rounds down and caps at $hz Hz', () {
      final f = _Fixture();
      f.world.health.hpMax[0] = 10001;
      f.world.mana.manaMax[0] = 11501;
      f.world.stamina.staminaMax[0] = 13001;
      final blessing = BossVictoryBlessingSystem(tickHz: hz)
        ..request(3, ChunkPatternTier.easy);
      blessing.step(f.world, player: f.player, tick: 100, emit: f.events.add);
      expect(f.resources, [4000, 3300, 3600]);
      expect(blessing.snapshot(100)!.restorationBp, 2000);
      blessing.request(3, ChunkPatternTier.hard);
      blessing.step(f.world, player: f.player, tick: 101, emit: f.events.add);
      expect(f.resources, [4000, 3300, 3600]);
      expect(f.events, hasLength(1));
      f.world.health.hp[0] = 9500;
      f.world.mana.mana[0] = 11000;
      f.world.stamina.stamina[0] = 12500;
      blessing.request(4, ChunkPatternTier.easy);
      blessing.step(f.world, player: f.player, tick: 102, emit: f.events.add);
      expect(f.resources, [10001, 11501, 13001]);
    });
    test(
      'restores 60 percent of maxima once and preserves shrine rates at $hz Hz',
      () {
        final f = _Fixture();
        f.world.levelBlessings.grant(
          f.player,
          LevelBlessingId.regeneration,
          tick: 1,
        );
        final blessing = BossVictoryBlessingSystem(tickHz: hz);
        blessing.request(3, ChunkPatternTier.normal);
        blessing.step(f.world, player: f.player, tick: 100, emit: f.events.add);
        expect(f.resources, [8000, 7900, 8800]);
        expect(f.world.health.regenAccumulator.single, 7);
        expect(f.world.levelBlessings.healthRegen100.single, 10);
        expect(f.world.health.regenPerSecond100.single, 50);
        final event = f.events.single as SpellImpactEvent;
        expect(event.impactId, SpellImpactId.holyBlessing);
        expect(event.pos, const Vec2(120, 224));
        expect(event.followEntityId, f.player);
        expect(event.followOffset, const Vec2(0, 24));
        final notice = blessing.snapshot(100)!;
        expect(notice.restorationBp, 6000);
        expect(
          notice.durationTicks,
          hz == 30
              ? 32
              : hz == 60
              ? 48
              : 80,
        );
        expect(blessing.snapshot(100), same(notice));
        expect(blessing.snapshot(100 + notice.durationTicks), isNull);
        blessing.request(3, ChunkPatternTier.normal);
        blessing.step(f.world, player: f.player, tick: 101, emit: f.events.add);
        expect(f.resources, [8000, 7900, 8800]);
        expect(f.events, hasLength(1));
        blessing.request(4, ChunkPatternTier.hard);
        blessing.step(f.world, player: f.player, tick: 102, emit: f.events.add);
        expect(f.resources, [10000, 11500, 13000]);
        expect(f.events, hasLength(2));
        blessing.endRun();
        expect(blessing.snapshot(102), isNull);
      },
    );
  }

  test(
    'fatal damage, dying actors and destroyed owners cannot receive the reward',
    () {
      for (final failure in ['dead', 'dying', 'destroyed']) {
        final f = _Fixture();
        if (failure == 'dead') f.world.health.hp[0] = 0;
        if (failure == 'dying') {
          f.world.deathState.add(
            f.player,
            const DeathStateDef(phase: DeathPhase.deathAnim),
          );
        }
        if (failure == 'destroyed') f.world.destroyEntity(f.player);
        final blessing = BossVictoryBlessingSystem(tickHz: 60)
          ..request(3, ChunkPatternTier.easy);
        blessing.step(f.world, player: f.player, tick: 100, emit: f.events.add);
        expect(f.events, isEmpty, reason: failure);
        expect(blessing.snapshot(100), isNull, reason: failure);
        if (failure == 'dead') expect(f.resources, [0, 1000, 1000]);
      }
    },
  );

  test('odd maxima round down in fixed point and full resources still show blessing', () {
    final f = _Fixture();
    f.world.health.hpMax[0] = 10001;
    f.world.mana.manaMax[0] = 11501;
    f.world.stamina.staminaMax[0] = 13001;
    final blessing = BossVictoryBlessingSystem(tickHz: 60)
      ..request(3, ChunkPatternTier.normal);
    blessing.step(f.world, player: f.player, tick: 100, emit: f.events.add);
    expect(f.resources, [8000, 7900, 8800]);
    f.world.health.hp[0] = 10001;
    f.world.mana.mana[0] = 11501;
    f.world.stamina.stamina[0] = 13001;
    blessing.request(4, ChunkPatternTier.normal);
    blessing.step(f.world, player: f.player, tick: 101, emit: f.events.add);
    expect(f.resources, [10001, 11501, 13001]);
    expect(f.events, hasLength(2));
  });
}

class _Fixture {
  _Fixture() {
    player = world.createEntity();
    world.transform.add(player, posX: 120, posY: 200, velX: 0, velY: 0);
    world.colliderAabb.add(player, const ColliderAabbDef(halfX: 8, halfY: 24));
    world.health.add(
      player,
      const HealthDef(hp: 2000, hpMax: 10000, regenPerSecond100: 50),
    );
    world.mana.add(
      player,
      const ManaDef(mana: 1000, manaMax: 11500, regenPerSecond100: 210),
    );
    world.stamina.add(
      player,
      const StaminaDef(
        stamina: 1000,
        staminaMax: 13000,
        regenPerSecond100: 100,
      ),
    );
    world.health.regenAccumulator[0] = 7;
  }
  final EcsWorld world = EcsWorld();
  final List<GameEvent> events = [];
  late final int player;
  List<int> get resources => [
    world.health.hp.single,
    world.mana.mana.single,
    world.stamina.stamina.single,
  ];
}
