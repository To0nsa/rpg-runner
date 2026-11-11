import 'dart:convert';

import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/meta/catalog_unlock.dart';
import 'package:runner_core/playtest/playtest_scenario_validation.dart';
import 'package:runner_core/track/finite_chunk_pattern_source.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/traps/trap_placement.dart';
import 'package:runner_core/interactions/world_interaction_placement.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import 'chunk_runtime_materialization.dart';
import 'campaign_placement_source.dart';

const campaignSourcePath = 'assets/authoring/campaign/chapter_defs.json';

/// Source text belongs to authors. Runtime rules, rewards and translations are
/// projected from this one versioned catalog by the repository generator.
final class CampaignCatalogSource {
  CampaignCatalogSource._(this.revision, this.chapters);

  factory CampaignCatalogSource.decode(String text) {
    final root = _object(jsonDecode(text), {
      'schemaVersion',
      'revision',
      'chapters',
    }, 'campaign');
    if (root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported campaign schema.');
    }
    final revision = _integer(root['revision'], 1, 1000000000, 'revision');
    final chapters = <CampaignChapterSource>[];
    final chapterIds = <String>{};
    final missionIds = <String>{};
    for (final value in _list(root['chapters'], 32, 'chapters')) {
      final chapter = _object(
        value,
        {
          'id',
          'title',
          'description',
          'mapX',
          'mapY',
          'rewardCharacterId',
          'rewardXp',
          'rewardGold',
          'rewardItems',
          'missions',
        },
        'chapter',
        optional: const {'rewardXp', 'rewardGold', 'rewardItems'},
      );
      final id = _id(chapter['id'], 'chapter.id');
      if (!chapterIds.add(id)) throw FormatException('Duplicate chapter $id.');
      final missions = <CampaignMissionSource>[];
      for (final raw in _list(chapter['missions'], 16, 'missions')) {
        final mission = CampaignMissionSource.decode(raw);
        if (!missionIds.add(mission.id)) {
          throw FormatException('Duplicate mission ${mission.id}.');
        }
        missions.add(mission);
      }
      if (missions.isEmpty) {
        throw FormatException('$id needs at least one mission.');
      }
      final character = chapter['rewardCharacterId'];
      if (character != null && character != 'bountyHunter') {
        throw const FormatException('Unknown chapter character reward.');
      }
      chapters.add(
        CampaignChapterSource(
          id: id,
          title: _translation(chapter['title'], 'title'),
          description: _translation(chapter['description'], 'description'),
          mapX: _number(chapter['mapX'], 0, 1, 'mapX'),
          mapY: _number(chapter['mapY'], 0, 1, 'mapY'),
          rewardCharacterId: character as String?,
          rewardXp: _integer(
            chapter.containsKey('rewardXp') ? chapter['rewardXp'] : 0,
            0,
            100000,
            'rewardXp',
          ),
          rewardGold: _integer(
            chapter.containsKey('rewardGold') ? chapter['rewardGold'] : 0,
            0,
            1000000,
            'rewardGold',
          ),
          rewardItems: _rewardItems(
            chapter.containsKey('rewardItems')
                ? chapter['rewardItems']
                : const [],
          ),
          missions: List.unmodifiable(missions),
        ),
      );
    }
    if (chapters.isEmpty) {
      throw const FormatException('Campaign needs a chapter.');
    }
    return CampaignCatalogSource._(revision, List.unmodifiable(chapters));
  }

  final int revision;
  final List<CampaignChapterSource> chapters;
  Iterable<CampaignMissionSource> get missions =>
      chapters.expand((c) => c.missions);
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'revision': revision,
    'chapters': chapters.map((c) => c.toJson()).toList(),
  };
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

