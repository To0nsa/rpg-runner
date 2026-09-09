import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_local_draft_state.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_session_semantics.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test(
    'committed save retains its document until refresh-only retry succeeds',
    () async {
      final plugin = _MemoryPlugin();
      final controller = _controller(plugin);
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      controller.applyCommand(AuthoringCommand(kind: 'edit'));
      final intended = controller.document;
      plugin.failLoadsAfterWrite = true;

      final result = await controller.exportDirectWrite();

      expect(result!.applied, isTrue);
      expect(plugin.persisted, 1);
      expect(plugin.writes, 1);
      expect(controller.document, same(intended));
      expect(controller.exportError, isNull);
      expect(controller.requiresSavedRefresh, isTrue);
      expect(controller.refreshError, contains('refresh unavailable'));
      expect(
        EditorPageSaveResult.fromSession(controller),
        EditorPageSaveResult.savedRefreshFailed,
      );

      controller.applyCommand(AuthoringCommand(kind: 'edit'));
      controller.undo();
      expect(controller.document, same(intended));
      expect(await controller.exportDirectWrite(), isNull);
      expect(await controller.retrySavedRefresh(), isFalse);
      expect(plugin.writes, 1);

      plugin.failLoadsAfterWrite = false;
      expect(await controller.retrySavedRefresh(), isTrue);
      expect(plugin.writes, 1);
      expect(controller.requiresSavedRefresh, isFalse);
      expect(controller.refreshError, isNull);
      expect((controller.document! as _Document).value, 1);
      expect(controller.pendingChanges.hasChanges, isFalse);
      expect(
        EditorPageSaveResult.fromSession(controller),
        EditorPageSaveResult.saved,
      );
    },
  );

  test(
    'transaction recovery blocks another write without misreporting commit',
    () async {
      final plugin = _MemoryPlugin()..cleanupRequired = true;
      final controller = _controller(plugin);
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      controller.applyCommand(AuthoringCommand(kind: 'edit'));

      await controller.exportDirectWrite();

      expect(controller.lastExportResult!.applied, isTrue);
      expect(controller.requiresSavedRefresh, isFalse);
      expect(controller.requiresTransactionRecovery, isTrue);
      expect(
        EditorPageSaveResult.fromSession(controller).permitsDeparture,
        isFalse,
      );
      expect(await controller.exportDirectWrite(), isNull);
      expect(plugin.writes, 1);
    },
  );

  test('verified cleanup retry unlocks Save without repeating export', () async {
    final plugin = _MemoryPlugin()..cleanupRequired = true;
    final controller = _controller(plugin);
    addTearDown(controller.dispose);
    await controller.loadWorkspace();
    controller.applyCommand(AuthoringCommand(kind: 'edit'));
    await controller.exportDirectWrite();
    expect(controller.requiresTransactionRecovery, isTrue);
    expect(await controller.retryTransactionRecovery(), isTrue);
    expect(plugin.writes, 1);
    expect(controller.requiresTransactionRecovery, isFalse);
    expect(controller.lastExportResult!.outcome, ExportOutcome.applied);
    expect(await controller.retryTransactionRecovery(), isFalse);
  });

  test(
    'presentation selection is history neutral and survives content undo',
    () async {
      final controller = _controller(_MemoryPlugin());
      addTearDown(controller.dispose);
      await controller.loadWorkspace();
      controller.applyPresentationCommand(
        AuthoringCommand(kind: 'select', payload: {'selection': 'second'}),
      );
      expect(controller.canUndo, isFalse);
      expect(controller.pendingChanges.hasChanges, isFalse);

      controller.applyCommand(AuthoringCommand(kind: 'edit'));
      controller.applyPresentationCommand(
        AuthoringCommand(kind: 'select', payload: {'selection': 'third'}),
      );
      controller.undo();
      expect((controller.document! as _Document).value, 0);
      expect((controller.document! as _Document).selection, 'third');
      expect(controller.canUndo, isFalse);
      controller.redo();
      expect((controller.document! as _Document).value, 1);
      expect((controller.document! as _Document).selection, 'third');
      expect(
        () =>
            controller.applyPresentationCommand(AuthoringCommand(kind: 'edit')),
        throwsArgumentError,
      );
    },
  );
}

EditorSessionController _controller(_MemoryPlugin plugin) =>
    EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(plugins: [plugin]),
      initialPluginId: plugin.id,
      initialWorkspacePath: '.',
    );

class _Document extends AuthoringDocument {
  const _Document(this.value, this.baseline, this.selection);
  final int value;
  final int baseline;
  final String selection;
}

class _Scene extends EditableScene {
  const _Scene();
}

class _MemoryPlugin
    implements AuthoringDomainPlugin, AuthoringSessionSemantics {
  int persisted = 0;
  int writes = 0;
  bool failLoadsAfterWrite = false;
  bool cleanupRequired = false;

  @override
  String get id => 'save_recovery_fixture';

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    if (writes > 0 && failLoadsAfterWrite) {
      throw StateError('refresh unavailable');
    }
    return _Document(persisted, persisted, 'first');
  }

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) {
    final source = document as _Document;
    return command.kind == 'select'
        ? _Document(
            source.value,
            source.baseline,
            command.payload['selection']! as String,
          )
        : _Document(source.value + 1, source.baseline, source.selection);
  }

  @override
  bool isPresentationCommand(AuthoringCommand command) =>
      command.kind == 'select';

  @override
  AuthoringDocument retainPresentation({
    required AuthoringDocument current,
    required AuthoringDocument restored,
  }) {
    final desired = restored as _Document;
    return _Document(
      desired.value,
      desired.baseline,
      (current as _Document).selection,
    );
  }

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      const _Scene();

  @override
  List<ValidationIssue> validate(AuthoringDocument document) => const [];

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) {
    final source = document as _Document;
    return source.value == source.baseline
        ? PendingChanges.empty
        : PendingChanges(changedItemIds: const ['fixture']);
  }

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) async {
    persisted = (document as _Document).value;
    writes++;
    return ExportResult(
      applied: true,
      recovery: cleanupRequired ? _CleanupRecovery() : null,
      outcome: cleanupRequired
          ? ExportOutcome.appliedWithCleanupRequired
          : ExportOutcome.applied,
      message: cleanupRequired
          ? 'Saved; fixture cleanup requires review.'
          : null,
    );
  }
}

class _CleanupRecovery implements AuthoringExportRecovery {
  @override
  Future<ExportResult> retry() async => ExportResult(applied: true);
}
