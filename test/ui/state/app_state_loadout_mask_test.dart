import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/players/player_character_definition.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/meta_store.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/selection_store.dart';
import 'package:rpg_runner/ui/state/user_profile.dart';
import 'package:rpg_runner/ui/state/user_profile_store.dart';

void main() {
  group('AppState loadout mask normalization', () {
    test('buildRunStartArgs uses character-authored loadout mask', () {
      final appState = AppState();

      final args = appState.buildRunStartArgs(seed: 123);

      expect(args.equippedLoadout.mask, LoadoutSlotMask.all);
    });

    test(
      'setLoadout normalizes legacy mask to selected character mask',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(mask: LoadoutSlotMask.defaultMask),
        );

        expect(appState.selection.equippedLoadout.mask, LoadoutSlotMask.all);
        expect(selectionStore.saved.equippedLoadout.mask, LoadoutSlotMask.all);
      },
    );

    test(
      'equipGear syncs selected loadout projectile and spellbook sources',
      () async {
        final selectionStore = _MemorySelectionStore();
        final metaStore = _MemoryMetaStore(
          saved: const MetaService().createNew(),
        );
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.throwingWeapon,
          itemId: ProjectileItemId.throwingAxe,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );

        expect(
          appState.selection.equippedLoadout.projectileItemId,
          ProjectileItemId.throwingAxe,
        );
        expect(
          appState.selection.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileItemId,
          ProjectileItemId.throwingAxe,
        );
        expect(
          selectionStore.saved.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );

    test(
      'bootstrap syncs stale selection gear ids from persisted meta',
      () async {
        const service = MetaService();
        var meta = service.createNew();
        meta = service.equip(
          meta,
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.throwingWeapon,
          itemId: ProjectileItemId.throwingAxe,
        );
        meta = service.equip(
          meta,
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );

        final selectionStore = _MemorySelectionStore(
          saved: SelectionState(
            selectedLevelId: SelectionState.defaults.selectedLevelId,
            selectedRunType: SelectionState.defaults.selectedRunType,
            selectedCharacterId: PlayerCharacterId.eloise,
            equippedLoadout: EquippedLoadoutDef(
              projectileItemId: ProjectileItemId.throwingKnife,
              spellBookId: SpellBookId.basicSpellBook,
            ),
            buildName: SelectionState.defaultBuildName,
          ),
        );
        final metaStore = _MemoryMetaStore(saved: meta);
        final profileStore = _MemoryUserProfileStore();
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: profileStore,
        );

        await appState.bootstrap(force: true);

        expect(
          appState.selection.equippedLoadout.projectileItemId,
          ProjectileItemId.throwingAxe,
        );
        expect(
          appState.selection.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileItemId,
          ProjectileItemId.throwingAxe,
        );
        expect(
          selectionStore.saved.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );
  });
}

class _MemorySelectionStore extends SelectionStore {
  _MemorySelectionStore({SelectionState? saved})
    : saved = saved ?? SelectionState.defaults;

  SelectionState saved;

  @override
  Future<SelectionState> load() async => saved;

  @override
  Future<void> save(SelectionState state) async {
    saved = state;
  }
}

class _MemoryMetaStore extends MetaStore {
  _MemoryMetaStore({required this.saved});

  MetaState saved;

  @override
  Future<MetaState> load(MetaService service) async => saved;

  @override
  Future<void> save(MetaState state) async {
    saved = state;
  }
}

class _MemoryUserProfileStore extends UserProfileStore {
  _MemoryUserProfileStore({UserProfile? saved})
    : saved = saved ?? UserProfile.empty();

  UserProfile saved;

  @override
  Future<UserProfile> load() async => saved;

  @override
  Future<void> save(UserProfile profile) async {
    saved = profile;
  }

  @override
  UserProfile createFresh() => saved;
}
