part of '../campaign_tutorial.dart';

/// Approach guidance follows a real, stable water region in a mission chunk.
/// The distance is measured left of its near bank in world units, not HUD pixels.
final class CampaignWaterTutorial extends CampaignPanelTutorial {
  CampaignWaterTutorial._(
    super.json, {
    required this.missionChunkId,
    required this.waterRegionId,
    required this.approachDistance,
  }) : super._();

  factory CampaignWaterTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'water',
      CampaignTutorialTrigger.waterApproached,
      null,
      extraFields: {'missionChunkId', 'waterRegionId', 'approachDistance'},
    );
    final chunk = json['missionChunkId'], water = json['waterRegionId'];
    if (chunk is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(chunk) ||
        water is! String ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(water)) {
      throw const FormatException(
        'Water guidance requires a chunk and water region.',
      );
    }
    return CampaignWaterTutorial._(
      json,
      missionChunkId: chunk,
      waterRegionId: water,
      approachDistance: _number(json['approachDistance'], 1, 600),
    );
  }

  @override
  final String missionChunkId;
  final String waterRegionId;
  final double approachDistance;
  @override
  String get kind => 'water';
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.waterApproached;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.water;

  /// Resolve from the actual captured/generated mission, never a second catalog.
  /// Missing regions fail Build/Play, including disabled authored lessons.
  WaterRegionData resolveWater(CampaignMissionDefinition mission) =>
      _resolveTutorialWater(mission, id, missionChunkId, waterRegionId);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'missionChunkId': missionChunkId,
      'waterRegionId': waterRegionId,
      'approachDistance': approachDistance,
    });

  static CampaignWaterTutorial introduction({
    required String missionChunkId,
    required String waterRegionId,
    double approachDistance = 20,
  }) => CampaignWaterTutorial.decode({
    'id': 'water_introduction',
    'name': 'Water introduction',
    'enabled': true,
    'trigger': 'waterApproached',
    'kind': 'water',
    'missionChunkId': missionChunkId,
    'waterRegionId': waterRegionId,
    'approachDistance': approachDistance,
    'title': {'en': 'Water ahead', 'fr': 'De l’eau devant toi'},
    'instruction': {
      'en': 'You can jump across water or swim through it. Moving in water is slower. Release, then move again to continue.',
      'fr': 'Tu peux sauter par-dessus l’eau ou la traverser à la nage. Dans l’eau, tu te déplaces plus lentement. Relâche puis bouge à nouveau pour continuer.',
    },
    'spotlight': const TutorialSpotlight().toJson(),
    'reveals': <String>[],
  });
}

/// First actual swimming state in any pool; bypassing water never blocks lessons.
final class CampaignSwimmingTutorial extends CampaignPanelTutorial {
  CampaignSwimmingTutorial._(super.json) : super._();
  factory CampaignSwimmingTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'swimming',
      CampaignTutorialTrigger.firstSwimming,
      TutorialHudElement.jump,
    );
    if (!decodeTutorialHud(json['reveals'])
        .contains(TutorialHudElement.resources)) {
      throw const FormatException(
        'Swimming guidance must retain resource bars.',
      );
    }
    return CampaignSwimmingTutorial._(json);
  }
  @override
  bool get optional => true;
  @override
  String get kind => 'swimming';
  @override
  CampaignTutorialTrigger get trigger => CampaignTutorialTrigger.firstSwimming;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.jump;
  @override
  CampaignTutorialContinuation continuationAt(int step) =>
      CampaignTutorialContinuation.jump;

  static CampaignSwimmingTutorial introduction() =>
      CampaignSwimmingTutorial.decode({
        'id': 'swimming_introduction',
        'name': 'First swim',
        'enabled': true,
        'trigger': 'firstSwimming',
        'kind': 'swimming',
        'title': {'en': 'Swim upward', 'fr': 'Nage vers le haut'},
        'instruction': {
          'en': 'Press Jump (Space on a keyboard) to swim upward. Each stroke uses stamina. Keep moving toward the bank and press Jump again to climb out.',
          'fr': 'Appuie sur Sauter (Espace au clavier) pour nager vers le haut. Chaque impulsion consomme de l’endurance. Avance vers la rive et appuie à nouveau sur Sauter pour sortir de l’eau.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
          x: -0.1,
          y: -0.1,
          width: 1.2,
          height: 1.2,
        ).toJson(),
        'reveals': ['jump', 'resources'],
      });
}

/// Validate presentation attachments without introducing tutorial state to Core.
void validateCampaignTutorialTargets(
  Iterable<CampaignTutorialSequence> sequences,
  CampaignMissionDefinition mission,
) {
  for (final lesson in sequences) {
    final chunk = lesson.missionChunkId;
    if (chunk != null) mission.missionChunkIndex(chunk);
    if (lesson is CampaignWaterTutorial) lesson.resolveWater(mission);
    if (lesson is CampaignGapTutorial) lesson.resolveGap(mission);
    if (lesson is CampaignPlatformTutorial) lesson.resolvePlatform(mission);
    if (lesson is CampaignBlessingTutorial) lesson.resolveShrine(mission);
    if (lesson is CampaignCombatTutorial) lesson.validateTarget(mission);
    if (lesson is CampaignDecorationTutorial) {
      lesson.resolveWater(mission);
      lesson.resolveDecoration(mission);
    }
  }
}

WaterRegionData _resolveTutorialWater(
  CampaignMissionDefinition mission,
  String lessonId,
  String chunkId,
  String waterId,
) {
  final chunk = mission.route.missionChunks[mission.missionChunkIndex(chunkId)];
  final water = mission.terrainCatalog
      .requireChunk(chunk.pattern.chunkKey!)
      .waterRegions
      .where((region) => region.id == waterId)
      .firstOrNull;
  if (water == null) {
    throw FormatException(
      'Tutorial $lessonId: missing water $waterId in $chunkId.',
    );
  }
  return water;
}
