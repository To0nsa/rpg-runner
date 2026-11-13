import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

/// Common feature selection for initial visibility and persistent lesson reveals.
class CampaignTutorialHudPicker extends StatelessWidget {
  const CampaignTutorialHudPicker({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.requiredElements = const {},
  });
  final String title;
  final Set<TutorialHudElement> value, requiredElements;
  final ValueChanged<Set<TutorialHudElement>> onChanged;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(title),
    subtitle: Text(value.map(_label).join(', ')),
    children: [
      for (final element in TutorialHudElement.values)
        CheckboxListTile(
          dense: true,
          title: Text(_label(element)),
          value: value.contains(element),
          onChanged: requiredElements.contains(element)
              ? null
              : (checked) {
                  final next = {...value};
                  if (checked == true) {
                    next.add(element);
                  } else {
                    next.remove(element);
                  }
                  onChanged(next);
                },
        ),
    ],
  );
}

String _label(TutorialHudElement element) => switch (element) {
  TutorialHudElement.movement => 'Movement controls',
  TutorialHudElement.resources => 'Health / mana / stamina',
  TutorialHudElement.objectives => 'Objectives and indicators',
  TutorialHudElement.runStats => 'Distance and Collectibles',
  TutorialHudElement.jump => 'Jump',
  TutorialHudElement.primary => 'Primary attack',
  TutorialHudElement.secondary => 'Secondary / shield',
  TutorialHudElement.projectile => 'Ranged attack',
  TutorialHudElement.spell => 'Spell',
  TutorialHudElement.mobility => 'Mobility',
  TutorialHudElement.blessings => 'Blessing indicator',
};
