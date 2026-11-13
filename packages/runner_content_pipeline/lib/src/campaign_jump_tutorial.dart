part of '../campaign_tutorial.dart';

/// An authored visual target in one 600x270 mission chunk, never collision data.
final class TutorialObstacleBounds {
  TutorialObstacleBounds.decode(Object? value) {
    final json = _object(value, {'x', 'y', 'width', 'height'});
    x = _number(json['x'], 0, 600);
    y = _number(json['y'], 0, 270);
    width = _number(json['width'], 1, 600);
    height = _number(json['height'], 1, 270);
    if (x + width > 600 || y + height > 270) {
      throw const FormatException(
        'Obstacle target must fit its mission chunk.',
      );
    }
  }

  late final double x, y, width, height;
  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

/// One chunk-attached sequence. Its three pages never run as separate triggers.
final class CampaignJumpTutorial extends CampaignSteppedTutorial {
  CampaignJumpTutorial._({
    required super.id,
    required super.name,
    required super.enabled,
    required this.missionChunkId,
    required this.obstacle,
    required super.steps,
  });

  factory CampaignJumpTutorial.decode(Object? value) {
    final json = _object(value, {
      'id',
      'name',
      'enabled',
      'trigger',
      'kind',
      'missionChunkId',
      'obstacle',
      'steps',
    });
    final id = json['id'],
        chunk = json['missionChunkId'],
        rawSteps = json['steps'];
    final identity = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
    if (id is! String ||
        !identity.hasMatch(id) ||
        chunk is! String ||
        !identity.hasMatch(chunk) ||
        json['enabled'] is! bool ||
        json['trigger'] != 'chunkEntered' ||
        json['kind'] != 'obstaclesAndJump' ||
        rawSteps is! List ||
        rawSteps.length != 3) {
      throw const FormatException(
        'Invalid three-step obstacle and jump sequence.',
      );
    }
    const targets = [
      CampaignTutorialTarget.obstacle,
      CampaignTutorialTarget.jump,
      CampaignTutorialTarget.resources,
    ];
    return CampaignJumpTutorial._(
      id: id,
      name: _text(json['name'], 120),
      enabled: json['enabled'] as bool,
      missionChunkId: chunk,
      obstacle: TutorialObstacleBounds.decode(json['obstacle']),
      steps: List.unmodifiable([
        for (var i = 0; i < 3; i++)
          CampaignTutorialStep.decode(rawSteps[i], targets[i]),
      ]),
    );
  }

  @override
  final String missionChunkId;
  final TutorialObstacleBounds obstacle;
  @override
  CampaignTutorialTrigger get trigger => CampaignTutorialTrigger.chunkEntered;
  @override
  CampaignTutorialContinuation continuationAt(int step) => step == 2
      ? CampaignTutorialContinuation.jump
      : CampaignTutorialContinuation.next;
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': trigger.name,
    'kind': 'obstaclesAndJump',
    'missionChunkId': missionChunkId,
    'obstacle': obstacle.toJson(),
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  static CampaignJumpTutorial introduction({
    required String missionChunkId,
  }) => CampaignJumpTutorial.decode({
    'id': 'obstacles_and_jump',
    'name': 'Obstacles, jump and resources',
    'enabled': true,
    'trigger': 'chunkEntered',
    'kind': 'obstaclesAndJump',
    'missionChunkId': missionChunkId,
    'obstacle': {'x': 15, 'y': 138, 'width': 250, 'height': 96},
    'steps': [
      {
        'target': 'obstacle',
        'title': {'en': 'Obstacles ahead', 'fr': 'Des obstacles sur le chemin'},
        'instruction': {
          'en': 'Obstacles interrupt your path. This rock is one of them. You can jump onto or over obstacles to keep going.',
          'fr': 'Les obstacles coupent ton chemin. Ce rocher en est un. Tu peux sauter dessus ou par-dessus pour continuer.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': <String>[],
      },
      {
        'target': 'jump',
        'title': {'en': 'Jump', 'fr': 'Sauter'},
        'instruction': {
          'en': 'This is your Jump button. Use it while moving to get past obstacles. On a keyboard, press Space. Next, see what a jump costs.',
          'fr': 'Voici le bouton Sauter. Utilise-le en te déplaçant pour franchir les obstacles. Au clavier, appuie sur Espace. Voyons maintenant le coût d’un saut.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
          x: -0.1,
          y: -0.1,
          width: 1.2,
          height: 1.2,
        ).toJson(),
        'reveals': ['jump'],
      },
      {
        'target': 'resources',
        'title': {'en': 'Watch your stamina', 'fr': 'Surveille ton endurance'},
        'instruction': {
          'en': 'Red is health, the middle bar fuels your abilities, and green is stamina. Jumping uses stamina, which recovers over time. Press Jump (Space on a keyboard) to try, then keep moving.',
          'fr': 'Le rouge indique ta santé, la barre du milieu alimente tes capacités et le vert indique ton endurance. Sauter consomme de l’endurance, qui se régénère avec le temps. Appuie sur Sauter (Espace au clavier) pour essayer, puis continue à avancer.',
        },
        'spotlight': const TutorialSpotlight().toJson(),
        'reveals': ['resources'],
      },
    ],
  });
}
