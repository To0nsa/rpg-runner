import '../levels/level_id.dart';
import '../encounters/encounter_limits.dart';
import '../enemies/enemy_id.dart';
import '../ecs/stores/restoration_item_store.dart';
import '../interactions/world_interaction_catalog.dart';
import '../interactions/world_interaction_placement.dart';
import '../levels/level_definition.dart';
import '../levels/level_identity.dart';
import '../playtest/playtest_scenario_validation.dart';
import '../track/finite_chunk_pattern_source.dart';
import '../track/staged_terrain_catalog.dart';
import '../track/staged_terrain_data.dart';
import '../tuning/collectible_tuning.dart';
import '../tuning/core_tuning.dart';
import '../tuning/restoration_item_tuning.dart';
import '../tuning/track_tuning.dart';
import 'campaign_placement.dart';

/// Coordinates remain attached to a mission chunk when the route is reordered.
final class CampaignPoint {
  CampaignPoint({
    required this.missionChunkId,
    required this.x,
    required this.y,
  }) {
    if (missionChunkId.isEmpty ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x >= 600 ||
        y < 0 ||
        y > 270) {
      throw ArgumentError('Campaign points must fit a 600x270 mission chunk.');
    }
  }
  final String missionChunkId;
  final double x, y;
}

/// Region contact is inclusive; the actor center must actually enter it.
final class CampaignRegion {
  CampaignRegion({
    required this.origin,
    required this.width,
    required this.height,
  }) {
    if (!width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0 ||
        origin.x + width > 600 ||
        origin.y + height > 270) {
      throw ArgumentError('Campaign regions must fit their mission chunk.');
    }
  }
  final CampaignPoint origin;
  final double width, height;
}

typedef CampaignEnemyTarget = ({String missionChunkId, int markerSalt});
typedef CampaignRescueTarget = ({String missionChunkId, String encounterId});
typedef CampaignShrineTarget = ({String missionChunkId, String bindingKey});

/// Explicit gem placement; collection uses the ordinary restoration system.
final class CampaignRestoration {
  const CampaignRestoration({required this.position, required this.resource});
  final CampaignPoint position;
  final RestorationStat resource;
}

