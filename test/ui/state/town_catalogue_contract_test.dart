import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/meta/meta_service.dart';
import 'package:rpg_runner/ui/pages/town/town_catalog.dart';
import 'package:rpg_runner/ui/state/ownership/progression_state.dart';

void main() {
  test('client consumes the backend catalogue fixture for both services', () {
    final json = jsonDecode(
      File('functions/test/fixtures/town_catalogue.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final store = TownStoreState.fromJson(json);
    expect(store.schemaVersion, 2);
    final meta = const MetaService().createNew();
    for (final id in [
      PlayerCharacterId.eloise,
      PlayerCharacterId.bountyHunter,
    ]) {
      final equipment = store.catalogOffers.where(
        (offer) =>
            offer.characterIds.contains(id) &&
            TownService.equipment.includes(offer),
      );
      expect(equipment, hasLength(42));
      expect(equipment.every((offer) => offer.priceGold == 150), isTrue);
      final accessory = equipment.singleWhere(
        (offer) => offer.itemId == 'strengthBelt',
      );
      expect(townOfferOwned(meta, id, accessory), isTrue);
    }
    final training = store.catalogOffers.where(
      (offer) =>
          offer.characterIds.contains(PlayerCharacterId.bountyHunter) &&
          TownService.training.includes(offer),
    );
    expect(training, hasLength(24));
    expect(
      TownStoreState.fromJson(Map<String, dynamic>.from(store.toJson()))
          .catalogOffers
          .map((o) => o.offerId),
      store.catalogOffers.map((o) => o.offerId),
    );
  });

  test('retained snapshots do not pretend to supply a full catalogue', () {
    final store = TownStoreState.fromJson({
      'schemaVersion': 1,
      'activeOffers': [],
    });
    expect(store.catalogOffers, isEmpty);
    expect(store.schemaVersion, 1);
  });
}
