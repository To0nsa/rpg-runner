part of '../campaign_tutorial.dart';

/// Immutable bilingual page shared by the bounded jump and blessing sequences.
final class CampaignTutorialStep {
  CampaignTutorialStep.decode(Object? value, this.target) {
    final json = _object(value, {
      'target',
      'title',
      'instruction',
      'spotlight',
      'reveals',
    });
    if (json['target'] != target.name) {
      throw const FormatException(
        'Tutorial pages must retain their declared target order.',
      );
    }
    title = _translation(json['title'], 120);
    instruction = _translation(json['instruction'], 500);
    spotlight = TutorialSpotlight.decode(json['spotlight']);
    reveals = decodeTutorialHud(json['reveals']);
    final required = switch (target) {
      CampaignTutorialTarget.jump => TutorialHudElement.jump,
      CampaignTutorialTarget.projectile => TutorialHudElement.projectile,
      CampaignTutorialTarget.primary => TutorialHudElement.primary,
      CampaignTutorialTarget.resources ||
      CampaignTutorialTarget.blessingResources => TutorialHudElement.resources,
      _ => null,
    };
    if (required != null && !reveals.contains(required)) {
      throw FormatException(
        'The ${target.name} step must reveal ${required.name}.',
      );
    }
  }

  final CampaignTutorialTarget target;
  late final Map<String, String> title, instruction;
  late final TutorialSpotlight spotlight;
  late final Set<TutorialHudElement> reveals;
  Map<String, Object?> toJson() => {
    'target': target.name,
    'title': title,
    'instruction': instruction,
    'spotlight': spotlight.toJson(),
    'reveals': reveals.map((element) => element.name).toList(),
  };
}

/// Shared page projection; concrete sequences own triggers and continuations.
sealed class CampaignSteppedTutorial extends CampaignTutorialSequence {
  CampaignSteppedTutorial({
    required super.id,
    required super.name,
    required super.enabled,
    required this.steps,
  }) : super(title: steps.first.title, reveals: steps.first.reveals);
  final List<CampaignTutorialStep> steps;
  @override
  CampaignTutorialTarget get target => steps.first.target;
  @override
  int get stepCount => steps.length;
  @override
  CampaignTutorialTarget targetAt(int step) => steps[step].target;
  @override
  Set<TutorialHudElement> revealsAt(int step) => steps[step].reveals;
  @override
  String titleFor(String language, {int step = 0}) =>
      steps[step].title[language] ?? steps[step].title['en']!;
  @override
  String instructionFor(
    TutorialMovementControl control,
    String language, {
    int step = 0,
  }) => steps[step].instruction[language] ?? steps[step].instruction['en']!;
  @override
  TutorialSpotlight spotlightFor(
    TutorialMovementControl control, {
    int step = 0,
  }) => steps[step].spotlight;
}
