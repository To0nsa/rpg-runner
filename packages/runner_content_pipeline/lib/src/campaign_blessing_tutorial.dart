part of '../campaign_tutorial.dart';

/// One authored sequence with real gameplay between the approach and reward pages.
/// The stable shrine marker also identifies the independently required Core goal.
final class CampaignBlessingTutorial extends CampaignSteppedTutorial {
  CampaignBlessingTutorial._({
    required super.id,
    required super.name,
    required super.enabled,
    required super.steps,
    required this.shrineId,
    required this.approachDistance,
  });

  factory CampaignBlessingTutorial.decode(Object? value) {
    final json = _object(value, {
      'id',
      'name',
      'enabled',
      'trigger',
      'kind',
      'shrineId',
      'approachDistance',
      'steps',
    });
    final id = json['id'], shrine = json['shrineId'], raw = json['steps'];
    final identity = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
    if (id is! String ||
        !identity.hasMatch(id) ||
        shrine is! String ||
        !identity.hasMatch(shrine) ||
        json['enabled'] is! bool ||
        json['trigger'] != 'blessingApproached' ||
        json['kind'] != 'blessing' ||
        raw is! List ||
        raw.length != 3) {
      throw const FormatException('Invalid three-step blessing sequence.');
    }
    const targets = [
      CampaignTutorialTarget.shrine,
      CampaignTutorialTarget.shrine,
      CampaignTutorialTarget.blessingResources,
    ];
    final steps = List<CampaignTutorialStep>.unmodifiable([
      for (var i = 0; i < targets.length; i++)
        CampaignTutorialStep.decode(raw[i], targets[i]),
    ]);
    if (!steps.first.reveals.containsAll({
          TutorialHudElement.objectives,
          TutorialHudElement.jump,
        }) ||
        !steps.last.reveals.contains(TutorialHudElement.blessings)) {
      throw const FormatException(
        'Blessing guidance must reveal its objective, Jump and blessing indicator.',
      );
    }
    return CampaignBlessingTutorial._(
      id: id,
      name: _text(json['name'], 120),
      enabled: json['enabled'] as bool,
      shrineId: shrine,
      approachDistance: _number(json['approachDistance'], 1, 600),
      steps: steps,
    );
  }

  final String shrineId;
  final double approachDistance;
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.blessingApproached;
  @override
  CampaignTutorialContinuation continuationAt(int step) => step == 1
      ? CampaignTutorialContinuation.next
      : CampaignTutorialContinuation.movement;