/// Captured, finite gameplay input shared by authored Play and trusted catalogs.
/// Repository discovery, source revisions/digests and reward policies live outside
/// Core. Neither this value nor its completion grants account ownership.
final class CampaignMissionDefinition {
  CampaignMissionDefinition({
    required this.id,
    required this.route,
    required Iterable<StagedTerrainChunkData> terrainChunks,
    required this.start,
    required this.exit,
    required this.visualThemeId,
    this.requiresFirstCoin = false,
    this.requiredBlessingShrine,
    Iterable<CampaignPoint> collectibles = const [],
    Iterable<CampaignRestoration> restorations = const [],
    Iterable<WorldInteractionBinding> interactions = const [],
    Iterable<CampaignRegion> requiredRegions = const [],
    Iterable<CampaignEnemyTarget> requiredEnemies = const [],
    Iterable<CampaignEnemyTarget> persistentPursuitEnemies = const [],
    Iterable<CampaignRescueTarget> requiredRescues = const [],
    this.groundTopY = 224,
    this.killPlaneY = 624,
  }) : terrainCatalog = StagedTerrainChunkCatalog(chunks: terrainChunks),
       collectibles = List.unmodifiable(collectibles),
       restorations = List.unmodifiable(restorations),
       interactions = List.unmodifiable(interactions),
       worldInteractions = List.unmodifiable([
         ...WorldInteractionCatalog.bindings,
         ...interactions,
       ]),
       requiredRegions = List.unmodifiable(requiredRegions),
       requiredEnemies = Set.unmodifiable(requiredEnemies),
       persistentPursuitEnemies = Set.unmodifiable(persistentPursuitEnemies),
       requiredRescues = Set.unmodifiable(requiredRescues) {
    if (this.requiredEnemies.length != requiredEnemies.length ||
        this.persistentPursuitEnemies.length !=
            persistentPursuitEnemies.length ||
        this.requiredRescues.length != requiredRescues.length) {
      throw ArgumentError('Required campaign targets must be unique.');
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
        visualThemeId.isEmpty ||
        !groundTopY.isFinite ||
        !killPlaneY.isFinite ||
        route.length > maxMissionChunks ||
        this.collectibles.length + this.restorations.length > 256 ||
        this.requiredRegions.length > 32) {
      throw ArgumentError(
        'Invalid campaign identity, settings or content capacity.',
      );
    }
    if (requiresFirstCoin && this.collectibles.isEmpty) {
      throw ArgumentError(
        'The first-coin objective requires an authored coin.',
      );
    }
    final level = buildLevel();
    var encounters = 0;
    for (var i = 0; i < route.length; i++) {
      final missionChunk = route.missionChunks[i];
      final pattern = missionChunk.pattern;
      final terrain = terrainCatalog.requireChunk(pattern.chunkKey!);
      if (terrain.levelId != missionChunk.sourceLevelId ||
          terrain.status != 'active' ||
          terrain.width != 600 ||
          terrain.height != 270 ||
          terrain.assemblyGroupId != pattern.assemblyGroupId ||
          playtestTierForDifficulty(terrain.difficulty) != missionChunk.tier) {
        throw ArgumentError(
          'Mission chunk ${missionChunk.id} does not match its source terrain.',
        );
      }
      validatePlaytestTraps(pattern, terrain);
      validatePlaytestEncounters(pattern, terrain, level);
      encounters += pattern.encounters.length;
      final salts = <int>{};
      for (final marker in pattern.spawnMarkers) {
        if (!salts.add(marker.salt) ||
            !marker.x.isFinite ||
            marker.x < 0 ||
            marker.x >= 600 ||
            marker.chancePercent < 0 ||
            marker.chancePercent > 100 ||
            marker.enemyId.isArenaOnly) {
          throw ArgumentError(
            'Mission chunk ${missionChunk.id} has an invalid or ambiguous enemy marker.',
          );
        }
      }
      if (i > 0) {
        validatePlaytestSeam(
          transitionRecord:
              '${route.missionChunks[i - 1].id} -> ${missionChunk.id}',
          leftChunkKey: route.missionChunks[i - 1].pattern.chunkKey!,
          rightChunkKey: pattern.chunkKey!,
          catalog: terrainCatalog,
        );
      }
    }
    if (encounters > EncounterLimits.maxLiveEncounters) {
      throw ArgumentError('Resident encounter capacity exceeded.');
    }
    for (final point in [
      start,
      exit.origin,
      ...this.collectibles,
      for (final gem in this.restorations) gem.position,
      for (final region in this.requiredRegions) region.origin,
    ]) {
      missionChunkIndex(point.missionChunkId);
    }
    for (final target in {
      ...this.requiredEnemies,
      ...this.persistentPursuitEnemies,
    }) {
      final missionChunk =
          route.missionChunks[missionChunkIndex(target.missionChunkId)];
      final marker = missionChunk.pattern.spawnMarkers
          .where((m) => m.salt == target.markerSalt)
          .firstOrNull;
      if (marker == null) {
        throw ArgumentError('Enemy policies must reference authored markers.');
      }
      if (this.requiredEnemies.contains(target) &&
          marker.chancePercent != 100) {
        throw ArgumentError(
          'Required enemies must reference guaranteed authored markers.',
        );
      }
    }
    for (final target in this.requiredRescues) {
      final missionChunk =
          route.missionChunks[missionChunkIndex(target.missionChunkId)];
      if (!missionChunk.pattern.encounters.any(
        (e) => e.id == target.encounterId,
      )) {
        throw ArgumentError('Required rescue target is missing.');
      }
    }
    validateCampaignStart(this);
    final interactionKeys = <(String, String)>{};
    if (this.interactions.length > 64) {
      throw ArgumentError('At most 64 campaign interactions are supported.');
    }
    for (final binding in this.interactions) {
      final missionChunk = binding.missionChunkId;
      if (missionChunk == null ||
          binding.key.isEmpty ||
          !interactionKeys.add((missionChunk, binding.key))) {
        throw ArgumentError(
          'Campaign interactions require unique mission chunk-local identities.',
        );
      }
      final chunkKey = route
          .missionChunks[missionChunkIndex(missionChunk)]
          .pattern
          .chunkKey!;
      if (WorldInteractionCatalog.bindings.any(
        (b) => b.chunkKey == chunkKey && b.key == binding.key,
      )) {
        throw ArgumentError(
          'Campaign interaction identity conflicts with inherited content.',
        );
      }
      if (binding.chunkKey != chunkKey) {
        throw ArgumentError(
          'Interaction source does not match its mission chunk.',
        );
      }
      try {
        resolveWorldInteractionSurface(
          binding,
          terrainCatalog.requireChunk(chunkKey),
        );
      } on StateError catch (error) {
        throw ArgumentError(error.message);
      }
    }
    final shrine = requiredBlessingShrine;
    if (shrine != null &&
        !this.interactions.any(
          (binding) =>
              binding.missionChunkId == shrine.missionChunkId &&
              binding.key == shrine.bindingKey &&
              binding.interactionId == WorldInteractionId.regenerationShrine,
        )) {
      throw ArgumentError(
        'The blessing objective requires an authored shrine.',
      );
    }
  }

