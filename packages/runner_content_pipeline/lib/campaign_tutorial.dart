/// Authored presentation values shared by Campaign source, editor and game UI.
/// These values never enter Core simulation or replay commands.
library;

import 'dart:math' as math;

import 'package:runner_core/interactions/world_interaction_catalog.dart';
import 'package:runner_core/interactions/world_interaction_placement.dart';

import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/chunk_pattern.dart';

part 'src/campaign_stepped_tutorial.dart';
part 'src/campaign_blessing_tutorial.dart';
part 'src/campaign_jump_tutorial.dart';
part 'src/campaign_water_tutorial.dart';
part 'src/campaign_decoration_tutorial.dart';
part 'src/campaign_gap_tutorial.dart';
part 'src/campaign_platform_tutorial.dart';
part 'src/campaign_mobility_tutorial.dart';
part 'src/campaign_combat_tutorial.dart';

enum TutorialMovementControl {
  arrows,
  fixedJoystick,
  floatingJoystick,
  keyboard,
}

enum TutorialSpotlightShape { ellipse, roundedRectangle }

/// Rectangle expressed in fractions of the actual HUD target's bounds.
/// Negative offsets provide padding without tying content to a device size.
final class TutorialSpotlight {
  const TutorialSpotlight({
    this.shape = TutorialSpotlightShape.roundedRectangle,
    this.x = -0.1,
    this.y = -0.2,
    this.width = 1.2,
    this.height = 1.4,
  });

  factory TutorialSpotlight.decode(Object? value) {
    final json = _object(value, {'shape', 'x', 'y', 'width', 'height'});
    return TutorialSpotlight(
      shape: _enumValue(TutorialSpotlightShape.values, json['shape']),
      x: _number(json['x'], -2, 2),
      y: _number(json['y'], -2, 2),
      width: _number(json['width'], 0.25, 4),
      height: _number(json['height'], 0.25, 4),
    );
  }

