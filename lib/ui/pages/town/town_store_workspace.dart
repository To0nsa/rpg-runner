import 'package:flutter/material.dart';
import 'package:game_presentation/game_icon.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/meta/gear_slot.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../../components/app_button.dart';
import '../../components/item_picker_tile.dart';
import '../../l10n/app_localization.dart';
import '../../state/ownership/progression_state.dart';
import '../../theme/ui_tokens.dart';
import 'town_catalog.dart';
import 'town_store_widgets.dart';

/// Presents a route-local selection beside the catalogue. Only [onPurchase]
/// requests an unlock; selecting items or categories never equips anything.
/// Training uses a null [slot] for All categories and keeps learned offers
/// inspectable; [ownedOfferIds] replaces their purchase action with a status.
class TownStoreWorkspace extends StatelessWidget {
  const TownStoreWorkspace({
    super.key,
    required this.service,
    required this.characterId,
    required this.slot,
    required this.offers,
    required this.selectedOffer,
    required this.selectedLoadout,
    required this.emptyText,
    required this.currentGold,
    required this.purchaseInFlight,
    required this.onSelectSlot,
    required this.onSelectOffer,
    required this.onPurchase,
    required this.ownedOfferIds,
  });

  final TownService service;
  final PlayerCharacterId characterId;
  final StoreSlot? slot;
  final List<StoreOfferState> offers;
  final StoreOfferState? selectedOffer;
  final EquippedLoadoutDef selectedLoadout;
  final String emptyText;
  final int currentGold;
  final bool purchaseInFlight;
  final ValueChanged<StoreSlot?> onSelectSlot;
  final ValueChanged<StoreOfferState> onSelectOffer;
  final ValueChanged<StoreOfferState> onPurchase;
  final Set<String> ownedOfferIds;

