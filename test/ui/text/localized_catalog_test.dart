import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_presentation/ability_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:game_presentation/gear_text.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/pages/selectCharacter/gear/gear_stats_presenter.dart';
import 'package:rpg_runner/ui/text/ability_tooltip_builder.dart';

void main() {
  test(
    'every catalog ability has a name and resolved tooltip in both languages',
    () {
      for (final locale in RunnerLocalizations.supportedLocales) {
        final strings = gameStringsFor(locale);
        final builder = DefaultAbilityTooltipBuilder.forLocale(locale);
        for (final ability in AbilityCatalog.abilities.values) {
          expect(
            abilityDisplayName(ability.id, strings: strings),
            isNot(strings.unknownAbility),
            reason: ability.id,
          );
          final tooltip = builder.build(ability);
          expect(tooltip.description, isNotEmpty, reason: ability.id);
          expect(tooltip.description, isNot(contains('{')), reason: ability.id);
          for (final token in tooltip.dynamicDescriptionValues) {
            expect(
              tooltip.description,
              contains(token),
              reason: '${locale.toLanguageTag()} ${ability.id}',
            );
          }
        }
      }
    },
  );

  test('French descriptions format values and preserve resource and highlight semantics', () {
    const locale = Locale('fr');
    final strings = gameStringsFor(locale);
    final l10n = appStringsFor(locale);
    expect(formatFixed100(125, strings: strings), '1,25');
    final builder = DefaultAbilityTooltipBuilder.forLocale(locale);
    final shot = builder.build(
      const AbilityCatalog().resolve('bounty_hunter.double_dash')!,
    );
    expect(shot.description, contains('0,5'));
    expect(shot.description, contains('Tu peux'));
    final supplies = gearStatsFor(
      GearSlot.accessory,
      AccessoryId.diamondRing,
      strings: strings,
      l10n: l10n,
      manaPresentation: ManaPresentation.supplies,
    );
    final mana = gearStatsFor(
      GearSlot.accessory,
      AccessoryId.diamondRing,
      strings: strings,
      l10n: l10n,
    );
    expect(
      supplies.map((line) => '${line.label} ${line.value}').join(),
      contains('Provisions'),
    );
    expect(
      mana.map((line) => '${line.label} ${line.value}').join(),
      contains('Mana'),
    );
    for (final line in supplies) {
      for (final token in line.highlights) {
        expect(line.value, contains(token.token));
      }
    }
    expect(
      projectileDescription(ProjectileId.holyBolt, strings: strings),
      isNotEmpty,
    );
  });
}
