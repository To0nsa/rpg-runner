import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/abilities/forced_interrupt_policy.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';

void main() {
  test('unknown ability falls back to default forced interruption causes', () {
    final causes = ForcedInterruptPolicy.defaultPolicy
        .forcedInterruptCausesForAbility('test.unknown_ability');
    expect(causes.contains(ForcedInterruptCause.stun), isTrue);
    expect(causes.contains(ForcedInterruptCause.death), isTrue);
    expect(causes.contains(ForcedInterruptCause.damageTaken), isFalse);
  });

  test('charged shot opts into damage-taken forced interruption', () {
    expect(
      ForcedInterruptPolicy.defaultPolicy.abilityAllowsForcedInterrupt(
        'eloise.charged_shot',
        ForcedInterruptCause.damageTaken,
      ),
      isTrue,
    );
  });

  test('quick shot keeps default forced interruption causes', () {
    expect(
      ForcedInterruptPolicy.defaultPolicy.abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.damageTaken,
      ),
      isFalse,
    );
    expect(
      ForcedInterruptPolicy.defaultPolicy.abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.stun,
      ),
      isTrue,
    );
    expect(
      ForcedInterruptPolicy.defaultPolicy.abilityAllowsForcedInterrupt(
        'eloise.quick_shot',
        ForcedInterruptCause.death,
      ),
      isTrue,
    );
  });

  test('policy uses injected catalog resolver', () {
    const policy = ForcedInterruptPolicy(abilities: _InjectedAbilityCatalog());

    expect(
      policy.abilityAllowsForcedInterrupt(
        'test.injected_interrupt',
        ForcedInterruptCause.damageTaken,
      ),
      isTrue,
    );
  });
}

class _InjectedAbilityCatalog extends AbilityCatalog {
  const _InjectedAbilityCatalog();

  @override
  AbilityDef? resolve(AbilityKey key) {
    if (key != 'test.injected_interrupt') {
      return super.resolve(key);
    }
    return const AbilityDef(
      id: 'test.injected_interrupt',
      category: AbilityCategory.utility,
      allowedSlots: <AbilitySlot>{AbilitySlot.spell},
      targetingModel: TargetingModel.none,
      inputLifecycle: AbilityInputLifecycle.tap,
      hitDelivery: SelfHitDelivery(),
      windupTicks: 0,
      activeTicks: 0,
      recoveryTicks: 1,
      staminaCost: 0,
      manaCost: 0,
      cooldownTicks: 0,
      forcedInterruptCauses: <ForcedInterruptCause>{
        ForcedInterruptCause.stun,
        ForcedInterruptCause.death,
        ForcedInterruptCause.damageTaken,
      },
      animKey: AnimKey.idle,
      baseDamage: 0,
    );
  }
}
