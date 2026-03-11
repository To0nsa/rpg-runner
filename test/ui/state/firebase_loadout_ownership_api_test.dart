import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/ui/state/firebase_loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/loadout_ownership_api.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';

void main() {
  test('loadCanonicalState decodes wrapped canonical payload', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource();
    final expected = OwnershipCanonicalState(
      profileId: 'p1',
      revision: 7,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
    );
    source.loadCanonicalResponse = <String, dynamic>{
      'canonicalState': expected.toJson(),
    };
    final api = FirebaseLoadoutOwnershipApi(source: source);

    final actual = await api.loadCanonicalState(
      profileId: 'p1',
      userId: 'u1',
      sessionId: 's1',
    );

    expect(actual.profileId, expected.profileId);
    expect(actual.revision, expected.revision);
  });

  test('setAbilitySlot forwards typed command to Firebase source', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource();
    final canonical = OwnershipCanonicalState(
      profileId: 'p1',
      revision: 1,
      selection: SelectionState.defaults,
      meta: const MetaService().createNew(),
    );
    source.commandResponse = OwnershipCommandResult(
      canonicalState: canonical,
      newRevision: canonical.revision,
      replayedFromIdempotency: false,
    ).toJson();
    final api = FirebaseLoadoutOwnershipApi(source: source);

    final result = await api.setAbilitySlot(
      const SetAbilitySlotCommand(
        profileId: 'p1',
        userId: 'u1',
        sessionId: 's1',
        expectedRevision: 0,
        commandId: 'cmd-1',
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.spell,
        abilityId: 'eloise.focus',
      ),
    );

    expect(result.accepted, isTrue);
    expect(source.lastCommand?.type, 'setAbilitySlot');
  });

  test('throws when Firebase source fails and fallback is disabled', () async {
    final source = _FakeFirebaseLoadoutOwnershipSource()
      ..commandError = StateError('backend unavailable');
    final api = FirebaseLoadoutOwnershipApi(source: source);

    await expectLater(
      () => api.unlockGear(
        const UnlockGearCommand(
          profileId: 'p1',
          userId: 'u1',
          sessionId: 's1',
          expectedRevision: 0,
          commandId: 'cmd-fallback',
          slot: GearSlot.accessory,
          itemId: AccessoryId.strengthBelt,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeFirebaseLoadoutOwnershipSource
    implements FirebaseLoadoutOwnershipSource {
  Map<String, dynamic> loadCanonicalResponse = <String, dynamic>{};
  Map<String, dynamic> commandResponse = <String, dynamic>{};
  Object? loadCanonicalError;
  Object? commandError;
  OwnershipCommand? lastCommand;

  @override
  Future<Map<String, dynamic>> loadCanonicalState({
    required String profileId,
    required String userId,
    required String sessionId,
  }) async {
    final error = loadCanonicalError;
    if (error != null) {
      throw error;
    }
    return loadCanonicalResponse;
  }

  @override
  Future<Map<String, dynamic>> executeCommand({
    required OwnershipCommand command,
  }) async {
    lastCommand = command;
    final error = commandError;
    if (error != null) {
      throw error;
    }
    return commandResponse;
  }
}
