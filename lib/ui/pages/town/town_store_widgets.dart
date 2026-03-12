import 'package:flutter/material.dart';

import '../../../core/accessories/accessory_id.dart';
import '../../../core/meta/gear_slot.dart';
import '../../../core/projectiles/projectile_id.dart';
import '../../../core/spellBook/spell_book_id.dart';
import '../../../core/weapons/weapon_id.dart';
import '../../components/app_button.dart';
import '../../components/gameIcon/game_icon.dart';
import '../../components/gold_display.dart';
import '../../state/progression_state.dart';
import '../../text/ability_text.dart';
import '../../text/gear_text.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_town_store_theme.dart';

/// Combined town store header and offers list in one card.
class TownStoreCard extends StatelessWidget {
  const TownStoreCard({
    super.key,
    required this.gold,
    required this.refreshesRemaining,
    required this.inFlight,
    required this.canRefresh,
    required this.onRefreshPressed,
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
  final List<StoreOfferState> activeOffers;
  final int currentGold;
  final bool purchaseInFlight;
  final bool refreshInFlight;
  final ValueChanged<StoreOfferState> onConfirmPurchase;

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
                      gold: gold,
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
                          'Store refreshes left: $refreshesRemaining',
                          style: ui.text.body.copyWith(
                            color: ui.colors.textMuted,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: ui.space.sm),
                      AppButton(
                        label: inFlight ? 'Refreshing...' : 'Refresh',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.xxs,
                        onPressed: canRefresh ? onRefreshPressed : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ui.space.md),
            if (activeOffers.isEmpty)
              Text(
                'No offers available right now.',
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              )
            else
              for (var index = 0; index < activeOffers.length; index++) ...[
                _TownOfferRow(
                  offer: activeOffers[index],
                  currentGold: currentGold,
                  purchaseInFlight: purchaseInFlight,
                  refreshInFlight: refreshInFlight,
                  onConfirmPurchase: onConfirmPurchase,
                ),
                if (index < activeOffers.length - 1)
                  SizedBox(height: ui.space.xs),
              ],
          ],
        ),
      ),
    );
  }
}

class _TownOfferRow extends StatelessWidget {
  const _TownOfferRow({
    required this.offer,
    required this.currentGold,
    required this.purchaseInFlight,
    required this.refreshInFlight,
    required this.onConfirmPurchase,
  });

  final StoreOfferState offer;
  final int currentGold;
  final bool purchaseInFlight;
  final bool refreshInFlight;
  final ValueChanged<StoreOfferState> onConfirmPurchase;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final storeTheme = context.townStore;
    final canAfford = currentGold >= offer.priceGold;
    final canBuy = canAfford && !purchaseInFlight && !refreshInFlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.colors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ui.radii.md),
        border: Border.all(
          color: ui.colors.outline.withValues(
            alpha: storeTheme.bucketIdleOutlineAlpha,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(ui.space.sm),
        child: Row(
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
            SizedBox(width: ui.space.sm),
            GoldDisplay(
              gold: offer.priceGold,
              variant: GoldDisplayVariant.headline,
            ),
            SizedBox(width: ui.space.sm),
            AppButton(
              label: purchaseInFlight ? 'Buying...' : 'Buy',
              variant: AppButtonVariant.primary,
              size: AppButtonSize.xxs,
              onPressed: canBuy ? () => onConfirmPurchase(offer) : null,
            ),
          ],
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
