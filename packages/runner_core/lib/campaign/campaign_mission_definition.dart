import '../levels/level_id.dart';
import '../encounters/encounter_limits.dart';
import '../enemies/enemy_id.dart';
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

/// Coordinates remain attached to an occurrence when the route is reordered.
final class CampaignPoint {
  CampaignPoint({
    required this.occurrenceId,
    required this.x,
    required this.y,
  }) {
    if (occurrenceId.isEmpty ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x >= 600 ||
        y < 0 ||
        y > 270) {
      throw ArgumentError('Campaign points must fit a 600x270 occurrence.');
    }
  }
  final String occurrenceId;
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
      throw ArgumentError('Campaign regions must fit their occurrence.');
    }
  }
  final CampaignPoint origin;
  final double width, height;
}

typedef CampaignEnemyTarget = ({String occurrenceId, int markerSalt});
typedef CampaignRescueTarget = ({String occurrenceId, String encounterId});

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
    Iterable<CampaignPoint> collectibles = const [],
    Iterable<CampaignRegion> requiredRegions = const [],
    Iterable<CampaignEnemyTarget> requiredEnemies = const [],
    Iterable<CampaignRescueTarget> requiredRescues = const [],
    this.combatAllowed = true,
    this.groundTopY = 224,
    this.killPlaneY = 624,
  }) : terrainCatalog = StagedTerrainChunkCatalog(chunks: terrainChunks),
       collectibles = List.unmodifiable(collectibles),
       requiredRegions = List.unmodifiable(requiredRegions),
       requiredEnemies = Set.unmodifiable(requiredEnemies),
       requiredRescues = Set.unmodifiable(requiredRescues) {
    if (this.requiredEnemies.length != requiredEnemies.length ||
        this.requiredRescues.length != requiredRescues.length) {
      throw ArgumentError('Required campaign targets must be unique.');
    }
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
        visualThemeId.isEmpty ||
        !groundTopY.isFinite ||
        !killPlaneY.isFinite ||
        route.length > maxOccurrences ||
        this.collectibles.length > 256 ||
        this.requiredRegions.length > 32) {
      throw ArgumentError(
        'Invalid campaign identity, settings or content capacity.',
      );
    }
    final level = buildLevel();
    var encounters = 0;
    for (var i = 0; i < route.length; i++) {
      final occurrence = route.occurrences[i];
      final pattern = occurrence.pattern;
      final terrain = terrainCatalog.requireChunk(pattern.chunkKey!);
      if (terrain.levelId != occurrence.sourceLevelId ||
          terrain.status != 'active' ||
          terrain.width != 600 ||
          terrain.height != 270 ||
          terrain.assemblyGroupId != pattern.assemblyGroupId ||
          playtestTierForDifficulty(terrain.difficulty) != occurrence.tier) {
        throw ArgumentError(
          'Occurrence ${occurrence.id} does not match its source terrain.',
        );
      }
      validatePlaytestTraps(pattern, terrain);
      validatePlaytestEncounters(pattern, terrain, level);
      encounters += pattern.encounters.length;
      if (!combatAllowed &&
          (pattern.spawnMarkers.isNotEmpty ||
              pattern.encounters.isNotEmpty ||
              pattern.bossArena != null)) {
        throw ArgumentError(
          'This mission requires encounter-free authored chunks.',
        );
      }
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
            'Occurrence ${occurrence.id} has an invalid or ambiguous enemy marker.',
          );
        }
      }
      if (i > 0) {
        validatePlaytestSeam(
          transitionRecord:
              '${route.occurrences[i - 1].id} -> ${occurrence.id}',
          leftChunkKey: route.occurrences[i - 1].pattern.chunkKey!,
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
      for (final region in this.requiredRegions) region.origin,
    ]) {
      occurrenceIndex(point.occurrenceId);
    }
    for (final target in this.requiredEnemies) {
      final occurrence =
          route.occurrences[occurrenceIndex(target.occurrenceId)];
      final marker = occurrence.pattern.spawnMarkers
          .where((m) => m.salt == target.markerSalt)
          .firstOrNull;
      if (marker == null || marker.chancePercent != 100) {
        throw ArgumentError(
          'Required enemies must reference guaranteed authored markers.',
        );
      }
    }
    for (final target in this.requiredRescues) {
      final occurrence =
          route.occurrences[occurrenceIndex(target.occurrenceId)];
      if (!occurrence.pattern.encounters.any(
        (e) => e.id == target.encounterId,
      )) {
        throw ArgumentError('Required rescue target is missing.');
      }
    }
    validateCampaignStart(this);
  }

  /// Admission cap for the initial resident-world implementation, not a promise
  /// of device performance. Performance acceptance must precede catalog release.
  static const maxOccurrences = 16;
  final String id, visualThemeId;
  final FiniteChunkPatternSource route;
  final StagedTerrainChunkCatalog terrainCatalog;
  final CampaignPoint start;
  final CampaignRegion exit;
  final List<CampaignPoint> collectibles;
  final List<CampaignRegion> requiredRegions;
  final Set<CampaignEnemyTarget> requiredEnemies;
  final Set<CampaignRescueTarget> requiredRescues;
  final bool combatAllowed;
  final double groundTopY, killPlaneY;
  double get worldWidth => route.length * 600.0;

  int occurrenceIndex(String id) {
    final index = route.occurrences.indexWhere((o) => o.id == id);
    if (index < 0) throw ArgumentError('Unknown route occurrence $id.');
    return index;
  }

  double worldX(CampaignPoint point) =>
      occurrenceIndex(point.occurrenceId) * 600 + point.x;

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
