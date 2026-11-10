import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:flutter/material.dart';

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_id.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_id.dart';

import '../../components/app_button.dart';

import 'package:game_presentation/game_icon.dart';

import '../../components/gold_display.dart';
import '../../state/ownership/progression_state.dart';
import '../../text/ability_tooltip_builder.dart';
import '../../text/ability_tooltip_context_helper.dart';

import 'package:game_presentation/ability_text.dart';
import 'package:game_presentation/gear_text.dart';

import '../../text/semantic_text.dart';
import '../../theme/ui_tokens.dart';
import '../selectCharacter/gear/gear_stats_presenter.dart';

import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/players/player_character_definition.dart';

/// Compact catalogue entry with expandable authoritative details and build comparison.
class TownOfferCard extends StatelessWidget {
  const TownOfferCard({
    super.key,
    required this.offer,
    required this.owned,
    required this.expanded,
    required this.currentGold,
    required this.purchaseInFlight,
    required this.selectedLoadout,
    required this.buildName,
    required this.characterId,
    required this.onToggleExpanded,
    required this.onConfirmPurchase,
  });
  final StoreOfferState offer;
  final bool owned, expanded, purchaseInFlight;
  final int currentGold;
  final EquippedLoadoutDef selectedLoadout;
  final String buildName;
  final PlayerCharacterId characterId;
  final VoidCallback onToggleExpanded;
  final ValueChanged<StoreOfferState> onConfirmPurchase;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final training = offer.domain == StoreDomain.ability;
    final name = townStoreOfferDisplayName(offer, strings: context.gameL10n);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(
          color: expanded ? ui.colors.accentStrong : ui.colors.outline,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                onTap: onToggleExpanded,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: ui.space.xs),
                  child: Row(
                    children: [
                      _OfferIcon(offer: offer),
                      SizedBox(width: ui.space.sm),
                      Expanded(
                        child: Text(
                          name,
                          style: ui.text.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: ui.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (offer.slot == StoreSlot.accessory)
              Padding(
                padding: EdgeInsets.only(bottom: ui.space.xs),
                child: Text(
                  context.l10n.townSharedAccessory,
                  style: ui.text.body.copyWith(color: ui.colors.textMuted),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: ui.space.sm,
              runSpacing: ui.space.xs,
              children: [
                if (owned)
                  Text(
                    training
                        ? context.l10n.townLearned
                        : context.l10n.townOwned,
                    style: ui.text.body.copyWith(color: ui.colors.success),
                  )
                else ...[
                  GoldDisplay(
                    gold: offer.priceGold,
                    variant: GoldDisplayVariant.headline,
                  ),
                  AppButton(
                    key: ValueKey('buy-${offer.offerId}'),
                    label: purchaseInFlight
                        ? context.l10n.uiBuying
                        : (training
                              ? context.l10n.townLearn
                              : context.l10n.uiBuy),
                    size: AppButtonSize.xxs,
                    onPressed:
                        currentGold >= offer.priceGold && !purchaseInFlight
                        ? () => onConfirmPurchase(offer)
                        : null,
                  ),
                ],
              ],
            ),
            if (expanded)
              Padding(
                padding: EdgeInsets.only(top: ui.space.sm),
                child: _TownOfferDetails(
                  offer: offer,
                  selectedProjectileSourceSpellId:
                      selectedLoadout.projectileSlotSpellId,
                  selectedLoadout: selectedLoadout,
                  buildName: buildName,
                  characterId: characterId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const ProjectileCatalog _projectileCatalog = ProjectileCatalog();

class _TownOfferDetails extends StatelessWidget {
  const _TownOfferDetails({
    required this.offer,
    required this.selectedProjectileSourceSpellId,
    required this.selectedLoadout,
    required this.buildName,
    required this.characterId,
  });

  final StoreOfferState offer;
  final ProjectileId? selectedProjectileSourceSpellId;
  final EquippedLoadoutDef selectedLoadout;
  final String buildName;
  final PlayerCharacterId characterId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ui.space.sm),
      decoration: BoxDecoration(
        color: ui.colors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.3)),
      ),
      child: switch (offer.domain) {
        StoreDomain.gear => _GearOfferDetails(
          offer: offer,
          selectedLoadout: selectedLoadout,
          buildName: buildName,
          manaPresentation: characterId == PlayerCharacterId.bountyHunter
              ? ManaPresentation.supplies
              : ManaPresentation.mana,
        ),
        StoreDomain.projectileSpell => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProjectileOfferDetails(offer: offer),
            SizedBox(height: ui.space.sm),
            Text(
              context.l10n.townCompareWith(
                item: projectileDisplayName(
                  selectedLoadout.projectileSlotSpellId,
                  strings: context.gameL10n,
                ),
                build: buildName,
              ),
              style: ui.text.body,
            ),
            _ProjectileOfferDetails(
              offer: offer.copyWith(
                itemId: selectedLoadout.projectileSlotSpellId.name,
              ),
            ),
          ],
        ),
        StoreDomain.ability => _AbilityOfferDetails(
          offer: offer,
          selectedProjectileSourceSpellId: selectedProjectileSourceSpellId,
        ),
      },
    );
  }
}

class _GearOfferDetails extends StatelessWidget {
  const _GearOfferDetails({
    required this.offer,
    required this.manaPresentation,
    required this.selectedLoadout,
    required this.buildName,
  });

