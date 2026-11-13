part of '../campaign_tutorial.dart';

/// A grounded Dash introduction at an authored chunk-local X, in world units.
/// The HUD spotlight is independent of this trigger; moving it never moves terrain.
final class CampaignMobilityTutorial extends CampaignPanelTutorial {
  CampaignMobilityTutorial._(
    super.json, {
    required this.missionChunkId,
    required this.triggerX,
  }) : super._();

  factory CampaignMobilityTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'mobility',
      CampaignTutorialTrigger.mobilityReached,
      TutorialHudElement.mobility,
      extraFields: {'missionChunkId', 'triggerX'},
    );
    final chunk = json['missionChunkId'];
    if (chunk is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(chunk)) {
      throw const FormatException(
        'Mobility guidance requires a mission chunk.',
      );
    }
    final x = json['triggerX'];
    if (x is! num || !x.isFinite || x < 0 || x > 600) {
      throw const FormatException(
        'Mobility trigger X must be between 0 and 600 world units.',
      );
    }
    return CampaignMobilityTutorial._(
      json,
      missionChunkId: chunk,
      triggerX: x.toDouble(),
    );
  }

  @override
  final String missionChunkId;
  final double triggerX;
  @override
  String get kind => 'mobility';
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.mobilityReached;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.mobility;
  @override
  CampaignTutorialContinuation continuationAt(int step) =>
      CampaignTutorialContinuation.mobility;
  @override
  Map<String, Object?> toJson() =>
      super.toJson()
        ..addAll({'missionChunkId': missionChunkId, 'triggerX': triggerX});

  static CampaignMobilityTutorial introduction({
    required String missionChunkId,
    // Near the eighth-chunk bush, after the pool and before the downhill seam.
    double triggerX = 522,
  }) => CampaignMobilityTutorial.decode({
    'id': 'mobility_introduction',
    'name': 'Mobility: Dash',
    'enabled': true,
    'trigger': 'mobilityReached',
    'kind': 'mobility',
    'missionChunkId': missionChunkId,
    'triggerX': triggerX,
    'title': {'en': 'Mobility: Dash', 'fr': 'Mobilité : Ruée'},
    'instruction': {
      'en': 'Dash gives you a short burst of speed. It uses stamina and needs a moment to recharge. Press the Mobility button (Shift on a keyboard) to try it.',
      'fr': 'La ruée te donne une brève accélération. Elle consomme de l’endurance et demande un instant de recharge. Appuie sur le bouton Mobilité (Maj au clavier) pour essayer.',
    },
    'spotlight': const TutorialSpotlight(
      shape: TutorialSpotlightShape.ellipse,
      x: -0.1,
      y: -0.1,
      width: 1.2,
      height: 1.2,
    ).toJson(),
    'reveals': ['mobility'],
  });
}
