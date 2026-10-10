import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/actor_navigation_profiles.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_navigation_profiles.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final tickHz in [30, 60, 90]) {
    test('complete actor profiles follow simulation tuning at $tickHz Hz', () {
      const locomotion = GroundEnemyLocomotionTuning(
        speedX: 240,
        jumpSpeed: 420,
      );
      const physics = PhysicsTuning(gravityY: 1100);
      const enemies = EnemyCatalog();
      const allies = NpcCatalog();
      final profiles = buildActorNavigationProfiles(
        enemyCatalog: enemies,
        locomotion: locomotion,
        physics: physics,
        tickHz: tickHz,
      );
      expect(profiles.map((p) => p.profileKey), [
        for (final id in groundNavigatingEnemyIds) id.name,
        for (final id in NpcCatalog.supportedIds) npcNavigationProfileKey(id),
      ]);
      expect(() => profiles.clear(), throwsUnsupportedError);
      for (final profile in profiles) {
        // Signatures must encode mirrored zero exactly as native integer zero.
        if (profile.authoredOffsetXTicks == 0) {
          expect(profile.authoredOffsetXTicks.toString(), '0');
        }
        final enemy = groundNavigatingEnemyIds
            .where((id) => id.name == profile.profileKey)
            .firstOrNull;
        final ally = NpcCatalog.supportedIds
            .where((id) => npcNavigationProfileKey(id) == profile.profileKey)
            .firstOrNull;
        final speed = enemy != null
            ? locomotion.speedX
            : allies.get(ally!).speedX;
        final jump = enemy != null
            ? locomotion.jumpSpeed
            : allies.get(ally!).jumpSpeed;
        expect(profile.simulationTicksPerSecond, tickHz);
        expect(
          profile.locomotionSpeedTicksPerSecond,
          physicsCoordinateToTicks(speed),
        );
        expect(profile.jumpTemplate.profile.gravityY, physics.gravityY);
        expect(profile.jumpTemplate.profile.jumpSpeed, jump);
        expect(profile.jumpTemplate.profile.dtSeconds, 1 / tickHz);
        if (enemy != null) {
          final contact = enemies.terrainContactProfile(enemy);
          expect(profile.canJump, contact.canJump);
          expect(profile.radiusTicks, contact.capsule.radiusTicks);
          expect(profile.traversalProfile, contact.traversal);
        }
      }
    });
  }
}