  CampaignTutorialShrine resolveShrine(CampaignMissionDefinition mission) {
    final goal = mission.requiredBlessingShrine;
    final binding = mission.interactions
        .where(
          (b) => b.key == shrineId && b.missionChunkId == goal?.missionChunkId,
        )
        .firstOrNull;
    if (goal?.bindingKey != shrineId || binding == null) {
      throw FormatException(
        'Tutorial $id must target the mission blessing objective shrine.',
      );
    }
    final chunk = mission
        .route
        .missionChunks[mission.missionChunkIndex(binding.missionChunkId!)];
    return campaignTutorialShrine(
      binding,
      mission.terrainCatalog.requireChunk(binding.chunkKey),
      chunk.pattern.visualSprites,
    );
  }

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': trigger.name,
    'kind': 'blessing',
    'shrineId': shrineId,
    'approachDistance': approachDistance,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  static CampaignBlessingTutorial introduction({
    required String shrineId,
  }) => CampaignBlessingTutorial.decode({
    'id': 'blessing_introduction',
    'name': 'Blessing objective and regeneration',
    'enabled': true, 'trigger': 'blessingApproached', 'kind': 'blessing',
    'shrineId': shrineId,
    // World units before the activation surface, leaving a grounded jump approach.
    'approachDistance': 96,
    'steps': [
      {
        'target': 'shrine',
        'title': {'en': 'Receive a blessing', 'fr': 'Reçois une bénédiction'},
        'instruction': {
          'en': 'Your next objective is to receive a blessing. Jump onto the basin to light its fire. Release, then move again to approach and jump.',
          'fr': 'Ton prochain objectif est de recevoir une bénédiction. Saute sur la vasque pour allumer son feu. Relâche puis bouge à nouveau pour t’approcher et sauter.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': ['objectives', 'jump'],
      },
      {
        'target': 'shrine',
        'title': {'en': 'A blessing received', 'fr': 'Une bénédiction reçue'},
        'instruction': {
          'en': 'You lit the basin and received the Bénédiction des Dames de la forêt. Your objective is complete. Next, see what the blessing gives you.',
          'fr': 'Tu as allumé la vasque et reçu la Bénédiction des Dames de la forêt. Ton objectif est accompli. Voyons maintenant ce que la bénédiction t’apporte.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': ['objectives'],
      },
      {
        'target': 'blessingResources',
        'title': {
          'en': 'Improved regeneration',
          'fr': 'Une meilleure régénération',
        },
        'instruction': {
          'en': 'Your health, ability resource and stamina now recover faster, without an instant refill. The fire indicator marks this blessing, which lasts for the rest of this attempt. Lighting another basin does not stack the bonus. Release, then move again to continue.',
          'fr': 'Ta santé, ta ressource de capacités et ton endurance se régénèrent plus vite, sans recharge immédiate. L’icône de feu indique cette bénédiction, active jusqu’à la fin de cette tentative. Allumer une autre vasque ne cumule pas le bonus. Relâche puis bouge à nouveau pour continuer.',
        },
        'spotlight': const TutorialSpotlight().toJson(),
        'reveals': ['resources', 'blessings'],
      },
    ],
  });
}

/// Current chunk-local shrine/fire envelope and the authoritative approach edge.
final class CampaignTutorialShrine {
  const CampaignTutorialShrine({
    required this.binding,
    required this.left,
    required this.bounds,
  });
  final WorldInteractionBinding binding;
  final double left;
  final ({double x, double y, double width, double height}) bounds;
  String get id => binding.key;
  String get missionChunkId => binding.missionChunkId!;
}

/// Reuses the gameplay surface resolver. The visual envelope includes space for
/// the fire above its top; authors can adjust the opening without editing terrain.
CampaignTutorialShrine campaignTutorialShrine(
  WorldInteractionBinding binding,
  StagedTerrainChunkData terrain,
  Iterable<ChunkVisualSpriteRel> sprites,
) {
  final surface = resolveWorldInteractionSurface(binding, terrain);
  final left = surface.leftTicks / terrainPhysicsTicksPerWorldUnit;
  final right = surface.rightTicks / terrainPhysicsTicksPerWorldUnit;
  final top = surface.topTicks / terrainPhysicsTicksPerWorldUnit;
  final padding = 24 * surface.scale;
  var x = (left + right) / 2 - padding, y = top - 36 * surface.scale;
  var farX = (left + right) / 2 + padding, bottom = top + 32 * surface.scale;
  final placements = terrain.placementLineage
      .where((p) => p.prefabKey == binding.prefabKey)
      .map((p) => p.sourceId.placementKey)
      .toSet();
  // Sprite snapshots lack instance identity. Only union art when it is unambiguous;
  // exact surface binding still supports repeated prefabs and direct terrain tops.
  if (binding.prefabKey != null && placements.length == 1) {
    for (final sprite in sprites.where(
      (s) => s.prefabKey == binding.prefabKey,
    )) {
      final b = campaignTutorialSpriteBounds(sprite);
      x = math.min(x, b.x);
      y = math.min(y, b.y);
      farX = math.max(farX, b.x + b.width);
      bottom = math.max(bottom, b.y + b.height);
    }
  }
  return CampaignTutorialShrine(
    binding: binding,
    left: left,
    bounds: (x: x, y: y, width: farX - x, height: bottom - y),
  );
}
