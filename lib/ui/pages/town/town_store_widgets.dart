import 'package:flutter/material.dart';

import '../../../core/abilities/ability_catalog.dart';
import '../../../core/abilities/ability_def.dart';
import '../../../core/accessories/accessory_id.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/projectiles/projectile_catalog.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/spellBook/spell_book_id.dart';
import '../../../core/weapons/weapon_id.dart';
import '../../components/app_button.dart';
import '../../components/gameIcon/game_icon.dart';
import '../../components/gold_display.dart';
import '../../state/progression_state.dart';
import '../../text/ability_tooltip_builder.dart';
import '../../text/ability_tooltip_context_helper.dart';
import '../../text/ability_text.dart';
import '../../text/gear_text.dart';
import '../../text/semantic_text.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_town_store_theme.dart';
import '../selectCharacter/gear/gear_stats_presenter.dart';

/// Combined town store header and offers list in one card.
class TownStoreCard extends StatefulWidget {
  const TownStoreCard({
    super.key,
    required this.gold,
    required this.refreshesRemaining,
    required this.inFlight,
    required this.canRefresh,
    required this.onRefreshPressed,
    required this.selectedProjectileSourceSpellId,
    required this.activeOffers,
    required this.currentGold,
    required this.purchaseInFlight,
    required this.refreshInFlight,
    required this.onConfirmPurchase,
  });

  final int gold;
  final int refreshesRemaining;
  final bool inFlight;
  final bool canRefresh;
  final VoidCallback onRefreshPressed;
  final ProjectileId? selectedProjectileSourceSpellId;
  final List<StoreOfferState> activeOffers;
  final int currentGold;
  final bool purchaseInFlight;
  final bool refreshInFlight;
  final ValueChanged<StoreOfferState> onConfirmPurchase;

  @override
  State<TownStoreCard> createState() => _TownStoreCardState();
}

class _TownStoreCardState extends State<TownStoreCard> {
  String? _expandedOfferId;

  @override
  void didUpdateWidget(covariant TownStoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandedOfferId == null) {
      return;
    }
    final stillExists = widget.activeOffers.any(
      (offer) => offer.offerId == _expandedOfferId,
    );
    if (!stillExists) {
      _expandedOfferId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.cardBackground,
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(color: ui.colors.outline),
        boxShadow: ui.shadows.card,
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GoldDisplay(
                      gold: widget.gold,
                      label: 'Current Gold',
                      variant: GoldDisplayVariant.headline,
                    ),
                  ),
                ),
                SizedBox(width: ui.space.md),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          'Store refreshes left: ${widget.refreshesRemaining}',
                          style: ui.text.body.copyWith(
                            color: ui.colors.textMuted,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: ui.space.sm),
                      AppButton(
                        label: widget.inFlight ? 'Refreshing...' : 'Refresh',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.xxs,
                        onPressed: widget.canRefresh
                            ? widget.onRefreshPressed
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ui.space.md),
            if (widget.activeOffers.isEmpty)
              Text(
                'No offers available right now.',
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              )
            else
              for (var index = 0; index < widget.activeOffers.length; index++) ...[
                _TownOfferRow(
                  offer: widget.activeOffers[index],
                  expanded:
                      widget.activeOffers[index].offerId == _expandedOfferId,
                  currentGold: widget.currentGold,
                  purchaseInFlight: widget.purchaseInFlight,
                  refreshInFlight: widget.refreshInFlight,
                  selectedProjectileSourceSpellId:
                      widget.selectedProjectileSourceSpellId,
                  onToggleExpanded: () => setState(() {
                    final offerId = widget.activeOffers[index].offerId;
                    _expandedOfferId = _expandedOfferId == offerId
                        ? null
                        : offerId;
                  }),
                  onConfirmPurchase: widget.onConfirmPurchase,
                ),
                if (index < widget.activeOffers.length - 1)
                  SizedBox(height: ui.space.xs),
              ],
          ],
        ),
      ),
    );
  }
}

const ProjectileCatalog _projectileCatalog = ProjectileCatalog();
const DefaultAbilityTooltipBuilder _abilityTooltipBuilder =
    DefaultAbilityTooltipBuilder();

class _TownOfferRow extends StatelessWidget {
  const _TownOfferRow({
    required this.offer,
    required this.expanded,
    required this.currentGold,
    required this.purchaseInFlight,
    required this.refreshInFlight,
    required this.selectedProjectileSourceSpellId,
    required this.onToggleExpanded,
    required this.onConfirmPurchase,
  });