  bool get _training => service == TownService.training;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final panelDecoration = BoxDecoration(
      color: Color.alphaBlend(ui.colors.cardBackground, ui.colors.background),
      borderRadius: BorderRadius.circular(ui.radii.md),
      border: Border.all(color: ui.colors.outline.withValues(alpha: 0.4)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        // A short landscape viewport keeps buying visible while each pane
        // scrolls independently. Large text gets one readable document instead.
        final split =
            constraints.maxWidth / textScale >= 620 &&
            constraints.maxHeight >= 220;
        if (!split) {
          return SingleChildScrollView(
            key: ValueKey('${service.name}-stacked'),
            child: DecoratedBox(
              decoration: panelDecoration,
              child: Padding(
                padding: EdgeInsets.all(ui.space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: ui.space.xs,
                      runSpacing: ui.space.xs,
                      children: _categories(context),
                    ),
                    SizedBox(height: ui.space.sm),
                    _catalogueHeader(context),
                    _grid(context, shrinkWrap: true),
                    if (selectedOffer != null) ...[
                      SizedBox(height: ui.space.md),
                      _details(context),
                      _purchase(context),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Row(
          key: ValueKey('${service.name}-split'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: ui.sizes.tapTarget,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final category in _categories(context))
                      Padding(
                        padding: EdgeInsets.only(bottom: ui.space.xs),
                        child: category,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: ui.space.sm),
            Expanded(
              child: DecoratedBox(
                decoration: panelDecoration,
                child: Padding(
                  padding: EdgeInsets.all(ui.space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                key: ValueKey(
                                  '${service.name}-details-${selectedOffer?.offerId}',
                                ),
                                child: selectedOffer == null
                                    ? const SizedBox.shrink()
                                    : _details(context),
                              ),
                            ),
                            if (selectedOffer != null) _purchase(context),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: ui.space.lg,
                        thickness: 1,
                        color: ui.colors.outline.withValues(alpha: 0.35),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _catalogueHeader(context),
                            Expanded(child: _grid(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _categories(BuildContext context) => [
    for (final category in <StoreSlot?>[if (_training) null, ...service.slots])
      SizedBox.square(
        dimension: context.ui.sizes.tapTarget,
        child: ItemPickerTile(
          key: ValueKey('catalogue-slot-${category?.name ?? 'all'}'),
          label: _categoryLabel(context, category),
          icon: _categoryIcon(context, category),
          selected: slot == category,
          onTap: purchaseInFlight ? null : () => onSelectSlot(category),
        ),
      ),
  ];

  String _categoryLabel(BuildContext context, StoreSlot? category) =>
      category == null
      ? context.l10n.townAllCategories
      : context.l10n.townCategory(
          character: characterId.name,
          service: service.name,
          slot: category.name,
        );

  Widget _categoryIcon(BuildContext context, StoreSlot? category) {
    if (category == null) return const Icon(Icons.apps);
    if (_training) {
      return GameIcon.ability(
        size: context.ui.sizes.iconSize.lg,
        abilityId: switch (category) {
          StoreSlot.primary => selectedLoadout.abilityPrimaryId,
          StoreSlot.secondary => selectedLoadout.abilitySecondaryId,
          StoreSlot.projectile => selectedLoadout.abilityProjectileId,
          StoreSlot.mobility => selectedLoadout.abilityMobilityId,
          StoreSlot.jump => selectedLoadout.abilityJumpId,
          _ => selectedLoadout.abilitySpellId,
        },
      );
    }
    return switch (category) {
      StoreSlot.mainWeapon => GameIcon.gear(
        slot: GearSlot.mainWeapon,
        id: selectedLoadout.mainWeaponId,
      ),
      StoreSlot.offhandWeapon => GameIcon.gear(
        slot: GearSlot.offhandWeapon,
        id: selectedLoadout.offhandWeaponId,
      ),
      StoreSlot.spellBook => GameIcon.gear(
        slot: GearSlot.spellBook,
        id: selectedLoadout.spellBookId,
      ),
      StoreSlot.accessory => GameIcon.gear(
        slot: GearSlot.accessory,
        id: selectedLoadout.accessoryId,
      ),
      _ => GameIcon.projectile(
        projectileId: selectedLoadout.projectileSlotSpellId,
      ),
    };
  }

  Widget _catalogueHeader(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: ui.space.xs),
      child: Text(_categoryLabel(context, slot), style: ui.text.body),
    );
  }

  Widget _grid(BuildContext context, {bool shrinkWrap = false}) {
    final ui = context.ui;
    if (offers.isEmpty) {
      if (shrinkWrap) return Text(emptyText, style: ui.text.body);
      return SingleChildScrollView(child: Text(emptyText, style: ui.text.body));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final tileWidth = 88 * scaler.scale(1);
        final columns =
            ((constraints.maxWidth + ui.space.xs) / (tileWidth + ui.space.xs))
                .floor()
                .clamp(1, 5);
        final labelHeight = scaler.scale(ui.text.label.fontSize ?? 12) * 3;
        return GridView.builder(
          key: ValueKey(
            '${service.name}-grid-${characterId.name}-${slot?.name ?? 'all'}',
          ),
          padding: EdgeInsets.all(2),
          primary: false,
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: ui.space.xs,
            mainAxisSpacing: ui.space.xs,
            mainAxisExtent: 32 + ui.space.sm + labelHeight + ui.space.xs,
          ),
          itemCount: offers.length,
          itemBuilder: (context, index) {
            final offer = offers[index];
            return ItemPickerTile(
              key: ValueKey('offer-${offer.offerId}'),
              label: townStoreOfferDisplayName(
                offer,
                strings: context.gameL10n,
              ),
              icon: TownOfferIcon(offer: offer),
              selected: offer.offerId == selectedOffer?.offerId,
              statusLabel: ownedOfferIds.contains(offer.offerId)
                  ? (_training
                        ? context.l10n.townLearned
                        : context.l10n.townOwned)
                  : null,
              showLabel: true,
              onTap: purchaseInFlight ? null : () => onSelectOffer(offer),
            );
          },
        );
      },
    );
  }

  Widget _details(BuildContext context) {
    final offer = selectedOffer!;
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TownOfferIcon(offer: offer),
            SizedBox(width: ui.space.xs),
            Expanded(
              child: Text(
                townStoreOfferDisplayName(offer, strings: context.gameL10n),
                style: ui.text.headline,
              ),
            ),
          ],
        ),
        SizedBox(height: ui.space.sm),
        TownOfferDetails(
          offer: offer,
          selectedLoadout: selectedLoadout,
          characterId: characterId,
        ),
      ],
    );
  }

  Widget _purchase(BuildContext context) {
    final ui = context.ui;
    final offer = selectedOffer!;
    return Padding(
      padding: EdgeInsets.only(top: ui.space.sm),
      child: Align(
        key: ValueKey('${service.name}-purchase-section'),
        alignment: Alignment.center,
        child: ownedOfferIds.contains(offer.offerId)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: ui.colors.success),
                  SizedBox(width: ui.space.xs),
                  Flexible(
                    child: Text(
                      _training
                          ? context.l10n.townLearned
                          : context.l10n.townOwned,
                      style: ui.text.body.copyWith(color: ui.colors.success),
                    ),
                  ),
                ],
              )
            : AppButton.gold(
                key: ValueKey('buy-${offer.offerId}'),
                label: purchaseInFlight
                    ? context.l10n.uiBuying
                    : _training
                    ? context.l10n.townLearnAmount(gold: offer.priceGold)
                    : context.l10n.townBuyAmount(gold: offer.priceGold),
                semanticLabel: purchaseInFlight
                    ? context.l10n.uiBuying
                    : _training
                    ? context.l10n.townLearnGoldLabel(gold: offer.priceGold)
                    : context.l10n.townBuyGoldLabel(gold: offer.priceGold),
                size: AppButtonSize.xs,
                onPressed: currentGold >= offer.priceGold && !purchaseInFlight
                    ? () => onPurchase(offer)
                    : null,
              ),
      ),
    );
  }
}