  /// Admission cap for the initial resident-world implementation, not a promise
  /// of device performance. Performance acceptance must precede catalog release.
  static const maxMissionChunks = 48;
  final String id, visualThemeId;
  final FiniteChunkPatternSource route;
  final StagedTerrainChunkCatalog terrainCatalog;
  final CampaignPoint start;
  final CampaignRegion exit;
  final List<CampaignPoint> collectibles;
  final List<CampaignRestoration> restorations;
  final List<WorldInteractionBinding> interactions;
  final List<WorldInteractionBinding> worldInteractions;
  final bool requiresFirstCoin;

  /// One exact shrine must activate; an unrelated blessing cannot clear this goal.
  final CampaignShrineTarget? requiredBlessingShrine;
  final List<CampaignRegion> requiredRegions;
  final Set<CampaignEnemyTarget> requiredEnemies;

  /// Ordinary markers that keep following after their first activation.
  final Set<CampaignEnemyTarget> persistentPursuitEnemies;
  final Set<CampaignRescueTarget> requiredRescues;
  final double groundTopY, killPlaneY;
  double get worldWidth => route.length * 600.0;

  int missionChunkIndex(String id) {
    final index = route.missionChunks.indexWhere((o) => o.id == id);
    if (index < 0) throw ArgumentError('Unknown route mission chunk $id.');
    return index;
  }

  double worldX(CampaignPoint point) =>
      missionChunkIndex(point.missionChunkId) * 600 + point.x;

  bool contains(CampaignRegion region, double x, double y) {
    final left = worldX(region.origin);
    return x >= left &&
        x <= left + region.width &&
        y >= region.origin.y &&
        y <= region.origin.y + region.height;
  }

  LevelDefinition buildLevel({LevelId? regionalLevelId}) {
    final authored = LevelDefinition.authored(
      identity: AuthoredLevelIdentity(id),
      chunkPatternSource: route,
      groundTopY: groundTopY,
      killPlaneY: killPlaneY,
      visualThemeId: visualThemeId,
      noEnemyChunks: 0,
      tuning: CoreTuning(
        track: TrackTuning(playerStartX: worldX(start)),
        collectible: const CollectibleTuning(enabled: false),
        restorationItem: const RestorationItemTuning(enabled: false),
      ),
    );
    if (regionalLevelId == null) return authored;
    return LevelDefinition(
      id: regionalLevelId,
      chunkPatternSource: route,
      groundTopY: groundTopY,
      killPlaneY: killPlaneY,
      visualThemeId: visualThemeId,
      noEnemyChunks: 0,
      tuning: authored.tuning,
    );
  }
}