  final ManaPresentation manaPresentation;
  final EquippedLoadoutDef selectedLoadout;
  final String buildName;

  final StoreOfferState offer;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final gearSlot = _gearSlotForStoreSlot(offer.slot);
    final typedId = _typedGearId(offer.slot, offer.itemId);
    if (gearSlot == null || typedId == null) {
      return Text(
        context.l10n.uiNoDetailsAvailableRightNow,
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final statLines = gearStatsFor(
      gearSlot,
      typedId,
      manaPresentation: manaPresentation,
      strings: context.gameL10n,
      l10n: context.l10n,
    );
    final equipped = switch (gearSlot) {
      GearSlot.mainWeapon => selectedLoadout.mainWeaponId,
      GearSlot.offhandWeapon => selectedLoadout.offhandWeaponId,
      GearSlot.spellBook => selectedLoadout.spellBookId,
      GearSlot.accessory => selectedLoadout.accessoryId,
    };
    final comparisons = gearCompareStats(
      gearSlot,
      equipped: equipped,
      candidate: typedId,
      manaPresentation: manaPresentation,
      strings: context.gameL10n,
      l10n: context.l10n,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.townCompareWith(
            item: gearDisplayNameForSlot(
              gearSlot,
              equipped,
              strings: context.gameL10n,
            ),
            build: buildName,
          ),
          style: ui.text.body,
        ),
        SizedBox(height: ui.space.xs),
        if (comparisons.isEmpty)
          Text(
            gearCompareEmptyText(
              selectedId: typedId,
              equippedForCompare: equipped,
              l10n: context.l10n,
            ),
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          )
        else
          for (final line in comparisons) _GearStatLineRow(line: line),
        SizedBox(height: ui.space.sm),
        Text(
          gearDescriptionForSlot(
            gearSlot,
            typedId,
            manaPresentation: manaPresentation,
            strings: context.gameL10n,
          ),
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
        SizedBox(height: ui.space.xs),
        if (statLines.isEmpty)
          Text(
            context.l10n.uiNoNonZeroStatBonuses,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          )
        else
          for (var index = 0; index < statLines.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 4),
              child: _GearStatLineRow(line: statLines[index]),
            ),
      ],
    );
  }
}

class _ProjectileOfferDetails extends StatelessWidget {
  const _ProjectileOfferDetails({required this.offer});

  final StoreOfferState offer;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final projectileId = _enumByName(
      playerEquippableProjectileIds,
      offer.itemId,
    );
    if (projectileId == null || projectileId == ProjectileId.unknown) {
      return Text(
        context.l10n.uiNoDetailsAvailableRightNow,
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final projectileDef = _projectileCatalog.tryGet(projectileId);
    final statusLines = projectileDef == null
        ? const <String>[]
        : projectileStatusSummaries(projectileDef, strings: context.gameL10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (projectileDef != null)
          _DetailsMetricLine(
            label: context.l10n.uiDamage,
            value: damageTypeDisplayName(
              projectileDef.damageType,
              strings: context.gameL10n,
            ),
          ),
        if (projectileDef != null) SizedBox(height: ui.space.xxs),
        Text(
          projectileDescription(projectileId, strings: context.gameL10n),
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
        if (statusLines.isNotEmpty) ...[
          SizedBox(height: ui.space.xs),
          for (var index = 0; index < statusLines.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 2),
              child: _BulletDetailLine(text: statusLines[index]),
            ),
        ],
      ],
    );
  }
}

class _AbilityOfferDetails extends StatelessWidget {
  const _AbilityOfferDetails({
    required this.offer,
    required this.selectedProjectileSourceSpellId,
  });

