import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/abilities/forced_interrupt_policy.dart';

void main() {
  test('unknown ability falls back to default forced interruption causes', () {
    final causes = forcedInterruptCausesForAbility('test.unknown_ability');
    expect(causes.contains(ForcedInterruptCause.stun), isTrue);
    expect(causes.contains(ForcedInterruptCause.death), isTrue);
    expect(causes.contains(ForcedInterruptCause.damageTaken), isFalse);
  });

  test('charged shot opts into damage-taken forced interruption', () {
    expect(
      abilityAllowsForcedInterrupt(
        'eloise.charged_shot',
        ForcedInterruptCause.damageTaken,
      ),
      isTrue,
    );
  });

  test('quick shot keeps default forced interruption causes', () {
    expect(
      abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.damageTaken,
      ),
      isFalse,
    );
    expect(
      abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.stun,
      ),
      isTrue,
    );
    expect(
      abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.death,
      ),
      isTrue,
    );
  });
}
