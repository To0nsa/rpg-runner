import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/combat/projectile_aim_visibility.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ability_activation_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:test/test.dart';

void main() {
  test('auto aim ignores targets beyond the equipped projectile reach', () {
    final scenario = _scenario(facing: Facing.left);
    _enemy(scenario.world, x: 1000, y: 100);

    final direction = _fire(scenario);
    expect(direction.$1, closeTo(-1, 1e-9));
    expect(direction.$2, closeTo(0, 1e-9));
  });

  test('auto aim ignores a zero-health target awaiting death cleanup', () {
    final scenario = _scenario();
    final dying = _enemy(scenario.world, x: 160, y: 100);
    scenario.world.health.hp[scenario.world.health.indexOf(dying)] = 0;
    _enemy(scenario.world, x: 200, y: -60);

    final direction = _fire(scenario);
    expect(direction.$2, lessThan(-0.2));
  });

  test('auto aim selects a clear target behind a blocked nearer target', () {
    final geometry = const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/wall',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'wall',
        ),
        vertices: <(double, double)>[
          (120, 80),
          (130, 80),
          (130, 120),
          (120, 120),
        ],
      ),
    ], geometryVersion: 1);
    final index = TerrainEdgeIndex(edges: geometry.edges);
    final visibility = ProjectileAimVisibility(() => index);
    final scenario = _scenario(originOffset: 0, pathClear: visibility.isClear);
    _enemy(scenario.world, x: 160, y: 100);
    _enemy(scenario.world, x: 200, y: -60);

    final direction = _fire(scenario);
    expect(direction.$1, greaterThan(0));
    expect(direction.$2, lessThan(-0.2));
  });

  test('projectile launch offset reduces lead while retaining intercept', () {
    (double, double) aimWithOffset(double offset) {
      final scenario = _scenario(originOffset: offset);
      _enemy(scenario.world, x: 200, y: 100, velY: 200);
      return _fire(scenario);
    }

    final centerAim = aimWithOffset(0);
    final offsetAim = aimWithOffset(20);
    expect(offsetAim.$2, lessThan(centerAim.$2));

    const speed = 600.0;
    const sourceX = 100.0;
    const sourceY = 100.0;
    const targetX = 200.0;
    const targetYAtLaunch = 100.0 + 200.0 * 10 / 60;
    final flightSeconds =
        (targetX - sourceX - 20 * offsetAim.$1) / (speed * offsetAim.$1);
    final projectileY = sourceY + (20 + speed * flightSeconds) * offsetAim.$2;
    final targetY = targetYAtLaunch + 200 * flightSeconds;
    expect(projectileY, closeTo(targetY, 1e-6));
  });

  test('terrain sight buffer follows a published edge-index replacement', () {
    final wall = const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/wall',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'wall',
        ),
        vertices: <(double, double)>[
          (120, 80),
          (130, 80),
          (130, 120),
          (120, 120),
        ],
      ),
    ], geometryVersion: 1);
    final clear = const TerrainCompiler().compile(
      <TerrainPolygonInput>[],
      geometryVersion: 2,
    );
    var index = TerrainEdgeIndex(edges: wall.edges);
    final visibility = ProjectileAimVisibility(() => index);

    expect(visibility.isClear(100, 100, 160, 100), isFalse);
    index = TerrainEdgeIndex(edges: clear.edges);
    expect(visibility.isClear(100, 100, 160, 100), isTrue);
  });

  test('terrain checks run only for candidates that can win', () {
    var checks = 0;
    final scenario = _scenario(
      pathClear: (fromX, fromY, toX, toY) {
        checks += 1;
        return true;
      },
    );
    _enemy(scenario.world, x: 160, y: 100);
    _enemy(scenario.world, x: 320, y: 100);
    _enemy(scenario.world, x: 1000, y: 100);

    _fire(scenario);
    expect(checks, 1);
  });

  test('rejected projectile commits skip the target and terrain search', () {
    var checks = 0;
    final scenario = _scenario(
      pathClear: (fromX, fromY, toX, toY) {
        checks += 1;
        return true;
      },
    );
    _enemy(scenario.world, x: 40, y: 100);
    final manaIndex = scenario.world.mana.indexOf(scenario.player);
    scenario.world.mana.mana[manaIndex] = 0;

    _fire(scenario);
    expect(checks, 0);
    final movementIndex = scenario.world.movement.indexOf(scenario.player);
    expect(scenario.world.movement.facing[movementIndex], Facing.right);
  });
}

({EcsWorld world, AbilityActivationSystem system, int player}) _scenario({
  Facing facing = Facing.right,
  double originOffset = 0,
  bool Function(double, double, double, double)? pathClear,
}) {
  final world = EcsWorld();
  final system = AbilityActivationSystem(
    tickHz: 60,
    inputBufferTicks: 10,
    abilities: const AbilityCatalog(),
    weapons: const WeaponCatalog(),
    projectiles: const ProjectileCatalog(),
    spellBooks: const SpellBookCatalog(),
    accessories: const AccessoryCatalog(),
    playerCastOriginOffset: originOffset,
    projectileAimPathClear: pathClear,
  );
  final player = world.createEntity();
  world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
  world.faction.add(player, const FactionDef(faction: Faction.player));
  world.health.add(
    player,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.playerInput.add(player);
  world.movement.add(player, facing: facing);
  world.abilityInputBuffer.add(player);
  world.activeAbility.add(player);
  world.cooldown.add(player);
  world.mana.add(
    player,
    const ManaDef(mana: 5000, manaMax: 5000, regenPerSecond100: 0),
  );
  world.stamina.add(
    player,
    const StaminaDef(stamina: 5000, staminaMax: 5000, regenPerSecond100: 0),
  );
  world.projectileIntent.add(player);
  world.equippedLoadout.add(
    player,
    const EquippedLoadoutDef(
      abilityProjectileId: 'eloise.snap_shot',
      projectileSlotSpellId: ProjectileId.iceBolt,
    ),
  );
  return (world: world, system: system, player: player);
}

int _enemy(
  EcsWorld world, {
  required double x,
  required double y,
  double velY = 0,
}) {
  final enemy = world.createEntity();
  world.transform.add(enemy, posX: x, posY: y, velX: 0, velY: velY);
  world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
  world.health.add(
    enemy,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  return enemy;
}

(double, double) _fire(
  ({EcsWorld world, AbilityActivationSystem system, int player}) scenario,
) {
  final inputIndex = scenario.world.playerInput.indexOf(scenario.player);
  scenario.world.playerInput.projectilePressed[inputIndex] = true;
  scenario.system.step(scenario.world, player: scenario.player, currentTick: 1);
  final intentIndex = scenario.world.projectileIntent.indexOf(scenario.player);
  return (
    scenario.world.projectileIntent.dirX[intentIndex],
    scenario.world.projectileIntent.dirY[intentIndex],
  );
}
