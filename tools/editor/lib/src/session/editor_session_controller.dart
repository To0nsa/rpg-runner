import 'package:flutter/foundation.dart';

import '../domain/authoring_plugin_registry.dart';
import '../domain/authoring_intent_reconciliation.dart';
import '../domain/authoring_session_semantics.dart';
import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';

/// Orchestrates the active authoring session for the selected plugin/workspace.
///
/// Keeps the loaded document snapshot, derived scene, validation issues,
/// pending changes, and undo/redo history in sync so routes can treat the
/// controller as a coherent session boundary. Changing the plugin invalidates
/// the loaded snapshot instead of reusing potentially stale state.
///
/// This controller owns committed authoring state only. Pages may still keep
/// transient local draft state such as text fields, viewport state, or tool
/// selection, but anything that should participate in validation, pending file
/// diffs, undo/redo, or export must flow through this session boundary.
class EditorSessionController extends ChangeNotifier {
  /// Creates a session scoped to one plugin registry, active plugin id, and
  /// workspace root path.
  ///
  /// The initial plugin/workspace are treated as context only; no document is
  /// loaded until [loadWorkspace] succeeds.
  EditorSessionController({
    required AuthoringPluginRegistry pluginRegistry,
    required String initialPluginId,
    required String initialWorkspacePath,
  }) : _pluginRegistry = pluginRegistry,
       _selectedPluginId = initialPluginId,
       _workspacePath = initialWorkspacePath;

  final AuthoringPluginRegistry _pluginRegistry;
  String _selectedPluginId;
  final String _workspacePath;

  bool _isLoading = false;
  bool _isExporting = false;
  String? _loadError;
  String? _exportError;
  String? _refreshError;
  bool _requiresSavedRefresh = false;
  bool _requiresTransactionRecovery = false;
  bool _requiresSourceReconciliation = false;
  int _sourceWriteCount = 0;
  int _sourceGeneration = 0;
  EditorWorkspace? _workspace;
  AuthoringDocument? _document;
  EditableScene? _scene;
  List<ValidationIssue> _issues = const <ValidationIssue>[];
  PendingChanges _pendingChanges = PendingChanges.empty;
  String? _pendingChangesError;
  ExportResult? _lastExportResult;
  final List<AuthoringDocument> _undoStack = <AuthoringDocument>[];
  final List<AuthoringDocument> _redoStack = <AuthoringDocument>[];
  AuthoringDocument? _coalescedUndoBaseDocument;
  AuthoringDocument? _recoveryCopy;
  String? _recoveryError;

  /// All registered domain plugins available for route/session selection.
  List<AuthoringDomainPlugin> get availablePlugins => _pluginRegistry.all;

  /// Active plugin id whose document/scene contract this session currently uses.
  String get selectedPluginId => _selectedPluginId;

  /// Workspace root path set when this editor session starts.
  String get workspacePath => _workspacePath;

  /// A read-only originating intent copy retained through recovery decisions.
  AuthoringDocument? get recoveryCopy => _recoveryCopy;
  String? get recoveryError => _recoveryError;
  bool get canReapplyIntent =>
      _pluginRegistry.requireById(_selectedPluginId)
          is AuthoringIntentReconciliation;

  /// Creates the single dependency session owned by the shell's repair journey.
  /// Loading it cannot replace this controller's document or page buffers.
  EditorSessionController createDependencySession(String pluginId) =>
      EditorSessionController(
        pluginRegistry: _pluginRegistry,
        initialPluginId: pluginId,
        initialWorkspacePath: _workspacePath,
      );

  /// True while a normal reload or guarded plugin transition is resolving a
  /// repository document.
  bool get isLoading => _isLoading;

  /// True while [exportDirectWrite] is running plugin-owned repository writes.
  bool get isExporting => _isExporting;

  /// Last load failure for the current context, if any.
  String? get loadError => _loadError;

  /// Last export failure for the current loaded document, if any.
  String? get exportError => _exportError;

  /// True after committed writes until their canonical document is reloaded.
  /// Further edits/exports are blocked so retry cannot write the same intent twice.
  bool get requiresSavedRefresh => _requiresSavedRefresh;