  final StoreOfferState offer;
  final bool expanded;
  final int currentGold;
  final bool purchaseInFlight;
  final bool refreshInFlight;
  final ProjectileId? selectedProjectileSourceSpellId;
  final VoidCallback onToggleExpanded;
  final ValueChanged<StoreOfferState> onConfirmPurchase;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final storeTheme = context.townStore;
    final canAfford = currentGold >= offer.priceGold;
    final canBuy = canAfford && !purchaseInFlight && !refreshInFlight;
    final borderColor = expanded
        ? ui.colors.accentStrong
        : ui.colors.outline.withValues(
            alpha: storeTheme.bucketIdleOutlineAlpha,
          );
    final fillColor = expanded
        ? UiBrandPalette.steelBlueInsetBottom
        : ui.colors.background.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleExpanded,
        borderRadius: BorderRadius.circular(ui.radii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(ui.radii.md),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(ui.space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _OfferIcon(offer: offer),
                    SizedBox(width: ui.space.sm),
                    Expanded(
                      child: Text(
                        townStoreOfferDisplayName(offer),
                        style: ui.text.body.copyWith(
                          color: ui.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: ui.space.xs),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: ui.colors.textMuted,
                      ),
                    ),
                    SizedBox(width: ui.space.xs),
                    GoldDisplay(
                      gold: offer.priceGold,
                      variant: GoldDisplayVariant.headline,
                    ),
                    SizedBox(width: ui.space.xs),
                    AppButton(
                      label: purchaseInFlight ? 'Buying...' : 'Buy',
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.xxs,
                      onPressed: canBuy ? () => onConfirmPurchase(offer) : null,
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: expanded
                      ? Padding(
                          key: ValueKey<String>('details-${offer.offerId}'),
                          padding: EdgeInsets.only(top: ui.space.xs),
                          child: _TownOfferDetails(
                            offer: offer,
                            selectedProjectileSourceSpellId:
                                selectedProjectileSourceSpellId,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey<String>('details-hidden')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TownOfferDetails extends StatelessWidget {
  const _TownOfferDetails({
    required this.offer,
    required this.selectedProjectileSourceSpellId,
  });

  final StoreOfferState offer;
  final ProjectileId? selectedProjectileSourceSpellId;

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
        StoreDomain.gear => _GearOfferDetails(offer: offer),
        StoreDomain.projectileSpell => _ProjectileOfferDetails(offer: offer),
        StoreDomain.ability => _AbilityOfferDetails(
          offer: offer,
          selectedProjectileSourceSpellId: selectedProjectileSourceSpellId,
        ),
      },
    );
  }
}

class _GearOfferDetails extends StatelessWidget {
  const _GearOfferDetails({required this.offer});

  final StoreOfferState offer;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final gearSlot = _gearSlotForStoreSlot(offer.slot);
    final typedId = _typedGearId(offer.slot, offer.itemId);
    if (gearSlot == null || typedId == null) {
      return Text(
        'No details available right now.',
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final statLines = gearStatsFor(gearSlot, typedId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gearDescriptionForSlot(gearSlot, typedId),
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
        SizedBox(height: ui.space.xs),
        if (statLines.isEmpty)
          Text(
            'No non-zero stat bonuses.',
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
    final projectileId = _enumByName(ProjectileId.values, offer.itemId);
    if (projectileId == null || projectileId == ProjectileId.unknown) {
      return Text(
        'No details available right now.',
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final projectileDef = _projectileCatalog.tryGet(projectileId);
    final statusLines = projectileDef == null
        ? const <String>[]
        : projectileStatusSummaries(projectileDef);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (projectileDef != null)
          _DetailsMetricLine(
            label: 'Damage: ',
            value: damageTypeDisplayName(projectileDef.damageType),
          ),
        if (projectileDef != null) SizedBox(height: ui.space.xxs),
        Text(
          projectileDescription(projectileId),
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
        'No details available right now.',
        style: ui.text.body.copyWith(color: ui.colors.textMuted),
      );
    }
    final tooltip = slot == null
        ? _abilityTooltipBuilder.build(def)
        : _abilityTooltipBuilder.build(
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
            label: 'Cooldown: ',
            value: '${_formatSeconds(tooltip.cooldownSeconds!)} seconds',
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
            label: 'Max duration: ',
            value: '${_formatSeconds(tooltip.maxDurationSeconds!)} seconds',
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
        Expanded(
          flex: 4,
          child: Text(line.label, style: labelStyle),
        ),
        SizedBox(width: ui.space.xs),
        Expanded(
          flex: 5,
          child: semanticValue == null
              ? Text(
                  line.value,
                  style: valueStyle,
                  textAlign: TextAlign.right,
                )
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
        Text(
          '• ',
          style: ui.text.body.copyWith(color: ui.colors.textMuted),
        ),
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
        final projectileId = _enumByName(ProjectileId.values, offer.itemId);
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

String _formatSeconds(double seconds) {
  return seconds.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

List<TextSpan> _highlightValues(
  String text, {
  required TextStyle normal,
  required TextStyle highlight,
}) {
  final regex = RegExp(r'[+-]?\d+(?:\.\d+)?%?');
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
String townStoreOfferDisplayName(StoreOfferState offer) {
  switch (offer.domain) {
    case StoreDomain.gear:
      final gearSlot = _gearSlotForStoreSlot(offer.slot);
      final typedId = _typedGearId(offer.slot, offer.itemId);
      if (gearSlot == null || typedId == null) {
        return offer.itemId;
      }
      return gearDisplayNameForSlot(gearSlot, typedId);
    case StoreDomain.projectileSpell:
      final projectileId = _enumByName(ProjectileId.values, offer.itemId);
      if (projectileId == null) {
        return offer.itemId;
      }
      return projectileDisplayName(projectileId);
    case StoreDomain.ability:
      return abilityDisplayName(offer.itemId);
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
