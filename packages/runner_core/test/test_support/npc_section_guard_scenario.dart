import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

/// Three flat production-terrain chunks form a finite synthetic section.
/// Camera auto-scroll is disabled to isolate NPC pursuit/combat; actor capabilities
/// and collision are unchanged. Only the player's initial pose is supplied.
GameCore sectionGuardCore({
  NpcId npcId = NpcId.warrior,
  int seed = 7,
  int tickHz = 60,
}) {
  final core = GameCore(
    seed: seed,
    tickHz: tickHz,
    playerCharacter: PlayerCharacterRegistry.eloise,
    levelDefinition: LevelRegistry.byId(LevelId.field).copyWith(
      noEnemyChunks: 0,
      earlyPatternChunks: 0,
      clearAssembly: true,
      clearFirstChunkKey: true,
      chunkPatternSource: _SectionSource(npcId),
      tuning: const CoreTuning(
        camera: CameraTuning(speedLagMulX: 0),
        track: TrackTuning(playerStartX: 560),
      ),
    ),
  );
  return core;
}

final class _SectionSource extends ChunkPatternSource {
  const _SectionSource(this.npcId);
  final NpcId npcId;
  @override
  ChunkPatternSelection selectionFor({
    required int seed,
    required int chunkIndex,
    required ChunkPatternTier tier,
  }) {
    return ChunkPatternSelection(
      tier: tier,
      assembly: ChunkAssemblySelection(
        segmentId: 'camp',
        segmentIndex: 0,
        runSequence: chunkIndex ~/ 3,
        cycleIndex: chunkIndex ~/ 3,
        startChunkIndex: chunkIndex ~/ 3 * 3,
        chunkCount: 3,
        repeatsFinalSegment: false,
      ),
      pattern: ChunkPattern(
        name: 'field_flat',
        chunkKey: 'field_flat',
        encounters: chunkIndex == 0
            ? [
                EncounterDefinition(
                  id: 'rescue',
                  name: 'Rescue',
                  trigger: EncounterTrigger(
                    x: 0,
                    y: -1000,
                    width: 600,
                    height: 2000,
                  ),
                  npcs: [
                    EncounterNpcPlacement(id: 'ally', npcId: npcId, x: 570),
                  ],
                  enemies: [
                    EncounterEnemyPlacement(
                      id: 'foe',
                      enemyId: EnemyId.grojib,
                      x: 580,
                    ),
                  ],
                ),
              ]
            : const [],
        spawnMarkers: chunkIndex == 2
            ? const [
                SpawnMarker(
                  enemyId: EnemyId.grojib,
                  x: 80,
                  chancePercent: 100,
                  salt: 1,
                  placement: SpawnPlacementMode.highestSurfaceAtX,
                ),
              ]
            : const [],
      ),
    );
  }
}
