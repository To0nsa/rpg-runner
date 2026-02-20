import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/meta/gear_slot.dart';
import 'package:rpg_runner/core/meta/meta_service.dart';
import 'package:rpg_runner/core/meta/meta_state.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/spellBook/spell_book_id.dart';
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

    test('setLoadout repairs unknown ability ids', () async {
      final selectionStore = _MemorySelectionStore();
      final appState = AppState(selectionStore: selectionStore);

      await appState.setLoadout(
        const EquippedLoadoutDef(abilityPrimaryId: 'common.unarmed_strike'),
      );

      expect(
        appState.selection.equippedLoadout.abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
      expect(
        selectionStore.saved.equippedLoadout.abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
    });

    test(
      'setLoadout repairs stale spell-slot spell for equipped spellbook',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(abilitySpellId: 'eloise.mana_infusion'),
        );

        expect(
          appState.selection.equippedLoadout.abilitySpellId,
          'eloise.arcane_haste',
        );
        expect(
          selectionStore.saved.equippedLoadout.abilitySpellId,
          'eloise.arcane_haste',
        );
      },
    );

    test(
      'setLoadout repairs stale projectile spell for equipped spellbook',
      () async {
        final selectionStore = _MemorySelectionStore();
        final appState = AppState(selectionStore: selectionStore);

        await appState.setLoadout(
          const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.iceBolt),
        );

        expect(
          appState.selection.equippedLoadout.projectileSlotSpellId,
          ProjectileId.fireBolt,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileSlotSpellId,
          ProjectileId.fireBolt,
        );
      },
    );

    test(
      'setLoadout stale projectile spell repairs to first granted spell only',
      () async {
        final selectionStore = _MemorySelectionStore();
        final baseMeta = const MetaService().createNew();
        final metaWithEpicEquipped = baseMeta.setEquippedFor(
          PlayerCharacterId.eloise,
          baseMeta
              .equippedFor(PlayerCharacterId.eloise)
              .copyWith(spellBookId: SpellBookId.epicSpellBook),
        );
        final metaStore = _MemoryMetaStore(saved: metaWithEpicEquipped);
        final appState = AppState(
          selectionStore: selectionStore,
          metaStore: metaStore,
          userProfileStore: _MemoryUserProfileStore(),
        );

        await appState.bootstrap(force: true);
        await appState.setLoadout(
          const EquippedLoadoutDef(
            projectileSlotSpellId: ProjectileId.throwingAxe,
          ),
        );

        expect(
          appState.selection.equippedLoadout.projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileSlotSpellId,
          ProjectileId.iceBolt,
        );
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
          itemId: ProjectileId.throwingAxe,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );

        expect(
          appState.selection.equippedLoadout.projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          appState.selection.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          selectionStore.saved.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );

    test(
      'equipGear spellbook swap repairs stale spell-slot spell immediately',
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
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );
        await appState.setLoadout(
          const EquippedLoadoutDef(abilitySpellId: 'eloise.vital_surge'),
        );
        expect(
          appState.selection.equippedLoadout.abilitySpellId,
          'eloise.vital_surge',
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.basicSpellBook,
        );

        expect(
          appState.selection.equippedLoadout.abilitySpellId,
          'eloise.arcane_haste',
        );
        expect(
          selectionStore.saved.equippedLoadout.abilitySpellId,
          'eloise.arcane_haste',
        );
      },
    );

    test(
      'equipGear spellbook swap repairs stale projectile spell immediately',
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
          slot: GearSlot.spellBook,
          itemId: SpellBookId.solidSpellBook,
        );
        await appState.setLoadout(
          const EquippedLoadoutDef(projectileSlotSpellId: ProjectileId.iceBolt),
        );
        expect(
          appState.selection.equippedLoadout.projectileSlotSpellId,
          ProjectileId.iceBolt,
        );

        await appState.equipGear(
          characterId: PlayerCharacterId.eloise,
          slot: GearSlot.spellBook,
          itemId: SpellBookId.basicSpellBook,
        );

        expect(
          appState.selection.equippedLoadout.projectileSlotSpellId,
          ProjectileId.fireBolt,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileSlotSpellId,
          ProjectileId.fireBolt,
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
          itemId: ProjectileId.throwingAxe,
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
              projectileId: ProjectileId.throwingKnife,
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
          appState.selection.equippedLoadout.projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          appState.selection.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
        expect(
          selectionStore.saved.equippedLoadout.projectileId,
          ProjectileId.throwingAxe,
        );
        expect(
          selectionStore.saved.equippedLoadout.spellBookId,
          SpellBookId.solidSpellBook,
        );
      },
    );

    test('bootstrap repairs unknown saved ability ids', () async {
      final selectionStore = _MemorySelectionStore(
        saved: SelectionState(
          selectedLevelId: SelectionState.defaults.selectedLevelId,
          selectedRunType: SelectionState.defaults.selectedRunType,
          selectedCharacterId: PlayerCharacterId.eloise,
          equippedLoadout: const EquippedLoadoutDef(
            abilityPrimaryId: 'common.unarmed_strike',
          ),
          buildName: SelectionState.defaultBuildName,
        ),
      );
      final metaStore = _MemoryMetaStore(
        saved: const MetaService().createNew(),
      );
      final profileStore = _MemoryUserProfileStore();
      final appState = AppState(
        selectionStore: selectionStore,
        metaStore: metaStore,
        userProfileStore: profileStore,
      );

      await appState.bootstrap(force: true);

      expect(
        appState.selection.equippedLoadout.abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
      expect(
        selectionStore.saved.equippedLoadout.abilityPrimaryId,
        'eloise.bloodletter_slash',
      );
    });
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
