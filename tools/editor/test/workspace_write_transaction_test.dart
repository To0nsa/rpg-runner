import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/workspace/workspace_write_transaction.dart';

void main() {
  test(
    'transaction installs and verifies a complete deterministic file set',
    () {
      final root = Directory.systemTemp.createTempSync(
        'workspace_write_success_',
      );
      try {
        final first = File(p.join(root.path, 'a.txt'))
          ..writeAsStringSync('old a');
        final second = File(p.join(root.path, 'nested', 'b.txt'));
        var verificationRan = false;

        WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: second.path, contents: 'new b\n'),
          WorkspaceWriteArtifact(path: first.path, contents: 'new a\n'),
        ]).apply(
          beforeReplace: () {
            expect(first.readAsStringSync(), 'old a');
            expect(second.existsSync(), isFalse);
          },
          verifyReplacements: () {
            verificationRan = true;
            expect(first.readAsStringSync(), 'new a\n');
            expect(second.readAsStringSync(), 'new b\n');
          },
        );

        expect(verificationRan, isTrue);
        expect(first.readAsStringSync(), 'new a\n');
        expect(second.readAsStringSync(), 'new b\n');
        expect(_transactionFiles(root), isEmpty);
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('drift callback aborts before any target moves', () {
    final root = Directory.systemTemp.createTempSync('workspace_write_drift_');
    try {
      final first = File(p.join(root.path, 'a.txt'))
        ..writeAsStringSync('old a');
      final second = File(p.join(root.path, 'b.txt'))
        ..writeAsStringSync('old b');

      WorkspaceWriteTransactionException? failure;
      try {
        WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: first.path, contents: 'new a'),
          WorkspaceWriteArtifact(path: second.path, contents: 'new b'),
        ]).apply(beforeReplace: () => throw StateError('source drift'));
      } on WorkspaceWriteTransactionException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.rollbackComplete, isTrue);
      expect(first.readAsStringSync(), 'old a');
      expect(second.readAsStringSync(), 'old b');
      expect(_transactionFiles(root), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('later install failure restores already installed earlier files', () {
    final root = Directory.systemTemp.createTempSync(
      'workspace_write_rollback_',
    );
    try {
      final first = File(p.join(root.path, 'a.txt'))
        ..writeAsStringSync('old a');
      final second = File(p.join(root.path, 'b.txt'))
        ..writeAsStringSync('old b');

      WorkspaceWriteTransactionException? failure;
      try {
        WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: first.path, contents: 'new a'),
          WorkspaceWriteArtifact(path: second.path, contents: 'new b'),
        ]).apply(
          beforeReplace: () {
            final secondStage = root.listSync().whereType<File>().singleWhere(
              (file) =>
                  file.path.startsWith('${second.path}.authoring-') &&
                  file.path.endsWith('.tmp'),
            );
            secondStage.deleteSync();
          },
        );
      } on WorkspaceWriteTransactionException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.rollbackComplete, isTrue);
      expect(first.readAsStringSync(), 'old a');
      expect(second.readAsStringSync(), 'old b');
      expect(_transactionFiles(root), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('post-install validation failure restores every original', () {
    final root = Directory.systemTemp.createTempSync('workspace_write_verify_');
    try {
      final first = File(p.join(root.path, 'a.txt'))
        ..writeAsStringSync('old a');
      final second = File(p.join(root.path, 'b.txt'))
        ..writeAsStringSync('old b');

      WorkspaceWriteTransactionException? failure;
      try {
        WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: first.path, contents: 'new a'),
          WorkspaceWriteArtifact(path: second.path, contents: 'new b'),
        ]).apply(
          verifyReplacements: () => throw StateError('invalid generation'),
        );
      } on WorkspaceWriteTransactionException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.rollbackComplete, isTrue);
      expect(first.readAsStringSync(), 'old a');
      expect(second.readAsStringSync(), 'old b');
      expect(_transactionFiles(root), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('transaction commits deletions with writes as one verified set', () {
    final root = Directory.systemTemp.createTempSync('workspace_write_delete_');
    try {
      final retained = File(p.join(root.path, 'a.txt'))
        ..writeAsStringSync('old a');
      final removed = File(p.join(root.path, 'b.txt'))
        ..writeAsStringSync('old b');

      WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
        WorkspaceWriteArtifact(path: retained.path, contents: 'new a'),
        WorkspaceWriteArtifact.delete(path: removed.path),
      ]).apply(
        verifyReplacements: () {
          expect(retained.readAsStringSync(), 'new a');
          expect(removed.existsSync(), isFalse);
        },
      );

      expect(retained.readAsStringSync(), 'new a');
      expect(removed.existsSync(), isFalse);
      expect(_transactionFiles(root), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('post-install failure restores a transaction deletion', () {
    final root = Directory.systemTemp.createTempSync(
      'workspace_write_delete_rollback_',
    );
    try {
      final retained = File(p.join(root.path, 'a.txt'))
        ..writeAsStringSync('old a');
      final removed = File(p.join(root.path, 'b.txt'))
        ..writeAsStringSync('old b');

      WorkspaceWriteTransactionException? failure;
      try {
        WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: retained.path, contents: 'new a'),
          WorkspaceWriteArtifact.delete(path: removed.path),
        ]).apply(
          verifyReplacements: () => throw StateError('invalid deletion set'),
        );
      } on WorkspaceWriteTransactionException catch (error) {
        failure = error;
      }

      expect(failure, isNotNull);
      expect(failure!.rollbackComplete, isTrue);
      expect(retained.readAsStringSync(), 'old a');
      expect(removed.readAsStringSync(), 'old b');
      expect(_transactionFiles(root), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('canonical duplicate targets reject before filesystem access', () {
    final root = Directory.systemTemp.createTempSync(
      'workspace_write_duplicate_',
    );
    try {
      final target = p.join(root.path, 'nested', '..', 'same.txt');
      expect(
        () => WorkspaceWriteTransaction(<WorkspaceWriteArtifact>[
          WorkspaceWriteArtifact(path: target, contents: 'a'),
          WorkspaceWriteArtifact(
            path: p.join(root.path, 'same.txt'),
            contents: 'b',
          ),
        ]),
        throwsArgumentError,
      );
      expect(root.listSync(), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}

List<FileSystemEntity> _transactionFiles(Directory root) => root
    .listSync(recursive: true)
    .where(
      (entity) =>
          entity.path.contains('.authoring-') &&
          (entity.path.endsWith('.tmp') || entity.path.endsWith('.bak')),
    )
    .toList(growable: false);