  /// Last refresh failure following a committed export, separate from write failure.
  String? get refreshError => _refreshError;

  /// Whether transaction-owned recovery must be resolved before another write.
  bool get requiresTransactionRecovery => _requiresTransactionRecovery;
  bool get requiresSourceReconciliation => _requiresSourceReconciliation;
  int get sourceWriteCount => _sourceWriteCount;

  /// Changes after a successful source reload, Save refresh, or reconciliation.
  /// Dependent views use this to retire projections built from older sources.
  int get sourceGeneration => _sourceGeneration;

  /// Loaded workspace handle bound to the current document snapshot.
  EditorWorkspace? get workspace => _workspace;

  /// Plugin-owned authoritative document snapshot currently being edited.
  AuthoringDocument? get document => _document;

  /// UI-facing scene projection derived from [document].
  EditableScene? get scene => _scene;

  /// Deterministic validation issues for the current [document].
  ///
  /// Exposed as an immutable snapshot so widgets cannot mutate controller state
  /// outside the session lifecycle.
  List<ValidationIssue> get issues => _issues;

  /// Pending plugin-reported item/file deltas against repository state.
  PendingChanges get pendingChanges => _pendingChanges;

  /// Error raised while computing [pendingChanges], if any.
  ///
  /// Pending-change computation is treated as auxiliary UI state, so a failure
  /// here does not invalidate the loaded document.
  String? get pendingChangesError => _pendingChangesError;

  /// Last export summary/artifacts produced by [exportDirectWrite].
  ///
  /// Cleared on subsequent local document changes so widgets do not show stale
  /// "last apply" output for a newer unsaved document state.
  ExportResult? get lastExportResult => _lastExportResult;

  /// True when the session can step backward through committed document edits.
  bool get canUndo => _undoStack.isNotEmpty;

  /// True when the session can step forward after an [undo].
  bool get canRedo => _redoStack.isNotEmpty;

  /// Domain-defined dirty item ids for the current [pendingChanges] snapshot.
  ///
  /// These ids are opaque to the controller and are intended for route UI such
  /// as dirty row markers or focused navigation.
  Set<String> get dirtyItemIds =>
      Set<String>.unmodifiable(_pendingChanges.changedItemIds);

  /// Number of validation issues at error severity in [issues].
  int get errorCount => _issues
      .where((issue) => issue.severity == ValidationSeverity.error)
      .length;

  /// Source-integrity findings that prevent Save, excluding runtime readiness.
  int get saveBlockingErrorCount =>
      _issues.where((issue) => issue.blocks(AuthoringOperation.save)).length;

  /// Number of validation issues at warning severity in [issues].
  int get warningCount => _issues
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .length;

  /// Switches the active plugin contract and invalidates the loaded document.
  ///
  /// The workspace path is preserved, but the current document/scene/history are
  /// dropped because they are only valid for the previously selected plugin.
  void setSelectedPluginId(String pluginId) {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    if (_selectedPluginId == pluginId) {
      return;
    }
    _selectedPluginId = pluginId;
    _resetForContextChange(clearWorkspace: false);
    notifyListeners();
  }