  final StoreOfferState offer;
  final ProjectileId? selectedProjectileSourceSpellId;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final def = AbilityCatalog.abilities[offer.itemId];
    final slot = _abilitySlotForStoreSlot(offer.slot);
    if (def == null) {
      return Text(
        context.l10n.uiNoDetailsAvailableRightNow,
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final tooltip = slot == null
        ? DefaultAbilityTooltipBuilder.localized(context).build(def)
        : DefaultAbilityTooltipBuilder.localized(context).build(
            def,
            ctx: AbilityTooltipContext(
              activeProjectileId: slot == AbilitySlot.projectile
                  ? selectedProjectileSourceSpellId
                  : null,
              payloadWeaponType: payloadWeaponTypeForTooltip(
                def: def,
                slot: slot,
                selectedSourceSpellId: selectedProjectileSourceSpellId,
              ),
            ),
          );
    final hasMetrics =
        tooltip.cooldownSeconds != null ||
        tooltip.costLines.isNotEmpty ||
        tooltip.maxDurationSeconds != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tooltip.cooldownSeconds != null)
          _DetailsMetricLine(
            label: context.l10n.uiCooldown,
            value: context.gameL10n.durationSeconds(
              seconds: (tooltip.cooldownSeconds! * 10).round() / 10,
            ),
          ),
        for (var index = 0; index < tooltip.costLines.length; index++) ...[
          if (tooltip.cooldownSeconds != null || index > 0)
            SizedBox(height: ui.space.xxs),
          _DetailsMetricLine(
            label: tooltip.costLines[index].label,
            value: tooltip.costLines[index].value,
          ),
        ],
        if (tooltip.maxDurationSeconds != null) ...[
          if (tooltip.cooldownSeconds != null || tooltip.costLines.isNotEmpty)
            SizedBox(height: ui.space.xxs),
          _DetailsMetricLine(
            label: context.l10n.uiMaxDuration,
            value: context.gameL10n.durationSeconds(
              seconds: (tooltip.maxDurationSeconds! * 10).round() / 10,
            ),
          ),
        ],
        if (hasMetrics) SizedBox(height: ui.space.xxs),
        UiSemanticRichText(
          semanticText: tooltip.semanticDescription,
          normalStyleForTone: (tone) => ui.text.body.copyWith(
            color: switch (tone) {
              UiSemanticTone.positive => ui.colors.success,
              UiSemanticTone.negative => ui.colors.danger,
              _ => ui.colors.textMuted,
            },
          ),
          highlightStyleForTone: (tone) => ui.text.body.copyWith(
            color: switch (tone) {
              UiSemanticTone.positive => ui.colors.success,
              UiSemanticTone.negative => ui.colors.danger,
              _ => ui.colors.valueHighlight,
            },
            fontWeight: FontWeight.w600,
          ),
        ),
        if (tooltip.badges.isNotEmpty) ...[
          SizedBox(height: ui.space.xs),
          Wrap(
            spacing: ui.space.xs,
            runSpacing: ui.space.xs,
            children: [
              for (final badge in tooltip.badges) _AbilityBadge(text: badge),
            ],
          ),
        ],
      ],
    );
  }
}

class _GearStatLineRow extends StatelessWidget {
  const _GearStatLineRow({required this.line});

  final GearStatLine line;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final valueColor = switch (line.tone) {
      GearStatLineTone.neutral => ui.colors.textPrimary,
      GearStatLineTone.positive => ui.colors.success,
      GearStatLineTone.negative => ui.colors.danger,
      GearStatLineTone.accent => ui.colors.valueHighlight,
    };
    final labelStyle = ui.text.body.copyWith(color: ui.colors.textMuted);
    final valueStyle = ui.text.body.copyWith(
      color: valueColor,
      fontWeight: FontWeight.w600,
    );
    final semanticValue =
        line.semanticValue ??
        (line.highlights.isEmpty
            ? null
            : UiSemanticText.single(line.value, highlights: line.highlights));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: Text(line.label, style: labelStyle)),
        SizedBox(width: ui.space.xs),
        Expanded(
          flex: 5,
          child: semanticValue == null
              ? Text(line.value, style: valueStyle, textAlign: TextAlign.right)
              : UiSemanticRichText(
                  semanticText: semanticValue,
                  normalStyleForTone: (_) => valueStyle,
                  highlightStyleForTone: (tone) => ui.text.body.copyWith(
                    color: _semanticToneColor(ui, tone),
                    fontWeight: FontWeight.w600,
                  ),
                  mapHighlightTone: line.forcePositiveHighlightTones
                      ? (_) => UiSemanticTone.positive
                      : null,
                  textAlign: TextAlign.right,
                ),
        ),
      ],
    );
  }
}

