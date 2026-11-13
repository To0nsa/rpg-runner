part of '../campaign_tutorial.dart';

/// One marker-bound encounter, with live practice between the ranged and melee
/// pages. The lock is attempt-local guidance, never a cooldown or damage rule.
final class CampaignCombatTutorial extends CampaignSteppedTutorial {
  CampaignCombatTutorial._({
    required super.id,
    required super.name,
    required super.enabled,
    required super.steps,
    required this.missionChunkId,
    required this.markerSalt,
    required this.approachDistance,
    required this.practiceHint,
  });

  factory CampaignCombatTutorial.decode(Object? value) {
    final json = _object(value, {
      'id',
      'name',
      'enabled',
      'trigger',
      'kind',
      'missionChunkId',
      'markerSalt',
      'approachDistance',
      'practiceHint',
      'steps',
    });
    final identity = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
    final id = json['id'],
        chunk = json['missionChunkId'],
        salt = json['markerSalt'],
        raw = json['steps'];
    if (id is! String ||
        !identity.hasMatch(id) ||
        chunk is! String ||
        !identity.hasMatch(chunk) ||
        salt is! int ||
        salt < 0 ||
        json['enabled'] is! bool ||
        json['trigger'] != 'enemyApproached' ||
        json['kind'] != 'combat' ||
        raw is! List ||
        raw.length != 3) {
      throw const FormatException('Invalid three-page combat sequence.');
    }
    const targets = [
      CampaignTutorialTarget.enemy,
      CampaignTutorialTarget.projectile,
      CampaignTutorialTarget.primary,
    ];
    final steps = List<CampaignTutorialStep>.unmodifiable([
      for (var i = 0; i < targets.length; i++)
        CampaignTutorialStep.decode(raw[i], targets[i]),
    ]);
    if (steps
        .take(2)
        .any((s) => s.reveals.contains(TutorialHudElement.primary))) {
      throw const FormatException(
        'Sword must remain hidden until the melee page.',
      );
    }
    return CampaignCombatTutorial._(
      id: id,
      name: _text(json['name'], 120),
      enabled: json['enabled'] as bool,
      steps: steps,
      missionChunkId: chunk,
      markerSalt: salt,
      approachDistance: _number(json['approachDistance'], 1, 600),
      practiceHint: _translation(json['practiceHint'], 250),
    );
  }
  @override
  final String missionChunkId;
  final int markerSalt;
  final double approachDistance;
  final Map<String, String> practiceHint;
  CampaignEnemyTarget get enemyTarget =>
      (missionChunkId: missionChunkId, markerSalt: markerSalt);
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.enemyApproached;
  @override
  CampaignTutorialContinuation continuationAt(int step) => switch (step) {
    0 => CampaignTutorialContinuation.next,
    1 => CampaignTutorialContinuation.projectile,
    _ => CampaignTutorialContinuation.primary,
  };

  /// Validate the exact marker, including disabled guidance. A probabilistic
  /// spawn cannot reliably support this authored encounter.
  void validateTarget(CampaignMissionDefinition mission) {
    final chunk =
        mission.route.missionChunks[mission.missionChunkIndex(missionChunkId)];
    if (!chunk.pattern.spawnMarkers.any(
      (m) => m.salt == markerSalt && m.chancePercent == 100,
    )) {
      throw FormatException(
        'Tutorial $id requires a guaranteed enemy marker in $missionChunkId.',
      );
    }
  }

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'kind': 'combat',
    'trigger': trigger.name,
    'missionChunkId': missionChunkId,
    'markerSalt': markerSalt,
    'approachDistance': approachDistance,
    'practiceHint': practiceHint,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
  static CampaignCombatTutorial introduction({
    required String missionChunkId,
    required int markerSalt,
  }) => CampaignCombatTutorial.decode({
    'id': 'combat_introduction',
    'name': 'Projectiles and sword',
    'enabled': true,
    'kind': 'combat',
    'trigger': 'enemyApproached',
    'missionChunkId': missionChunkId,
    'markerSalt': markerSalt,
    'approachDistance': 250,
    'practiceHint': {
      'en': 'Let the enemy approach, then use your sword. Projectiles unlock after your first sword strike.',
      'fr': 'Laisse l’ennemi approcher, puis utilise ton épée. Les projectiles seront débloqués après ton premier coup d’épée.',
    },
    'steps': [
      {
        'target': 'enemy',
        'title': {'en': 'Your first enemy', 'fr': 'Ton premier ennemi'},
        'instruction': {
          'en': 'Enemies can hurt you. Attack from a distance with a projectile, then use your sword when this enemy gets close.',
          'fr': 'Les ennemis peuvent te blesser. Attaque à distance avec un projectile, puis utilise ton épée quand cet ennemi s’approche.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': [],
      },
      {
        'target': 'projectile',
        'title': {'en': 'Attack from a distance', 'fr': 'Attaque à distance'},
        'instruction': {
          'en': 'Projectiles consume mana. Press Projectile (K or right mouse button) to fire. We will pause further shots while you practise the sword.',
          'fr': 'Les projectiles consomment du mana. Appuie sur Projectile (K ou clic droit) pour tirer. Les tirs suivants seront suspendus pendant l’apprentissage de l’épée.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': ['projectile'],
      },
      {
        'target': 'primary',
        'title': {'en': 'Strike with your sword', 'fr': 'Frappe avec ton épée'},
        'instruction': {
          'en': 'This enemy is within sword reach. Sword attacks consume stamina. Press Sword (J or left mouse button) to strike and unlock projectiles.',
          'fr': 'Cet ennemi est à portée de ton épée. Les coups d’épée consomment de l’endurance. Appuie sur Épée (J ou clic gauche) pour frapper et débloquer les projectiles.',
        },
        'spotlight': const TutorialSpotlight(
          shape: TutorialSpotlightShape.ellipse,
        ).toJson(),
        'reveals': ['primary'],
      },
    ],
  });
}
