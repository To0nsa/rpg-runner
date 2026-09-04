import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_owner_draft_state.dart';

void main() {
  test('edit and rename transitions preserve draft invariants', () {
    final state = EditorOwnerDraftState<String, int>();

    expect(state.editSource, isNull);
    expect(state.beginRename(), isFalse);

    state.beginEdit('owner-a');
    expect(state.editSource, 'owner-a');
    expect(state.beginRename(), isTrue);
    expect(state.renameActive, isTrue);
    expect(state.setEditDirty(true), isTrue);
    expect(state.hasDirtyDraft, isTrue);
    expect(state.beginRename(), isFalse);

    expect(state.cancelRename(), isTrue);
    expect(state.renameActive, isFalse);
    expect(state.editDirty, isFalse);
    expect(state.clearEdit(), isTrue);
    expect(state.clearEdit(), isFalse);
  });

  test('creation supports guidance-only expansion and complete reset', () {
    final state = EditorOwnerDraftState<String, int>();

    state.expandCreate();
    expect(state.createExpanded, isTrue);
    expect(state.createSource, isNull);
    expect(state.setCreateDirty(true), isTrue);
    expect(state.hasDirtyDraft, isTrue);

    state.clearCreate();
    state.expandCreate(42);
    state.beginEdit('owner-b');
    state.setEditDirty(true);
    expect(state.createSource, 42);

    state.reset();
    expect(state.editSource, isNull);
    expect(state.createSource, isNull);
    expect(state.createExpanded, isFalse);
    expect(state.hasDirtyDraft, isFalse);
  });
}
