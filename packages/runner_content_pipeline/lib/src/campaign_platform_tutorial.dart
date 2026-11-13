part of '../campaign_tutorial.dart';

/// One approach explanation for a unique placed one-way prefab. The target uses
/// compiled placement lineage so tiled visuals do not masquerade as duplicates.
final class CampaignPlatformTutorial extends CampaignPanelTutorial {
  CampaignPlatformTutorial._(
    super.json, {
    required this.missionChunkId,
    required this.platformPrefabKey,
    required this.approachDistance,
  }) : super._();

  factory CampaignPlatformTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'platform',
      CampaignTutorialTrigger.platformApproached,
      null,
      extraFields: {'missionChunkId', 'platformPrefabKey', 'approachDistance'},
    );
    final chunk = json['missionChunkId'], prefab = json['platformPrefabKey'];
    if (chunk is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(chunk) ||
        prefab is! String ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(prefab)) {
      throw const FormatException(
        'Platform guidance requires a chunk and prefab key.',
      );
    }
    return CampaignPlatformTutorial._(
      json,
      missionChunkId: chunk,
      platformPrefabKey: prefab,
      approachDistance: _number(json['approachDistance'], 1, 600),
    );
  }
  @override
  final String missionChunkId;
  final String platformPrefabKey;
  final double approachDistance;
  @override
  String get kind => 'platform';
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.platformApproached;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.platform;

  /// Resolves the actual captured mission, including unsaved editor geometry.
  /// Missing, duplicate and changed collision targets fail even when disabled.
  CampaignTutorialPlatform resolvePlatform(CampaignMissionDefinition mission) {
    final chunk =
        mission.route.missionChunks[mission.missionChunkIndex(missionChunkId)];
    final platform = campaignTutorialPlatforms(
      mission.terrainCatalog.requireChunk(chunk.pattern.chunkKey!),
      chunk.pattern.visualSprites,
    ).where((p) => p.prefabKey == platformPrefabKey).firstOrNull;
    if (platform == null) {
      throw FormatException(
        'Tutorial $id: $platformPrefabKey must be a unique one-way platform in $missionChunkId.',
      );
    }
    return platform;
  }

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'missionChunkId': missionChunkId,
      'platformPrefabKey': platformPrefabKey,
      'approachDistance': approachDistance,
    });
  static CampaignPlatformTutorial introduction({
    required String missionChunkId,
    required String platformPrefabKey,
    // World units: a grounded approach with room to choose when to jump.
    double approachDistance = 64,
  }) => CampaignPlatformTutorial.decode({
    'id': 'platform_introduction',
    'name': 'Platforms',
    'enabled': true,
    'trigger': 'platformApproached',
    'kind': 'platform',
    'missionChunkId': missionChunkId,
    'platformPrefabKey': platformPrefabKey,
    'approachDistance': approachDistance,
    'title': {'en': 'Platforms', 'fr': 'Les plateformes'},
    'instruction': {
      'en': 'Jump up through platforms and land on top as you come down. Use them to reach higher places and cross gaps. Release, then move again to continue.',
      'fr': 'Saute à travers les plateformes par-dessous et atterris dessus en redescendant. Utilise-les pour atteindre des endroits plus élevés et franchir les trous. Relâche puis bouge à nouveau pour continuer.',
    },
    'spotlight': const TutorialSpotlight(
      shape: TutorialSpotlightShape.ellipse,
      x: -0.25,
      y: -0.4,
      width: 1.5,
      height: 1.8,
    ).toJson(),
    'reveals': <String>[],
  });
}

/// Current chunk-local visual bounds and physical approach edges, in world units.
/// One platform can contain many render tiles and collision shapes.
final class CampaignTutorialPlatform {
  const CampaignTutorialPlatform._({
    required this.prefabKey,
    required this.bounds,
    required this.left,
    required this.right,
  });
  final String prefabKey;
  final ({double x, double y, double width, double height}) bounds;
  final double left, right;
}

/// Eligible targets share a single placement, only one-way collision, an exposed
/// upper surface, and rendered visuals. Repeated prefab instances are ambiguous.
List<CampaignTutorialPlatform> campaignTutorialPlatforms(
  StagedTerrainChunkData terrain,
  Iterable<ChunkVisualSpriteRel> sprites,
) {
  final placements = <String, Set<String>>{};
  for (final lineage in terrain.placementLineage) {
    final placement = lineage.sourceId.placementKey;
    if (placement != null) {
      (placements[lineage.prefabKey] ??= {}).add(placement);
    }
  }
  final result = <CampaignTutorialPlatform>[];
  for (final entry in placements.entries) {
    if (entry.value.length != 1) continue;
    final polygons = terrain.polygons
        .where((p) => p.id.placementKey == entry.value.single)
        .toList();
    if (polygons.isEmpty ||
        polygons.any(
          (p) => p.collisionMode != StagedTerrainCollisionMode.oneWay,
        ) ||
        !terrain.edges.any(
          (e) =>
              e.id.sourceId.placementKey == entry.value.single &&
              e.outwardNormal.yTicks < 0,
        )) {
      continue;
    }
    final visuals = sprites
        .where((s) => s.prefabKey == entry.key && !s.isDecoration)
        .toList();
    if (visuals.isEmpty) continue;
    final bounds = visuals.map(campaignTutorialSpriteBounds).toList();
    final x = bounds.map((b) => b.x).reduce(math.min),
        y = bounds.map((b) => b.y).reduce(math.min);
    final right = bounds.map((b) => b.x + b.width).reduce(math.max),
        bottom = bounds.map((b) => b.y + b.height).reduce(math.max);
    final vertices = polygons.expand((p) => p.vertices).toList();
    result.add(
      CampaignTutorialPlatform._(
        prefabKey: entry.key,
        bounds: (x: x, y: y, width: right - x, height: bottom - y),
        left:
            vertices.map((p) => p.xTicks).reduce(math.min) /
            terrainPhysicsTicksPerWorldUnit,
        right:
            vertices.map((p) => p.xTicks).reduce(math.max) /
            terrainPhysicsTicksPerWorldUnit,
      ),
    );
  }
  result.sort((a, b) {
    final order = a.left.compareTo(b.left);
    return order != 0 ? order : a.prefabKey.compareTo(b.prefabKey);
  });
  return List.unmodifiable(result);
}
