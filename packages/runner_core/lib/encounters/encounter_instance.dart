import '../ecs/entity_id.dart';
import '../npcs/npc_guard_region.dart';
import '../track/chunk_pattern_source.dart';
import 'encounter_definition.dart';

typedef EncounterKey = ({int chunkIndex, String encounterId});

enum EncounterPhase { dormant, active, rescued, failed, abandoned, skipped }

enum EncounterEndReason {
  rescued,
  npcsDefeated,
  unassisted,
  invalidSpawn,
  invalidMember,
  capacity,
  passedCamera,
  runEnded,
  openingSuppression,
}

enum EncounterMemberRole { npc, enemy }

/// A single placement of an authored group, independent of repeated chunk keys.
final class EncounterOccurrence {
  EncounterOccurrence({
    required this.chunkIndex,
    required this.startX,
    required this.endX,
    required this.definition,
    ChunkAssemblySelection? assembly,
  }) : guardRegion = NpcGuardRegion.forChunk(
         chunkIndex: chunkIndex,
         startX: startX,
         endX: endX,
         assembly: assembly,
       ),
       participants = List.unmodifiable(
         <EncounterParticipant>[...definition.npcs, ...definition.enemies]
           ..sort((a, b) => a.id.compareTo(b.id)),
       ) {
    if (!startX.isFinite ||
        !endX.isFinite ||
        startX >= endX ||
        !abandonmentX.isFinite) {
      throw ArgumentError('Encounter occurrence needs finite chunk bounds.');
    }
    definition.validateForChunk(endX - startX);
  }
  final int chunkIndex;
  final double startX;
  final double endX;
  final EncounterDefinition definition;

  /// Survivor territory; activation and rescue objectives remain chunk-local.
  final NpcGuardRegion guardRegion;

  /// Publication order shared by placement preflight, actor creation and registration.
  final List<EncounterParticipant> participants;
  EncounterKey get key => (chunkIndex: chunkIndex, encounterId: definition.id);
  double get abandonmentX => endX + (endX - startX);
}

/// Placement adapters preflight the entire roster before publishing entities.
sealed class EncounterSpawnResult {
  const EncounterSpawnResult();
}

final class EncounterSpawnRejected extends EncounterSpawnResult {
  const EncounterSpawnRejected(this.diagnostic);
  final String diagnostic;
}

final class EncounterSpawned extends EncounterSpawnResult {
  EncounterSpawned(Map<String, EntityId> entities)
    : entities = Map.unmodifiable(entities);
  final Map<String, EntityId> entities;
}

/// Immutable terminal evidence; consumers cannot issue awards from this record.
final class EncounterOutcome {
  const EncounterOutcome({
    required this.key,
    required this.phase,
    required this.reason,
    required this.tick,
    this.survivors = 0,
    this.points = 0,
    this.diagnostic,
  });
  final EncounterKey key;
  final EncounterPhase phase;
  final EncounterEndReason reason;
  final int tick;
  final int survivors;
  final int points;
  final String? diagnostic;
}
