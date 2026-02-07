import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/ui/state/app_state.dart';
import 'package:rpg_runner/ui/state/selection_state.dart';
import 'package:rpg_runner/ui/state/selection_store.dart';

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
  });
}

class _MemorySelectionStore extends SelectionStore {
  SelectionState saved = SelectionState.defaults;

  @override
  Future<SelectionState> load() async => saved;

  @override
  Future<void> save(SelectionState state) async {
    saved = state;
  }
}
