import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  for (final enemyId in [EnemyId.grojib, EnemyId.hashash]) {
    for (final npcId in NpcId.values) {
      for (final side in [-1, 1]) {
        test('${enemyId.name} holds position fighting ${npcId.name} from $side', () {
          final core = _core(enemyId, npcId, side);
          double? heldX;
          var heldSide = side;
          var heldTicks = 0;
          var damagedNpc = false;
          for (var tick = 0; tick < 240 && !core.gameOver; tick++) {
            core.stepOneTick();
            final actors = core.buildSnapshot().entities;
            final npc = actors.where((e) => e.npcId == npcId).first;
            final enemy = actors.where((e) => e.enemyId == enemyId).first;
            damagedNpc |=
                npc.npcHealth!.hp100 < const NpcCatalog().get(npcId).health.hp;
            if (npc.anim == AnimKey.death || enemy.anim == AnimKey.death) break;
            // Hashash deliberately teleports across its target when evading a
            // hit. Check stable melee positioning before and after that ability.
            if (enemy.anim == AnimKey.teleportOut ||
                enemy.anim == AnimKey.ambush) {
              heldX = null;
              continue;
            }
            final dx = enemy.pos.x - npc.pos.x;
            if (heldX == null && (dx.abs() > 40 || enemy.vel!.x != 0)) continue;
            if (heldX == null) {
              heldX = enemy.pos.x;
              heldSide = dx.sign.toInt();
            }
            expect(
              dx * heldSide,
              greaterThan(0),
              reason: 'crossed NPC at tick $tick',
            );
            expect(
              enemy.pos.x,
              closeTo(heldX, 1 / 1024),
              reason: 'drifted during combat at tick $tick',
            );
            expect(enemy.vel!.x, 0);
            expect(enemy.facing, heldSide < 0 ? Facing.right : Facing.left);
            heldTicks++;
          }
          // Low-health allies may die on the first attack. Holding must remain
          // stable for every observed combat tick, regardless of fight length.
          expect(heldTicks, greaterThan(0));
          expect(
            damagedNpc,
            isTrue,
            reason: 'holding must still allow attacks',
          );
        });
      }
    }
  }
}

GameCore _core(EnemyId enemyId, NpcId npcId, int side) => GameCore(
  seed: 7,
  playerCharacter: PlayerCharacterRegistry.eloise,
  levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
    noEnemyChunks: 0,
    earlyPatternChunks: 0,
    clearAssembly: true,
    clearFirstChunkKey: true,
    chunkPatternSource: ChunkPatternListSource(
      easyPatterns: const [],
      normalPatterns: [
        ChunkPattern(
          name: 'field_flat',
          chunkKey: 'field_flat',
          encounters: [
            EncounterDefinition(
              id: 'combat_position',
              name: 'Combat position',
              trigger: EncounterTrigger(
                x: 0,
                y: -1000,
                width: 600,
                height: 2000,
              ),
              npcs: [EncounterNpcPlacement(id: 'ally', npcId: npcId, x: 330)],
              enemies: [
                EncounterEnemyPlacement(
                  id: 'foe',
                  enemyId: enemyId,
                  x: 330 + side * 120,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
);