final class CampaignChapterSource {
  const CampaignChapterSource({
    required this.id,
    required this.title,
    required this.description,
    required this.mapX,
    required this.mapY,
    required this.rewardCharacterId,
    this.rewardXp = 0,
    this.rewardGold = 0,
    this.rewardItems = const [],
    required this.missions,
  });
  final String id;
  final Map<String, String> title, description;
  final double mapX, mapY;
  final String? rewardCharacterId;
  final int rewardXp, rewardGold;
  final List<CatalogUnlock> rewardItems;
  final List<CampaignMissionSource> missions;
  Map<String, Object?> rewardsToJson() => {
    'rewardCharacterId': rewardCharacterId,
    'rewardXp': rewardXp,
    'rewardGold': rewardGold,
    'rewardItems': rewardItems.map((item) => item.toJson()).toList(),
  };
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'mapX': mapX,
    'mapY': mapY,
    ...rewardsToJson(),
    'missions': missions.map((m) => m.toJson()).toList(),
  };
}

List<CatalogUnlock> _rewardItems(Object? raw) {
  final items = <CatalogUnlock>[];
  final keys = <String>{};
  for (final value in _list(raw, 8, 'rewardItems')) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid chapter item reward.');
    }
    final item = CatalogUnlock.fromJson(value);
    if (!keys.add(item.key)) {
      throw const FormatException('Duplicate chapter item reward.');
    }
    items.add(item);
  }
  return List.unmodifiable(items);
}

typedef CampaignOccurrenceSource = ({
  String id,
  String levelId,
  String chunkKey,
});

final class CampaignMissionSource {
  CampaignMissionSource._({
    required this.id,
    required this.revision,
    required this.includeInBuild,
    required this.title,
    required this.description,
    required this.visualThemeId,
    required this.levelId,
    required this.firstClearXp,
    required this.rewardAbilityId,
    required this.combatAllowed,
    required this.route,
    required this.start,
    required this.exit,
    required this.collectibles,
    required this.requiredRegions,
    required this.requiredEnemies,
    required this.requiredRescues,
    required this.placements,
  });

  factory CampaignMissionSource.decode(Object? value) {
    final m = _object(
      value,
      {
        'id',
        'revision',
        'includeInBuild',
        'title',
        'description',
        'visualThemeId',
        'levelId',
        'firstClearXp',
        'rewardAbilityId',
        'combatAllowed',
        'route',
        'start',
        'exit',
        'collectibles',
        'requiredRegions',
        'requiredEnemies',
        'requiredRescues',
        'placements',
      },
      'mission',
      optional: const {'placements'},
    );
    final route = <CampaignOccurrenceSource>[];
    final ids = <String>{};
    for (final raw in _list(
      m['route'],
      CampaignMissionDefinition.maxOccurrences,
      'route',
    )) {
      final o = _object(raw, {'id', 'levelId', 'chunkKey'}, 'occurrence');
      final id = _id(o['id'], 'occurrence.id');
      if (!ids.add(id)) throw FormatException('Duplicate occurrence $id.');
      route.add((
        id: id,
        levelId: _id(o['levelId'], 'levelId'),
        chunkKey: _id(o['chunkKey'], 'chunkKey'),
      ));
    }
    final ability = m['rewardAbilityId'];
    final missionId = _id(m['id'], 'mission.id');
    if (missionId.length > 64) {
      throw const FormatException('Mission IDs are limited to 64 characters.');
    }
    if (ability != null && ability != 'eloise.double_jump') {
      throw const FormatException('Unknown mission ability reward.');
    }
    return CampaignMissionSource._(
      id: missionId,
      revision: _integer(m['revision'], 1, 1000000000, 'revision'),
      includeInBuild: _boolean(m['includeInBuild'], 'includeInBuild'),
      title: _translation(m['title'], 'title'),
      description: _translation(m['description'], 'description'),
      visualThemeId: _id(m['visualThemeId'], 'visualThemeId'),
      levelId: _id(m['levelId'], 'levelId'),
      firstClearXp: _integer(m['firstClearXp'], 0, 100000, 'firstClearXp'),
      rewardAbilityId: ability as String?,
      combatAllowed: _boolean(m['combatAllowed'], 'combatAllowed'),
      placements: decodeCampaignPlacements(
        m.containsKey('placements') ? m['placements'] : const [],
      ),
      route: List.unmodifiable(route),
      start: m['start'] == null ? null : campaignPointFromJson(m['start']),
      exit: m['exit'] == null ? null : campaignRegionFromJson(m['exit']),
      collectibles: List.unmodifiable(
        _list(
          m['collectibles'],
          256,
          'collectibles',
        ).map(campaignPointFromJson),
      ),
      requiredRegions: List.unmodifiable(
        _list(
          m['requiredRegions'],
          32,
          'requiredRegions',
        ).map(campaignRegionFromJson),
      ),
      requiredEnemies: List.unmodifiable(
        _list(m['requiredEnemies'], 128, 'requiredEnemies').map((raw) {
          final e = _object(raw, {
            'occurrenceId',
            'markerSalt',
          }, 'enemy target');
          return (
            occurrenceId: _id(e['occurrenceId'], 'occurrenceId'),
            markerSalt: _integer(e['markerSalt'], 0, 2147483647, 'markerSalt'),
          );
        }),
      ),
      requiredRescues: List.unmodifiable(
        _list(m['requiredRescues'], 32, 'requiredRescues').map((raw) {
          final e = _object(raw, {
            'occurrenceId',
            'encounterId',
          }, 'rescue target');
          return (
            occurrenceId: _id(e['occurrenceId'], 'occurrenceId'),
            encounterId: _id(e['encounterId'], 'encounterId'),
          );
        }),
      ),
    );
  }

