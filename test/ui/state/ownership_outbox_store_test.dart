import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rpg_runner/ui/state/ownership_outbox_store.dart';
import 'package:rpg_runner/ui/state/ownership_pending_command.dart';
import 'package:rpg_runner/ui/state/ownership_sync_policy.dart';

void main() {
  group('SharedPrefsOwnershipOutboxStore', () {
    late SharedPrefsOwnershipOutboxStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = SharedPrefsOwnershipOutboxStore();
    });

    test('upsertCoalesced stores and replaces by coalesceKey', () async {
      await store.upsertCoalesced(command: _command(key: 'selection:level'));
      await store.upsertCoalesced(
        command: _command(
          key: 'selection:level',
          updatedAtMs: 200,
          payload: <String, Object?>{'selectedLevelId': 'forest'},
        ),
      );

      final all = await store.loadAll();
      expect(all, hasLength(1));
      expect(all.single.coalesceKey, 'selection:level');
      expect(all.single.createdAtMs, 100);
      expect(all.single.updatedAtMs, 200);
      expect(all.single.payloadJson['selectedLevelId'], 'forest');
    });

    test('loadAll accepts wrapped v2 payload and legacy row list', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<Object?>[_command(key: 'selection:runMode').toJson()]),
      );

      final legacyLoaded = await store.loadAll();
      expect(legacyLoaded, hasLength(1));
      expect(legacyLoaded.single.coalesceKey, 'selection:runMode');

      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<String, Object?>{
          'version': 2,
          'entries': <Object?>[_command(key: 'gear:eloise:mainWeapon').toJson()],
        }),
      );
      final wrappedLoaded = await store.loadAll();
      expect(wrappedLoaded, hasLength(1));
      expect(wrappedLoaded.single.coalesceKey, 'gear:eloise:mainWeapon');
    });

    test('ignores malformed rows and keeps valid rows', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPrefsOwnershipOutboxStore.storageKey,
        jsonEncode(<String, Object?>{
          'version': 2,
          'entries': <Object?>[
            <String, Object?>{'coalesceKey': 7},
            _command(key: 'selection:character').toJson(),
          ],
        }),
      );

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.coalesceKey, 'selection:character');
    });

    test('removeByCoalesceKey and clear delete entries', () async {
      await store.upsertCoalesced(command: _command(key: 'a'));
      await store.upsertCoalesced(command: _command(key: 'b'));

      await store.removeByCoalesceKey(coalesceKey: 'a');
      final afterRemove = await store.loadAll();
      expect(afterRemove.map((e) => e.coalesceKey), ['b']);

      await store.clear();
      final afterClear = await store.loadAll();
      expect(afterClear, isEmpty);
    });
  });
}

OwnershipPendingCommand _command({
  required String key,
  int createdAtMs = 100,
  int updatedAtMs = 100,
  Map<String, Object?> payload = const <String, Object?>{
    'selectedLevelId': 'field',
  },
}) {
  return OwnershipPendingCommand(
    coalesceKey: key,
    commandType: OwnershipPendingCommandType.setSelection,
    policyTier: OwnershipSyncTier.selectionFastSync,
    payloadJson: payload,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
  );
}