  /// Loads a fresh plugin document from the current workspace path.
  ///
  /// Guarantees that a failed load does not leave the last successful document
  /// editable. A successful load replaces the entire derived session snapshot
  /// and clears undo/redo history because the repository baseline has changed.
  Future<void> loadWorkspace() async {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    _isLoading = true;
    _loadError = null;
    _exportError = null;
    notifyListeners();

    try {
      final workspace = EditorWorkspace(rootPath: _workspacePath);
      final plugin = _pluginRegistry.requireById(_selectedPluginId);
      final document = await plugin.loadFromRepo(workspace);
      _applyDocumentState(
        plugin: plugin,
        document: document,
        workspace: workspace,
        clearHistory: true,
      );
      _sourceGeneration++;
      _requiresSavedRefresh = false;
      _refreshError = null;
      _requiresSourceReconciliation = false;
      _recoveryCopy = null;
      _recoveryError = null;
    } catch (error, stackTrace) {
      // A failed reload must not leave the last successful document editable.
      _clearLoadedSessionState(clearWorkspace: true);
      _loadError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while loading editor workspace'),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atomically loads a repository document for another registered plugin.
  ///
  /// This is reserved for guarded cross-domain navigation that needs a
  /// plugin-owned loader other than [AuthoringDomainPlugin.loadFromRepo]. The
  /// active plugin, document, scene, pending changes, and history change only
  /// after [loadDocument] and the target plugin projections all succeed. A
  /// failure leaves the current session editable and returns `false`.
  Future<bool> loadWorkspaceForPlugin({
    required String pluginId,
    required Future<AuthoringDocument> Function(
      AuthoringDomainPlugin plugin,
      EditorWorkspace workspace,
    )
    loadDocument,
  }) async {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return false;
    }
    _isLoading = true;
    _loadError = null;
    _exportError = null;
    notifyListeners();

    try {
      final workspace = EditorWorkspace(rootPath: _workspacePath);
      final plugin = _pluginRegistry.requireById(pluginId);
      final document = await loadDocument(plugin, workspace);
      _applyDocumentState(
        plugin: plugin,
        document: document,
        workspace: workspace,
        clearHistory: true,
      );
      _selectedPluginId = pluginId;
      _requiresSourceReconciliation = false;
      _recoveryCopy = null;
      _recoveryError = null;
      _sourceGeneration++;
      return true;
    } catch (error, stackTrace) {
      _loadError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription(
            'while loading a cross-plugin editor workspace',
          ),
        ),
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applies one plugin-defined edit command to the current [document].
  ///
  /// Commands only affect committed session state. Pages should keep purely
  /// transient drafts locally until they are ready to become part of the
  /// authoritative document and participate in undo/redo/export.
  void applyCommand(AuthoringCommand command) {
    _applyCommand(command, coalesceUndo: false);
  }

  /// Applies a domain-declared selection/view command without a content undo step.
  /// Misclassified source commands are rejected instead of silently hiding edits.
  void applyPresentationCommand(AuthoringCommand command) {
    final document = _document;
    if (document == null ||
        _isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final semantics = plugin is AuthoringSessionSemantics
        ? plugin as AuthoringSessionSemantics
        : null;
    if (semantics == null || !semantics.isPresentationCommand(command)) {
      throw ArgumentError.value(
        command.kind,
        'command',
        'Not a presentation command.',
      );
    }
    final next = plugin.applyEdit(document, command);
    if (identical(next, document)) return;
    _commitCoalescedUndoStep();
    _applyDocumentState(plugin: plugin, document: next);
    notifyListeners();
  }

  /// Applies a command that should be merged into one pending undo step.
  ///
  /// Intended for high-frequency interactions (for example pointer drags)
  /// where each intermediate value should update the document, but undo should
  /// roll back the whole interaction as one operation.
  void applyCoalescedCommand(AuthoringCommand command) {
    _applyCommand(command, coalesceUndo: true);
  }

  void _applyCommand(AuthoringCommand command, {required bool coalesceUndo}) {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    final document = _document;
    if (document == null) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final nextDocument = plugin.applyEdit(document, command);
    if (identical(nextDocument, document)) {
      return;
    }
    if (_recoveryCopy != null) _recoveryCopy = nextDocument;
    if (coalesceUndo) {
      _coalescedUndoBaseDocument ??= document;
      _redoStack.clear();
      _applyDocumentState(plugin: plugin, document: nextDocument);
      notifyListeners();
      return;
    }
    _commitCoalescedUndoStep();
    _undoStack.add(document);
    _redoStack.clear();
    _applyDocumentState(plugin: plugin, document: nextDocument);
    notifyListeners();
  }

  /// Commits a pending coalesced command batch into one undo step.
  ///
  /// Scene routes can use [applyCoalescedCommand] while the
  /// pointer is moving, then call this method once when the interaction ends.
  void commitCoalescedUndoStep() {
    if (!_commitCoalescedUndoStep()) {
      return;
    }
    notifyListeners();
  }

  /// Restores the previous committed document snapshot, if available.
  void undo() {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    _commitCoalescedUndoStep();
    final document = _document;
    if (document == null || _undoStack.isEmpty) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final previous = _restoreHistoryTarget(plugin, document, _undoStack);
    if (previous == null) {
      notifyListeners();
      return;
    }
    _redoStack.add(document);
    _applyDocumentState(
      plugin: plugin,
      document: plugin is AuthoringSessionSemantics
          ? (plugin as AuthoringSessionSemantics).retainPresentation(
              current: document,
              restored: previous,
            )
          : previous,
    );
    if (_recoveryCopy != null) _recoveryCopy = _document;
    notifyListeners();
  }

  /// Reapplies the next committed document snapshot after an [undo], if any.
  void redo() {
    if (_isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return;
    }
    _commitCoalescedUndoStep();
    final document = _document;
    if (document == null || _redoStack.isEmpty) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final next = _restoreHistoryTarget(plugin, document, _redoStack);
    if (next == null) {
      notifyListeners();
      return;
    }
    _undoStack.add(document);
    _applyDocumentState(
      plugin: plugin,
      document: plugin is AuthoringSessionSemantics
          ? (plugin as AuthoringSessionSemantics).retainPresentation(
              current: document,
              restored: next,
            )
          : next,
    );
    if (_recoveryCopy != null) _recoveryCopy = _document;
    notifyListeners();
  }

  /// Exports the current [document] through the active plugin.
  ///
  /// When the plugin reports that files were written, the controller reloads
  /// from disk so the session reflects canonical persisted output rather than
  /// assuming the in-memory document matches post-export repository state.
  Future<ExportResult?> exportDirectWrite() async {
    _commitCoalescedUndoStep();
    final document = _document;
    final workspace = _workspace;
    if (document == null ||
        workspace == null ||
        _isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery ||
        _requiresSourceReconciliation) {
      return null;
    }
    _isExporting = true;
    _exportError = null;
    notifyListeners();
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    try {
      final result = await plugin.exportToRepo(workspace, document: document);
      _lastExportResult = result;
      _requiresSourceReconciliation =
          result.outcome == ExportOutcome.sourceDrift;
      _requiresTransactionRecovery =
          result.outcome == ExportOutcome.rollbackIncomplete ||
          result.outcome == ExportOutcome.appliedWithCleanupRequired;
      if (result.outcome.isFailure) {
        _exportError = result.message ?? 'The export was rejected.';
      }
      if (result.applied) {
        _sourceWriteCount += 1;
        _requiresSavedRefresh = true;
        await _refreshSavedDocument(plugin, workspace);
        _lastExportResult = result;
      }
      return result;
    } on AuthoringExportFailure catch (failure) {
      final result = failure.exportResult;
      _lastExportResult = result;
      _exportError = result.message;
      _requiresSourceReconciliation =
          result.outcome == ExportOutcome.sourceDrift;
      _requiresTransactionRecovery =
          result.outcome == ExportOutcome.rollbackIncomplete;
      return result;
    } catch (error, stackTrace) {
      _exportError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while exporting editor changes'),
        ),
      );
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Retries only canonical loading after committed writes; never exports again.
  Future<bool> retrySavedRefresh() async {
    final workspace = _workspace;
    if (!_requiresSavedRefresh ||
        workspace == null ||
        _isLoading ||
        _isExporting) {
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      return await _refreshSavedDocument(
        _pluginRegistry.requireById(_selectedPluginId),
        workspace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retries only the transaction's captured cleanup/rollback work. A failure
  /// keeps its original outcome and evidence; it never invokes plugin export.
  Future<bool> retryTransactionRecovery() async {
    final recovery = _lastExportResult?.recovery;
    if (!_requiresTransactionRecovery ||
        recovery == null ||
        _isLoading ||
        _isExporting) {
      return false;
    }
    _isExporting = true;
    notifyListeners();
    try {
      final result = await recovery.retry();
      _lastExportResult = result;
      _requiresTransactionRecovery = false;
      _exportError = result.outcome.isFailure ? result.message : null;
      if (result.applied && _workspace != null) {
        await _refreshSavedDocument(
          _pluginRegistry.requireById(_selectedPluginId),
          _workspace!,
        );
      }
      return true;
    } catch (error) {
      _recoveryError = '$error';
      return false;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  /// Reviews or reapplies semantic intent against a fresh canonical document.
  /// Every attempt reloads current sources, including after a conflict dialog,
  /// so a second external edit cannot be overwritten with an old review result.
  /// Unresolved conflicts and rejected commands leave the live origin untouched.
  Future<AuthoringReapplyPlan?> reapplyIntent({
    Map<String, AuthoringConflictChoice> resolutions = const {},
    bool reviewOnly = false,
  }) async {
    final original = _recoveryCopy ?? _document;
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    if (original == null ||
        plugin is! AuthoringIntentReconciliation ||
        _isLoading ||
        _isExporting ||
        _requiresSavedRefresh ||
        _requiresTransactionRecovery) {
      return null;
    }
    _recoveryCopy = original;
    _recoveryError = null;
    _isLoading = true;
    notifyListeners();
    try {
      final workspace = EditorWorkspace(rootPath: _workspacePath);
      final current = await plugin.loadFromRepo(workspace);
      final plan = (plugin as AuthoringIntentReconciliation).planReapply(
        current: current,
        original: original,
        resolutions: resolutions,
      );
      if (reviewOnly || plan.unresolvedPaths.isNotEmpty) return plan;
      var candidate = current;
      for (final command in plan.commands) {
        candidate = plugin.applyEdit(candidate, command);
        final rejected = plugin
            .validate(candidate)
            .where((issue) => issue.blocks(AuthoringOperation.save));
        if (rejected.isNotEmpty) {
          throw StateError(rejected.map((issue) => issue.message).join(' '));
        }
      }
      final blocking = plugin
          .validate(candidate)
          .where((issue) => issue.blocks(AuthoringOperation.save))
          .toList();
      if (blocking.isNotEmpty) {
        _recoveryError =
            'Retained edits still need correction: '
            '${blocking.map((issue) => issue.message).join(' ')}';
        return plan;
      }
      if (plugin is AuthoringSessionSemantics) {
        candidate = (plugin as AuthoringSessionSemantics).retainPresentation(
          current: _document ?? original,
          restored: candidate,
        );
      }
      _applyDocumentState(
        plugin: plugin,
        document: candidate,
        workspace: workspace,
        clearHistory: true,
      );
      if (_pendingChanges.hasChanges) _undoStack.add(current);
      _sourceGeneration++;
      _recoveryCopy = null;
      _requiresSourceReconciliation = false;
      return plan;
    } catch (error) {
      _recoveryError = 'Could not reconcile the retained edits: $error';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _refreshSavedDocument(
    AuthoringDomainPlugin plugin,
    EditorWorkspace workspace,
  ) async {
    final savedResult = _lastExportResult;
    try {
      final canonical = await plugin.loadFromRepo(workspace);
      final previous = _document;
      final presented = previous != null && plugin is AuthoringSessionSemantics
          ? (plugin as AuthoringSessionSemantics).retainPresentation(
              current: previous,
              restored: canonical,
            )
          : canonical;
      _applyDocumentState(
        plugin: plugin,
        document: presented,
        workspace: workspace,
        clearHistory: plugin is! AuthoringHistoryReconciliation,
      );
      if (plugin is AuthoringHistoryReconciliation) {
        final history = plugin as AuthoringHistoryReconciliation;
        for (final stack in [_undoStack, _redoStack]) {
          var cursor = presented;
          final retained = <AuthoringDocument>[];
          for (final historical in stack.reversed) {
            final reconciled = history.restoreContent(
              current: cursor,
              historical: historical,
            );
            if (reconciled == null) break;
            if (identical(reconciled, cursor)) continue;
            retained.add(historical);
            cursor = reconciled;
          }
          stack
            ..clear()
            ..addAll(retained.reversed);
        }
      }
      _sourceGeneration++;
      _requiresSourceReconciliation = false;
      _recoveryCopy = null;
      _recoveryError = null;
      _lastExportResult = savedResult;
      _requiresSavedRefresh = false;
      _refreshError = null;
      return true;
    } catch (error) {
      // The write already committed. Keep the originating document and exact
      // outcome; a normal failed-reload path would destroy the recovery context.
      _lastExportResult = savedResult;
      _refreshError = '$error';
      _requiresSavedRefresh = true;
      return false;
    }
  }

  AuthoringDocument? _restoreHistoryTarget(
    AuthoringDomainPlugin plugin,
    AuthoringDocument current,
    List<AuthoringDocument> stack,
  ) {
    while (stack.isNotEmpty) {
      final historical = stack.removeLast();
      if (plugin is! AuthoringHistoryReconciliation) return historical;
      final restored = (plugin as AuthoringHistoryReconciliation)
          .restoreContent(current: current, historical: historical);
      if (restored == null) {
        stack.clear();
        return null;
      }
      if (!identical(restored, current)) return restored;
    }
    return null;
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
    _coalescedUndoBaseDocument = null;
  }

  bool _commitCoalescedUndoStep() {
    final baseline = _coalescedUndoBaseDocument;
    if (baseline == null) {
      return false;
    }
    _undoStack.add(baseline);
    _coalescedUndoBaseDocument = null;
    return true;
  }

  /// Rebuilds the full derived session snapshot from one authoritative document.
  ///
  /// Validation issues, scene projection, pending changes, and transient export
  /// result state are all recomputed from the same document instance so routes
  /// never observe a mixed "old document / new scene" combination.
  void _applyDocumentState({
    required AuthoringDomainPlugin plugin,
    required AuthoringDocument document,
    EditorWorkspace? workspace,
    bool clearHistory = false,
  }) {
    final nextWorkspace = workspace ?? _workspace;
    final nextIssues = plugin.validate(document);
    final nextScene = plugin.buildEditableScene(document);
    final nextPending = nextWorkspace == null
        ? (changes: PendingChanges.empty, error: null)
        : _describePendingChanges(
            plugin,
            workspace: nextWorkspace,
            document: document,
          );
    // Document, issues, scene, and pending changes are a single derived
    // snapshot; update them together so listeners never observe a mixed state.
    _workspace = nextWorkspace;
    _document = document;
    _setIssues(nextIssues);
    _scene = nextScene;
    if (clearHistory) {
      _clearHistory();
    }
    _pendingChanges = nextPending.changes;
    _pendingChangesError = nextPending.error;
    _lastExportResult = null;
    _exportError = null;
  }

  void _setIssues(List<ValidationIssue> issues) {
    _issues = List<ValidationIssue>.unmodifiable(issues);
  }

  /// Clears loaded session state after a workspace/plugin context change.
  ///
  /// Both context changes also clear previous load/export errors because those
  /// messages are only meaningful for the old context.
  void _resetForContextChange({required bool clearWorkspace}) {
    _clearLoadedSessionState(clearWorkspace: clearWorkspace);
    _loadError = null;
    _exportError = null;
    _refreshError = null;
    _requiresSavedRefresh = false;
    _requiresTransactionRecovery = false;
    _requiresSourceReconciliation = false;
    _recoveryCopy = null;
    _recoveryError = null;
  }

  /// Drops the currently loaded document-derived snapshot.
  ///
  /// Used for failed reloads and destructive context changes. The workspace can
  /// optionally be preserved when only the plugin changes.
  void _clearLoadedSessionState({required bool clearWorkspace}) {
    if (clearWorkspace) {
      _workspace = null;
    }
    _document = null;
    _scene = null;
    _issues = const <ValidationIssue>[];
    _pendingChanges = PendingChanges.empty;
    _pendingChangesError = null;
    _lastExportResult = null;
    _clearHistory();
  }

  ({PendingChanges changes, String? error}) _describePendingChanges(
    AuthoringDomainPlugin plugin, {
    required EditorWorkspace workspace,
    required AuthoringDocument document,
  }) {
    try {
      // Pending-change computation is auxiliary UI state; on failure, keep the
      // loaded document usable and surface the error separately.
      final pendingChanges = plugin.describePendingChanges(
        workspace,
        document: document,
      );
      return (changes: pendingChanges, error: null);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription(
            'while computing pending authoring changes',
          ),
        ),
      );
      return (changes: PendingChanges.empty, error: '$error');
    }
  }
}