  final String id, visualThemeId, levelId;
  final int revision, firstClearXp;
  final bool includeInBuild, combatAllowed;
  final String? rewardAbilityId;
  final Map<String, String> title, description;
  final List<CampaignOccurrenceSource> route;
  final CampaignPoint? start;
  final CampaignRegion? exit;
  final List<CampaignPoint> collectibles;
  final List<CampaignRegion> requiredRegions;
  final List<CampaignEnemyTarget> requiredEnemies;
  final List<CampaignRescueTarget> requiredRescues;
  final List<CampaignPlacementSource> placements;

  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'includeInBuild': includeInBuild,
    'title': title,
    'description': description,
    'visualThemeId': visualThemeId,
    'levelId': levelId,
    'firstClearXp': firstClearXp,
    'rewardAbilityId': rewardAbilityId,
    'combatAllowed': combatAllowed,
    if (placements.isNotEmpty)
      'placements': placements.map((p) => p.toJson()).toList(),
    'route': route
        .map((o) => {'id': o.id, 'levelId': o.levelId, 'chunkKey': o.chunkKey})
        .toList(),
    'start': start == null ? null : campaignPointToJson(start!),
    'exit': exit == null ? null : campaignRegionToJson(exit!),
    'collectibles': collectibles.map(campaignPointToJson).toList(),
    'requiredRegions': requiredRegions.map(campaignRegionToJson).toList(),
    'requiredEnemies': requiredEnemies
        .map(
          (e) => {'occurrenceId': e.occurrenceId, 'markerSalt': e.markerSalt},
        )
        .toList(),
    'requiredRescues': requiredRescues
        .map(
          (e) => {'occurrenceId': e.occurrenceId, 'encounterId': e.encounterId},
        )
        .toList(),
  };
}

/// Captures exact source dependencies, including campaign-only variants. Runner
/// pool admission is irrelevant to a mission's explicit source references.
final class CompiledCampaignMission {
  const CompiledCampaignMission(this.source, this.chunks, this.definition);
  final CampaignMissionSource source;
  final List<PolygonTerrainRuntimeChunk> chunks;
  final CampaignMissionDefinition definition;
}