class _BulletDetailLine extends StatelessWidget {
  const _BulletDetailLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: ui.text.body.copyWith(color: ui.colors.textMuted)),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: _highlightValues(
                text,
                normal: ui.text.body.copyWith(color: ui.colors.textPrimary),
                highlight: ui.text.body.copyWith(
                  color: ui.colors.valueHighlight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsMetricLine extends StatelessWidget {
  const _DetailsMetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Text.rich(
      TextSpan(
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
        children: [
          TextSpan(text: label),
          TextSpan(
            text: value,
            style: ui.text.body.copyWith(
              color: ui.colors.valueHighlight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityBadge extends StatelessWidget {
  const _AbilityBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.xs,
        vertical: ui.space.xxs,
      ),
      decoration: BoxDecoration(
        color: UiBrandPalette.steelBlueInsetBottom,
        borderRadius: BorderRadius.circular(ui.radii.sm),
        border: Border.all(color: ui.colors.outline.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: ui.text.body.copyWith(
          color: ui.colors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OfferIcon extends StatelessWidget {
  const _OfferIcon({required this.offer});

  final StoreOfferState offer;

  @override
  Widget build(BuildContext context) {
    final iconSize = context.ui.sizes.iconSize.lg;
    switch (offer.domain) {
      case StoreDomain.gear:
        final gearSlot = _gearSlotForStoreSlot(offer.slot);
        if (gearSlot == null) {
          break;
        }
        final typedId = _typedGearId(offer.slot, offer.itemId);
        if (typedId == null) {
          break;
        }
        return GameIcon.gear(slot: gearSlot, id: typedId, size: iconSize);
      case StoreDomain.projectileSpell:
        final projectileId = _enumByName(
          playerEquippableProjectileIds,
          offer.itemId,
        );
        if (projectileId == null || projectileId == ProjectileId.unknown) {
          break;
        }
        return GameIcon.projectile(projectileId: projectileId, size: iconSize);
      case StoreDomain.ability:
        return GameIcon.ability(abilityId: offer.itemId, size: iconSize);
    }

    return SizedBox.square(dimension: iconSize);
  }
}

Color _semanticToneColor(UiTokens ui, UiSemanticTone tone) {
  return switch (tone) {
    UiSemanticTone.positive => ui.colors.success,
    UiSemanticTone.negative => ui.colors.danger,
    UiSemanticTone.accent => ui.colors.valueHighlight,
    UiSemanticTone.neutral => ui.colors.textPrimary,
  };
}

List<TextSpan> _highlightValues(
  String text, {
  required TextStyle normal,
  required TextStyle highlight,
}) {
  final regex = RegExp(
    r'[+-]?\d+(?:[.,\u00a0\u202f]\d+)*(?:[ \u00a0\u202f]?%)?',
  );
  final spans = <TextSpan>[];
  var index = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > index) {
      spans.add(
        TextSpan(text: text.substring(index, match.start), style: normal),
      );
    }
    spans.add(TextSpan(text: match.group(0), style: highlight));
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: normal));
  }
  return spans;
}

/// Human-readable offer label resolved from the typed domain payload.
String townStoreOfferDisplayName(
  StoreOfferState offer, {
  required GameLocalizations strings,
}) {
  switch (offer.domain) {
    case StoreDomain.gear:
      final gearSlot = _gearSlotForStoreSlot(offer.slot);
      final typedId = _typedGearId(offer.slot, offer.itemId);
      if (gearSlot == null || typedId == null) {
        return strings.unknownItem;
      }
      return gearDisplayNameForSlot(gearSlot, typedId, strings: strings);
    case StoreDomain.projectileSpell:
      final projectileId = _enumByName(
        playerEquippableProjectileIds,
        offer.itemId,
      );
      if (projectileId == null) {
        return strings.unknownItem;
      }
      return projectileDisplayName(projectileId, strings: strings);
    case StoreDomain.ability:
      return abilityDisplayName(offer.itemId, strings: strings);
  }
}

GearSlot? _gearSlotForStoreSlot(StoreSlot slot) {
  return switch (slot) {
    StoreSlot.mainWeapon => GearSlot.mainWeapon,
    StoreSlot.offhandWeapon => GearSlot.offhandWeapon,
    StoreSlot.spellBook => GearSlot.spellBook,
    StoreSlot.accessory => GearSlot.accessory,
    _ => null,
  };
}

AbilitySlot? _abilitySlotForStoreSlot(StoreSlot slot) {
  return switch (slot) {
    StoreSlot.primary => AbilitySlot.primary,
    StoreSlot.secondary => AbilitySlot.secondary,
    StoreSlot.projectile => AbilitySlot.projectile,
    StoreSlot.mobility => AbilitySlot.mobility,
    StoreSlot.jump => AbilitySlot.jump,
    StoreSlot.spell => AbilitySlot.spell,
    _ => null,
  };
}

Object? _typedGearId(StoreSlot slot, String itemId) {
  return switch (slot) {
    StoreSlot.mainWeapon ||
    StoreSlot.offhandWeapon => _enumByName(WeaponId.values, itemId),
    StoreSlot.spellBook => _enumByName(SpellBookId.values, itemId),
    StoreSlot.accessory => _enumByName(AccessoryId.values, itemId),
    _ => null,
  };
}

T? _enumByName<T extends Enum>(List<T> values, String name) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}
