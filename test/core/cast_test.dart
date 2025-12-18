import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/commands/command.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/v0_resource_tuning.dart';

void main() {
  test('cast: insufficient mana => no projectile', () {
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      playerBody: const BodyDef(isKinematic: true, useGravity: false),
      resourceTuning: const V0ResourceTuning(
        playerManaMax: 10,
        playerManaStart: 0,
        playerManaRegenPerSecond: 0,
      ),
    );

    core.applyCommands(const [CastPressedCommand(tick: 1)]);
    core.stepOneTick();

    final snapshot = core.buildSnapshot();
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile),
      isEmpty,
    );
    expect(snapshot.hud.mana, closeTo(0.0, 1e-9));
    expect(core.playerCastCooldownTicksLeft, 0);
  });

  test('cast: sufficient mana => projectile spawns + mana spent + cooldown set', () {
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      playerBody: const BodyDef(isKinematic: true, useGravity: false),
      resourceTuning: const V0ResourceTuning(
        playerManaMax: 100,
        playerManaStart: 20,
        playerManaRegenPerSecond: 0,
      ),
    );

    final playerPos = core.playerPos;

    core.applyCommands(const [CastPressedCommand(tick: 1)]);
    core.stepOneTick();

    final snapshot = core.buildSnapshot();
    final projectiles =
        snapshot.entities.where((e) => e.kind == EntityKind.projectile).toList();
    expect(projectiles.length, 1);

    final p = projectiles.single;
    expect(p.pos.x, closeTo(playerPos.x + 4.0, 1e-9)); // playerRadius * 0.5
    expect(p.pos.y, closeTo(playerPos.y, 1e-9));

    expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
    expect(core.playerCastCooldownTicksLeft, 5); // ceil(0.25s * 20Hz)
  });

  test('cast: cooldown blocks recast until it expires', () {
    final core = GameCore(
      seed: 1,
      tickHz: 20,
      playerBody: const BodyDef(isKinematic: true, useGravity: false),
      resourceTuning: const V0ResourceTuning(
        playerManaMax: 100,
        playerManaStart: 30,
        playerManaRegenPerSecond: 0,
      ),
    );

    core.applyCommands(const [CastPressedCommand(tick: 1)]);
    core.stepOneTick();

    core.applyCommands(const [CastPressedCommand(tick: 2)]);
    core.stepOneTick();

    var snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(20.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      1,
    );

    // Wait until cooldown should be 0, then cast again.
    for (var t = 3; t <= 6; t += 1) {
      core.applyCommands(<Command>[]);
      core.stepOneTick();
    }

    core.applyCommands(const [CastPressedCommand(tick: 7)]);
    core.stepOneTick();

    snapshot = core.buildSnapshot();
    expect(snapshot.hud.mana, closeTo(10.0, 1e-9));
    expect(
      snapshot.entities.where((e) => e.kind == EntityKind.projectile).length,
      2,
    );
  });
}