CompiledCampaignMission compileCampaignMission({
  required CampaignMissionSource source,
  required Map<String, String> chunkContentsByKey,
  required String prefabContents,
  required String tileContents,
}) {
  if (source.route.isEmpty || source.start == null || source.exit == null) {
    throw FormatException(
      '${source.id}: add a route, player start and exit before Play/Build.',
    );
  }
  final chunks = <String, PolygonTerrainRuntimeChunk>{};
  for (final o in source.route) {
    if (chunks.containsKey(o.chunkKey)) continue;
    final text = chunkContentsByKey[o.chunkKey];
    if (text == null) {
      throw FormatException('${o.id}: missing chunk ${o.chunkKey}.');
    }
    final result = compilePolygonTerrainRuntimeChunkSource(
      prefabSourcePath: 'assets/authoring/level/prefab_defs.json',
      prefabContents: prefabContents,
      tileSourcePath: 'assets/authoring/level/tile_defs.json',
      tileContents: tileContents,
      chunkSourcePath: 'assets/authoring/level/chunks/${o.chunkKey}.json',
      chunkContents: text,
      groundTopY: 224,
    );
    if (result.chunk == null || result.issues.isNotEmpty) {
      throw FormatException(
        '${o.id}: ${result.issues.map((i) => '${i.code}: ${i.message}').join('\n')}',
      );
    }
    chunks[o.chunkKey] = result.chunk!;
  }
  try {
    for (final placement in source.placements) {
      if (!source.route.any((o) => o.id == placement.occurrenceId)) {
        throw FormatException(
          '${placement.id}: unknown occurrence ${placement.occurrenceId}.',
        );
      }
    }
    final definition = CampaignMissionDefinition(
      id: source.id,
      visualThemeId: source.visualThemeId,
      interactions: [
        for (final p in source.placements.whereType<CampaignShrineSource>())
          p.bindingFor(
            source.route.firstWhere((o) => o.id == p.occurrenceId).chunkKey,
          ),
      ],
      route: FiniteChunkPatternSource(
        source.route.map((o) {
          final chunk = chunks[o.chunkKey]!;
          return FiniteChunkOccurrence(
            id: o.id,
            sourceLevelId: o.levelId,
            pattern: composeCampaignOccurrencePattern(source, o.id, chunk),
            tier: playtestTierForDifficulty(chunk.stagedTerrain.difficulty),
          );
        }),
      ),
      terrainChunks: chunks.values.map((c) => c.stagedTerrain),
      start: source.start!,
      exit: source.exit!,
      collectibles: [
        ...source.collectibles,
        for (final p in source.placements.whereType<CampaignPickupSource>())
          if (p.resource == null) p.position,
      ],
      restorations: [
        for (final p in source.placements.whereType<CampaignPickupSource>())
          if (p.resource != null)
            CampaignRestoration(position: p.position, resource: p.resource!),
      ],
      requiredRegions: source.requiredRegions,
      requiredEnemies: [
        ...source.requiredEnemies,
        for (final p in source.placements.whereType<CampaignEnemySource>())
          if (p.required)
            (occurrenceId: p.occurrenceId, markerSalt: p.marker.salt),
      ],
      requiredRescues: [
        ...source.requiredRescues,
        for (final p in source.placements.whereType<CampaignRescueSource>())
          if (p.required)
            (occurrenceId: p.occurrenceId, encounterId: p.encounter.id),
      ],
      combatAllowed: source.combatAllowed,
    );
    for (final p in source.placements.whereType<CampaignShrineSource>()) {
      final occurrence = source.route.firstWhere((o) => o.id == p.occurrenceId);
      final surface = resolveWorldInteractionSurface(
        p.bindingFor(occurrence.chunkKey),
        chunks[occurrence.chunkKey]!.stagedTerrain,
      );
      if (physicsCoordinateToTicks(p.position.y) != surface.topTicks) {
        throw FormatException(
          '${p.id}: support moved; reattach the blessing fire.',
        );
      }
    }
    return CompiledCampaignMission(
      source,
      List.unmodifiable(chunks.values),
      definition,
    );
  } on ArgumentError catch (e) {
    throw FormatException('${source.id}: ${e.message}');
  } on PlaytestScenarioException catch (e) {
    throw FormatException('${source.id}: $e');
  }
}

