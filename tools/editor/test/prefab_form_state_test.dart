import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_form_state.dart';

void main() {
  test('obstacle form can enter the colliderless reauthoring state', () {
    final state = PrefabFormState.obstacle();
    addTearDown(state.dispose);

    expect(state.colliderDrafts, hasLength(1));
    expect(state.canDeleteSelectedCollider, isTrue);

    expect(state.deleteSelectedCollider(), isNull);
    expect(state.colliderDrafts, isEmpty);
    expect(state.selectedColliderIndex, isNull);
    expect(state.canDeleteSelectedCollider, isFalse);
    expect(state.tryParseColliderDrafts(), isEmpty);
  });
}
