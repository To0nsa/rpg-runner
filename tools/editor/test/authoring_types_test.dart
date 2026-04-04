import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';

void main() {
  test('authoring command snapshots and freezes nested payload collections', () {
    final nestedList = <Object?>['chunk_a'];
    final nestedMap = <String, Object?>{'ids': nestedList};
    final payload = <String, Object?>{
      'levelId': 'forest',
      'nested': nestedMap,
    };

    final command = AuthoringCommand(kind: 'set_active_level', payload: payload);

    nestedList.add('chunk_b');
    nestedMap['other'] = true;
    payload['topLevel'] = 'mutated';

    expect(command.payload.containsKey('topLevel'), isFalse);

    final frozenNestedMap = command.payload['nested']! as Map<Object?, Object?>;
    final frozenNestedList = frozenNestedMap['ids']! as List<Object?>;
    expect(frozenNestedList, <Object?>['chunk_a']);

    expect(
      () => command.payload['newKey'] = 'value',
      throwsUnsupportedError,
    );
    expect(
      () => frozenNestedMap['other'] = false,
      throwsUnsupportedError,
    );
    expect(
      () => frozenNestedList.add('chunk_c'),
      throwsUnsupportedError,
    );
  });

  test('export result snapshots artifact collections', () {
    final artifacts = <ExportArtifact>[
      const ExportArtifact(title: 'summary.md', content: 'before'),
    ];

    final result = ExportResult(applied: true, artifacts: artifacts);
    artifacts.add(
      const ExportArtifact(title: 'diff.md', content: 'after'),
    );

    expect(result.artifacts, hasLength(1));
    expect(
      () => result.artifacts.add(
        const ExportArtifact(title: 'extra.md', content: 'x'),
      ),
      throwsUnsupportedError,
    );
  });

  test('pending changes snapshots changed items and file diffs', () {
    final changedItemIds = <String>['chunk_field_001'];
    final fileDiffs = <PendingFileDiff>[
      const PendingFileDiff(
        relativePath: 'assets/authoring/level/chunks/chunk_field_001.json',
        editCount: 1,
        unifiedDiff: 'diff --git',
      ),
    ];

    final pending = PendingChanges(
      changedItemIds: changedItemIds,
      fileDiffs: fileDiffs,
    );

    changedItemIds.add('chunk_field_002');
    fileDiffs.add(
      const PendingFileDiff(
        relativePath: 'assets/authoring/level/chunks/chunk_field_002.json',
        editCount: 1,
        unifiedDiff: 'diff --git',
      ),
    );

    expect(pending.changedItemIds, <String>['chunk_field_001']);
    expect(pending.fileDiffs, hasLength(1));
    expect(() => pending.changedItemIds.add('chunk_field_003'), throwsUnsupportedError);
    expect(
      () => pending.fileDiffs.add(
        const PendingFileDiff(
          relativePath: 'assets/authoring/level/chunks/chunk_field_003.json',
          editCount: 1,
          unifiedDiff: 'diff --git',
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
