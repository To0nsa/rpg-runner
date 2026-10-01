import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/combat_target.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/ai_target_store.dart';
import 'package:runner_core/ecs/stores/enemies/enemy_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/systems/npc_guard_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_guard_region.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test(
    'guards discover entering enemies only inside their own section occurrence',
    () {
      final f = _Fixture();
      final npc = f.guard(x: 430);
      final inside = f.enemy(700);
      final outside = f.enemy(1800);
      f.step();
      expect(f.selected(npc), inside);
      expect(f.selected(inside), npc);
      expect(f.world.aiTarget.has(outside), isFalse);
      f.move(inside, 1800);
      f.move(outside, 650);
      f.step();
      expect(f.selected(npc), outside);
      expect(f.world.aiTarget.has(inside), isFalse);
      expect(f.selected(outside), npc);
      f.move(outside, -1);
      f.step();
      expect(f.selected(npc), isNull);
      expect(f.world.aiTarget.has(outside), isFalse);
      f.move(outside, 0);
      f.step();
      expect(f.selected(npc), outside);
    },
  );

  test('repeated section IDs and multiple guard archetypes never share a territory', () {
    final f = _Fixture();
    final first = f.guard(x: 430);
    final second = f.guard(
      x: 2000,
      start: 1800,
      chunkIndex: 3,
      id: NpcId.huntress2,
    );
    final foe = f.enemy(2200);
    f.step();
    expect(f.selected(first), isNull);
    expect(f.selected(second), foe);
    expect(f.roster(foe), [second]);
  });

  test('unchanged rosters retain targets and negative navigation evidence', () {
    final f = _Fixture();
    final npc = f.guard(x: 430);
    final original = f.enemy(700);
    f.step();
    final closer = f.enemy(500);
    f.step();
    expect(f.selected(npc), original);
    final index = f.world.aiTarget.indexOf(npc);
    f.world.aiTarget.unreachable[index][original] = targetNavigationEvidence(
      f.world,
      npc,
      original,
    );
    final roster = f.roster(npc);
    f.step();
    expect(identical(f.roster(npc), roster), isTrue);
    expect(f.selected(npc), closer);
    expect(f.world.aiTarget.unreachable[index], contains(original));
    f.step();
    expect(f.selected(npc), closer);
    f.move(original, 1900);
    f.step();
    expect(f.world.aiTarget.unreachable[index], isNot(contains(original)));
  });

  test(
    'active encounter rosters and player-only policy keep their ownership',
    () {
      final f = _Fixture();
      final npc = f.guard(x: 430);
      final enemy = f.enemy(500);
      f.world.aiTarget.configure(
        enemy,
        targetPolicy: AiTargetPolicy.playerOnly,
        candidates: const [],
      );
      final original = f.roster(enemy);
      f.step();
      expect(f.selected(npc), enemy);
      expect(f.selected(enemy), f.player);
      expect(
        f.world.aiTarget.owner[f.world.aiTarget.indexOf(enemy)],
        AiTargetOwner.encounter,
      );
      expect(identical(f.roster(enemy), original), isTrue);
    },
  );

  test('enemy player fallback remains eligible and stable when guards are farther away', () {
    final f = _Fixture();
    f.guard(x: 430);
    final enemy = f.enemy(80);
    f.step();
    expect(f.selected(enemy), f.player);
    f.step();
    expect(f.selected(enemy), f.player);
  });

  test('destruction and recycled IDs cannot retain stale guard targets', () {
    final f = _Fixture();
    final npc = f.guard(x: 430);
    final enemy = f.enemy(500);
    f.step();
    f.world.destroyEntity(enemy);
    expect(f.selected(npc), isNull);
    expect(f.roster(npc), isEmpty);
    final recycled = f.enemy(1900);
    expect(recycled, enemy);
    f.step();
    expect(f.selected(npc), isNull);
    f.world.destroyEntity(npc);
    final ordinaryNpc = EntityFactory(f.world).createNpc(
      npcId: NpcId.huntress,
      posX: 1900,
      posY: 0,
      chunkStartX: 1800,
      chunkEndX: 2400,
    );
    expect(ordinaryNpc, npc);
    f.step();
    expect(f.world.aiTarget.has(recycled), isFalse);
    expect(f.world.npc.guardRegion[f.world.npc.indexOf(ordinaryNpc)], isNull);
  });

  test('guard death or protection restores ordinary enemy pursuit', () {
    for (final protected in [false, true]) {
      final f = _Fixture();
      final npc = f.guard(x: 430);
      final enemy = f.enemy(500);
      f.step();
      if (protected) {
        protectNpc(f.world, npc);
      } else {
        f.world.health.hp[f.world.health.indexOf(npc)] = 0;
      }
      f.step();
      expect(f.world.aiTarget.has(enemy), isFalse);
      expect(combatTarget(f.world, enemy, f.player), f.player);
    }
  });
}

class _Fixture {
  _Fixture() {
    player = actor(50, Faction.player);
  }
  final world = EcsWorld();
  final guards = NpcGuardSystem();
  final targets = AiTargetSystem();
  late final int player;

  int actor(double x, Faction faction) {
    final e = world.createEntity();
    world.transform.add(e, posX: x, posY: 0, velX: 0, velY: 0);
    world.health.add(
      e,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );
    world.faction.add(e, FactionDef(faction: faction));
    return e;
  }

  int enemy(double x) {
    final e = actor(x, Faction.enemy);
    world.enemy.add(e, const EnemyDef(enemyId: EnemyId.grojib));
    return e;
  }

  int guard({
    required double x,
    double start = 0,
    int chunkIndex = 0,
    NpcId id = NpcId.warrior,
  }) {
    final e = EntityFactory(world).createNpc(
      npcId: id,
      posX: x,
      posY: 0,
      chunkStartX: start,
      chunkEndX: start + 600,
    );
    beginNpcGuarding(
      world,
      e,
      NpcGuardRegion.forChunk(
        chunkIndex: chunkIndex,
        startX: start,
        endX: start + 600,
        assembly: ChunkAssemblySelection(
          segmentId: 'repeated',
          segmentIndex: 0,
          runSequence: chunkIndex ~/ 3,
          cycleIndex: chunkIndex ~/ 3,
          startChunkIndex: chunkIndex,
          chunkCount: 3,
          repeatsFinalSegment: false,
        ),
      ),
    );
    return e;
  }

  void move(int e, double x) =>
      world.transform.posX[world.transform.indexOf(e)] = x;
  void step() {
    guards.step(world);
    targets.step(world, player: player);
  }

  int? selected(int e) => world.aiTarget.selected[world.aiTarget.indexOf(e)];
  List<int> roster(int e) =>
      world.aiTarget.opponents[world.aiTarget.indexOf(e)];
}