  final TutorialSpotlightShape shape;
  final double x, y, width, height;
  Map<String, Object?> toJson() => {
    'shape': shape.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

/// HUD features accumulate as lessons introduce them. Abilities also gate input.
enum TutorialHudElement {
  movement,
  resources,
  objectives,
  runStats,
  jump,
  primary,
  secondary,
  projectile,
  spell,
  mobility,
  blessings,
}

const allTutorialHud = <TutorialHudElement>{...TutorialHudElement.values};

enum CampaignTutorialTrigger {
  missionStart,
  movementStarted,
  firstCoinCollected,
  chunkEntered,
  waterApproached,
  firstSwimming,
  waterCleared,
  gapApproached,
  platformApproached,
  blessingApproached,
  mobilityReached,
  enemyApproached,
}

enum CampaignTutorialTarget {
  movement,
  objectives,
  runStats,
  obstacle,
  jump,
  resources,
  water,
  decoration,
  gap,
  platform,
  shrine,
  mobility,
  blessingResources,
  enemy,
  projectile,
  primary;

  bool get isWorld => switch (this) {
    obstacle ||
    water ||
    decoration ||
    gap ||
    platform ||
    shrine ||
    enemy => true,
    _ => false,
  };
}

enum CampaignTutorialContinuation {
  movement,
  next,
  jump,
  mobility,
  projectile,
  primary,
}

/// Immutable authored guidance. Core retains pickup and reward authority;
/// the shared presentation session owns per-attempt progression and pausing.
sealed class CampaignTutorialSequence {
  CampaignTutorialSequence({
    required this.id,
    required this.name,
    required this.enabled,
    required this.title,
    required this.reveals,
  });
  final String id, name;
  final bool enabled;
  final Map<String, String> title;
  final Set<TutorialHudElement> reveals;
  CampaignTutorialTrigger get trigger;
  CampaignTutorialTarget get target;
  String? get missionChunkId => null;

  /// Optional situational hints remain eligible without holding up route lessons.
  bool get optional => false;
  int get stepCount => 1;
  CampaignTutorialTarget targetAt(int step) => target;
  Set<TutorialHudElement> revealsAt(int step) => reveals;
  CampaignTutorialContinuation continuationAt(int step) =>
      CampaignTutorialContinuation.movement;
  String titleFor(String language, {int step = 0}) =>
      title[language] ?? title['en']!;
  String instructionFor(
    TutorialMovementControl control,
    String language, {
    int step = 0,
  });
  TutorialSpotlight? spotlightFor(
    TutorialMovementControl control, {
    int step = 0,
  });
  Map<String, Object?> toJson();
}

/// One mission-start sequence, currently containing only a movement explanation.
/// All supported control variants and both languages are required, even disabled.
final class CampaignMovementTutorial extends CampaignTutorialSequence {
  CampaignMovementTutorial._({
    required super.id,
    required super.name,
    required super.enabled,
    required super.title,
    required super.reveals,
    required this.instructions,
    required this.spotlights,
  });

  factory CampaignMovementTutorial.decode(Object? value) {
    final json = _object(
      value,
      {
        'id',
        'name',
        'enabled',
        'trigger',
        'kind',
        'title',
        'instructions',
        'spotlights',
        'reveals',
      },
      optional: {'reveals'},
    );
    final id = json['id'];
    if (id is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
        json['trigger'] != 'missionStart' ||
        json['kind'] != 'movement' ||
        json['enabled'] is! bool) {
      throw const FormatException('Invalid mission-start movement tutorial.');
    }
    final instructions = _object(json['instructions'], {
      for (final control in TutorialMovementControl.values) control.name,
    });
    final spotlights = _object(json['spotlights'], {
      for (final control in TutorialMovementControl.values)
        if (control != TutorialMovementControl.keyboard) control.name,
    });
    return CampaignMovementTutorial._(
      id: id,
      name: _text(json['name'], 120),
      enabled: json['enabled'] as bool,
      reveals: decodeTutorialHud(
        json.containsKey('reveals') ? json['reveals'] : ['movement'],
      ),
      title: _translation(json['title'], 120),
      instructions: Map.unmodifiable({
        for (final control in TutorialMovementControl.values)
          control: _translation(instructions[control.name], 500),
      }),
      spotlights: Map.unmodifiable({
        for (final control in TutorialMovementControl.values)
          if (control != TutorialMovementControl.keyboard)
            control: TutorialSpotlight.decode(spotlights[control.name]),
      }),
    );
  }

  @override
  CampaignTutorialTrigger get trigger => CampaignTutorialTrigger.missionStart;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.movement;
  @override
  TutorialSpotlight? spotlightFor(
    TutorialMovementControl control, {
    int step = 0,
  }) => spotlights[control];
  final Map<TutorialMovementControl, Map<String, String>> instructions;
  final Map<TutorialMovementControl, TutorialSpotlight> spotlights;
  @override
  String instructionFor(
    TutorialMovementControl control,
    String language, {
    int step = 0,
  }) => instructions[control]![language] ?? instructions[control]!['en']!;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': 'missionStart',
    'kind': 'movement',
    if (reveals.length != 1 || !reveals.contains(TutorialHudElement.movement))
      'reveals': reveals.map((element) => element.name).toList(),
    'title': title,
    'instructions': {
      for (final entry in instructions.entries) entry.key.name: entry.value,
    },
    'spotlights': {
      for (final entry in spotlights.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  /// Editable authoring preset, copied into mission source when added.
  static CampaignMovementTutorial movementIntroduction() =>
      CampaignMovementTutorial.decode({
        'id': 'movement_introduction',
        'name': 'Movement introduction',
        'enabled': true,
        'trigger': 'missionStart',
        'kind': 'movement',
        'title': {'en': 'Moving around', 'fr': 'Se déplacer'},
        'instructions': {
          'arrows': {
            'en': 'Hold the left or right arrow to start moving.',
            'fr': 'Maintiens la flèche gauche ou droite pour commencer à te déplacer.',
          },
          'fixedJoystick': {
            'en': 'Touch the joystick, then drag left or right to move.',
            'fr': 'Touche le joystick, puis fais-le glisser à gauche ou à droite pour te déplacer.',
          },
          'floatingJoystick': {
            'en': 'Touch the lower-left area, then drag left or right to move.',
            'fr': 'Touche la zone en bas à gauche, puis fais glisser ton doigt à gauche ou à droite pour te déplacer.',
          },
          'keyboard': {
            'en': 'Hold the left or right arrow key to start moving.',
            'fr': 'Maintiens la touche flèche gauche ou droite pour commencer à te déplacer.',
          },
        },
        'spotlights': {
          'arrows': const TutorialSpotlight().toJson(),
          'fixedJoystick': const TutorialSpotlight(
            shape: TutorialSpotlightShape.ellipse,
            x: -0.15,
            y: -0.15,
            width: 1.3,
            height: 1.3,
          ).toJson(),
          'floatingJoystick': const TutorialSpotlight(
            x: 0,
            y: 0,
            width: 1,
            height: 1,
          ).toJson(),
        },
      });
}

/// Single-card lessons share a localized instruction and anchored spotlight.
/// Concrete lessons retain their own bounded triggers and reveal requirements.
sealed class CampaignPanelTutorial extends CampaignTutorialSequence {
  CampaignPanelTutorial._(Map<String, Object?> json)
    : instruction = _translation(json['instruction'], 500),
      spotlight = TutorialSpotlight.decode(json['spotlight']),
      super(
        id: json['id']! as String,
        name: _text(json['name'], 120),
        enabled: json['enabled']! as bool,
        title: _translation(json['title'], 120),
        reveals: decodeTutorialHud(json['reveals']),
      );
  final Map<String, String> instruction;
  final TutorialSpotlight spotlight;
  String get kind;
  @override
  String instructionFor(
    TutorialMovementControl control,
    String language, {
    int step = 0,
  }) => instruction[language] ?? instruction['en']!;
  @override
  TutorialSpotlight spotlightFor(
    TutorialMovementControl control, {
    int step = 0,
  }) => spotlight;
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'trigger': trigger.name,
    'kind': kind,
    'title': title,
    'instruction': instruction,
    'spotlight': spotlight.toJson(),
    'reveals': reveals.map((element) => element.name).toList(),
  };
}

final class CampaignObjectivesTutorial extends CampaignPanelTutorial {
  CampaignObjectivesTutorial._(super.json) : super._();
  factory CampaignObjectivesTutorial.decode(Object? value) =>
      CampaignObjectivesTutorial._(
        _decodePanel(
          value,
          'objectives',
          CampaignTutorialTrigger.movementStarted,
          TutorialHudElement.objectives,
        ),
      );
  @override
  String get kind => 'objectives';
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.movementStarted;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.objectives;
  static CampaignObjectivesTutorial introduction() =>
      CampaignObjectivesTutorial.decode({
        'id': 'objectives_introduction',
        'name': 'Objectives introduction',
        'enabled': true,
        'trigger': 'movementStarted',
        'kind': 'objectives',
        'title': {'en': 'Your first objective', 'fr': 'Ton premier objectif'},
        'instruction': {
          'en': 'Your objectives appear here. First, collect a coin. Release, then move again to continue towards it.',
          'fr': 'Tes objectifs apparaissent ici. Commence par ramasser une pièce. Relâche puis bouge à nouveau pour la rejoindre.',
        },
        'spotlight': const TutorialSpotlight().toJson(),
        'reveals': ['objectives'],
      });
}

final class CampaignCoinTutorial extends CampaignPanelTutorial {
  CampaignCoinTutorial._(super.json) : super._();
  factory CampaignCoinTutorial.decode(Object? value) => CampaignCoinTutorial._(
    _decodePanel(
      value,
      'firstCoin',
      CampaignTutorialTrigger.firstCoinCollected,
      TutorialHudElement.runStats,
    ),
  );
  @override
  String get kind => 'firstCoin';
  @override
  CampaignTutorialTrigger get trigger =>
      CampaignTutorialTrigger.firstCoinCollected;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.runStats;
  static CampaignCoinTutorial introduction() => CampaignCoinTutorial.decode({
    'id': 'first_coin',
    'name': 'First coin',
    'enabled': true,
    'trigger': 'firstCoinCollected',
    'kind': 'firstCoin',
    'title': {'en': 'Your first coin', 'fr': 'Ta première pièce'},
    'instruction': {
      'en': 'Release, then move again to continue. Each coin gives 1 gold. Collectibles counts coins; Distance shows your furthest progress.',
      'fr': 'Relâche puis bouge à nouveau pour continuer. Chaque pièce donne 1 or. Objets collectés compte les pièces ; Distance indique ta progression maximale.',
    },
    'spotlight': const TutorialSpotlight().toJson(),
    'reveals': ['runStats'],
  });
}

Map<String, Object?> _decodePanel(
  Object? value,
  String kind,
  CampaignTutorialTrigger trigger,
  TutorialHudElement? requiredReveal, {
  Set<String> extraFields = const {},
}) {
  final json = _object(value, {
    'id',
    'name',
    'enabled',
    'trigger',
    'kind',
    'title',
    'instruction',
    'spotlight',
    'reveals',
    ...extraFields,
  });
  final id = json['id'];
  if (id is! String ||
      !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(id) ||
      json['trigger'] != trigger.name ||
      json['kind'] != kind ||
      json['enabled'] is! bool) {
    throw FormatException('Invalid $kind tutorial.');
  }
  if (requiredReveal != null &&
      !decodeTutorialHud(json['reveals']).contains(requiredReveal)) {
    throw FormatException(
      'The $kind lesson must reveal ${requiredReveal.name}.',
    );
  }
  return json;
}

/// Missing fields mean the normal HUD. Explicit lists reject unknown/duplicate
/// features; the first bounded tutorial flow always retains movement access.
Set<TutorialHudElement> decodeTutorialHud(
  Object? value, {
  bool initial = false,
}) {
  if (value is! List) throw const FormatException('Expected HUD feature list.');
  final result = <TutorialHudElement>{};
  for (final name in value) {
    if (!result.add(_enumValue(TutorialHudElement.values, name))) {
      throw const FormatException('Duplicate HUD feature.');
    }
  }
  if (initial && !result.contains(TutorialHudElement.movement)) {
    throw const FormatException('Initial tutorial HUD must retain movement.');
  }
  return Set.unmodifiable(result);
}

CampaignTutorialSequence decodeCampaignTutorial(Object? value) {
  if (value is Map && value['kind'] == 'combat') {
    return CampaignCombatTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'mobility') {
    return CampaignMobilityTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'blessing') {
    return CampaignBlessingTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'platform') {
    return CampaignPlatformTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'gap') {
    return CampaignGapTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'decoration') {
    return CampaignDecorationTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'water') {
    return CampaignWaterTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'swimming') {
    return CampaignSwimmingTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'obstaclesAndJump') {
    return CampaignJumpTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'objectives') {
    return CampaignObjectivesTutorial.decode(value);
  }
  if (value is Map && value['kind'] == 'firstCoin') {
    return CampaignCoinTutorial.decode(value);
  }
  return CampaignMovementTutorial.decode(value);
}

/// Only the currently supported, ordered triggers are admitted. Each lesson
/// can occur once; disabled lessons are still validated and retain their IDs.
List<CampaignTutorialSequence> decodeCampaignTutorials(Object? value) {
  if (value is! List || value.length > CampaignTutorialTrigger.values.length) {
    throw const FormatException(
      'Expected up to twelve ordered tutorial sequences.',
    );
  }
  final result = value.map(decodeCampaignTutorial).toList();
  final ids = <String>{};
  var previous = -1;
  for (final lesson in result) {
    if (!ids.add(lesson.id) || lesson.trigger.index <= previous) {
      throw const FormatException(
        'Tutorial IDs/triggers must be unique and ordered.',
      );
    }
    previous = lesson.trigger.index;
  }
  return List.unmodifiable(result);
}

Map<String, Object?> _object(
  Object? value,
  Set<String> keys, {
  Set<String> optional = const {},
}) {
  if (value is! Map ||
      !value.keys.toSet().containsAll(keys.difference(optional)) ||
      value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Invalid tutorial fields.');
  }
  return Map<String, Object?>.from(value);
}

String _text(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw FormatException('Tutorial text must contain 1–$max characters.');
  }
  return value.trim();
}

Map<String, String> _translation(Object? value, int max) {
  final json = _object(value, {'en', 'fr'});
  return Map.unmodifiable({
    for (final entry in json.entries) entry.key: _text(entry.value, max),
  });
}

double _number(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max) {
    throw FormatException('Spotlight value must be between $min and $max.');
  }
  return value.toDouble();
}

T _enumValue<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Unknown tutorial value: $name.');
}