/// Adds mission-owned gameplay without changing or duplicating source geometry.
/// Each occurrence receives its own pattern while sharing admitted terrain.
ChunkPattern composeCampaignOccurrencePattern(
  CampaignMissionSource mission,
  String occurrenceId,
  PolygonTerrainRuntimeChunk chunk,
) {
  final local = mission.placements
      .where((p) => p.occurrenceId == occurrenceId)
      .toList();
  final base = chunk.pattern;
  if (local.isEmpty) return base;
  final enemies = local.whereType<CampaignEnemySource>().toList();
  final traps = local.whereType<CampaignTrapSource>().toList();
  final rescues = local.whereType<CampaignRescueSource>().toList();
  if (base.bossArena != null &&
      (enemies.isNotEmpty || traps.isNotEmpty || rescues.isNotEmpty)) {
    throw FormatException(
      '$occurrenceId: boss arenas cannot contain ambient enemies, traps or rescues.',
    );
  }
  return ChunkPattern(
    name: base.name,
    chunkKey: base.chunkKey,
    assemblyGroupId: base.assemblyGroupId,
    visualSprites: base.visualSprites,
    bossArena: base.bossArena,
    spawnMarkers: [...base.spawnMarkers, ...enemies.map((p) => p.marker)],
    traps: [
      ...base.traps,
      for (final p in traps)
        p.trap.copyWith(
          zIndex: p.trap.zIndex - chunk.compiled.chunk.groundBandZIndex,
        ),
    ]..sort(compareTrapPlacements),
    encounters: [...base.encounters, ...rescues.map((p) => p.encounter)]
      ..sort((a, b) => a.id.compareTo(b.id)),
  );
}

CampaignPoint campaignPointFromJson(Object? raw) {
  final p = _object(raw, {'occurrenceId', 'x', 'y'}, 'point');
  try {
    return CampaignPoint(
      occurrenceId: _id(p['occurrenceId'], 'occurrenceId'),
      x: _number(p['x'], 0, 599.5, 'x'),
      y: _number(p['y'], 0, 270, 'y'),
    );
  } on ArgumentError catch (e) {
    throw FormatException('${e.message}');
  }
}

CampaignRegion campaignRegionFromJson(Object? raw) {
  final p = _object(raw, {'origin', 'width', 'height'}, 'region');
  try {
    return CampaignRegion(
      origin: campaignPointFromJson(p['origin']),
      width: _number(p['width'], 0.5, 600, 'width'),
      height: _number(p['height'], 0.5, 270, 'height'),
    );
  } on ArgumentError catch (e) {
    throw FormatException('${e.message}');
  }
}

Map<String, Object> campaignPointToJson(CampaignPoint p) => {
  'occurrenceId': p.occurrenceId,
  'x': p.x,
  'y': p.y,
};
Map<String, Object> campaignRegionToJson(CampaignRegion r) => {
  'origin': campaignPointToJson(r.origin),
  'width': r.width,
  'height': r.height,
};

Map<String, dynamic> _object(
  Object? v,
  Set<String> keys,
  String path, {
  Set<String> optional = const {},
}) {
  if (v is! Map<String, dynamic> ||
      v.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(optional).difference(v.keys.toSet()).isNotEmpty) {
    throw FormatException('$path requires exactly: ${keys.join(', ')}.');
  }
  return v;
}

List<dynamic> _list(Object? v, int max, String path) {
  if (v is! List || v.length > max) {
    throw FormatException('$path must be an array with at most $max entries.');
  }
  return v;
}

String _id(Object? v, String path) {
  if (v is! String || !RegExp(r'^[a-z][a-z0-9_]{0,95}$').hasMatch(v)) {
    throw FormatException('$path must be a stable snake_case identifier.');
  }
  return v;
}

bool _boolean(Object? v, String path) {
  if (v is! bool) throw FormatException('$path must be boolean.');
  return v;
}

int _integer(Object? v, int min, int max, String path) {
  if (v is! int || v < min || v > max) {
    throw FormatException('$path must be an integer in $min..$max.');
  }
  return v;
}

double _number(Object? v, double min, double max, String path) {
  if (v is! num || !v.isFinite || v < min || v > max) {
    throw FormatException('$path must be finite in $min..$max.');
  }
  return v.toDouble();
}

Map<String, String> _translation(Object? v, String path) {
  final m = _object(v, {'en', 'fr'}, path);
  return Map.unmodifiable(
    m.map((k, v) {
      if (v is! String || v.trim().isEmpty || v.length > 2000) {
        throw FormatException('$path.$k needs text (max 2000 characters).');
      }
      return MapEntry(k, v);
    }),
  );
}
