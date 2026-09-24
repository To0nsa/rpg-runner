import 'dart:io';

import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_limits.dart';

/// Executed as a compiled program to verify guards do not depend on assertions.
void main() {
  var rejected = 0;
  for (final operation in <void Function()>[
    () => EncounterLimits.validatePoints(-1),
    () => EncounterLimits.validatePoints(EncounterLimits.maxPointsPerNpc + 1),
    () => EncounterLimits.addAward(
      EncounterLimits.maxExactScore,
      survivors: 1,
      points: 1,
    ),
    () => EncounterTrigger(x: 0, y: 0, width: double.infinity, height: 1),
    () => EncounterDefinition(
      id: 'draft',
      name: 'Draft',
      trigger: EncounterTrigger(x: 0, y: 0, width: 1, height: 1),
    ).validateForChunk(600),
  ]) {
    try {
      operation();
    } on ArgumentError {
      rejected++;
    } on StateError {
      rejected++;
    }
  }
  if (rejected != 5) {
    throw StateError('Only $rejected of 5 invalid contracts rejected.');
  }
  stdout.writeln('Encounter contract guards passed without assertions.');
}
