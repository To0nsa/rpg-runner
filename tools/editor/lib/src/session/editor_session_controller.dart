import 'package:flutter/foundation.dart';

import '../domain/authoring_plugin_registry.dart';
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

  /// All registered domain plugins available for route/session selection.
  List<AuthoringDomainPlugin> get availablePlugins => _pluginRegistry.all;

  /// Active plugin id whose document/scene contract this session currently uses.
  String get selectedPluginId => _selectedPluginId;

  /// Workspace root path set when this editor session starts.
  String get workspacePath => _workspacePath;

  /// True while a normal reload or guarded plugin transition is resolving a
  /// repository document.
  bool get isLoading => _isLoading;

  /// True while [exportDirectWrite] is running plugin-owned repository writes.
  bool get isExporting => _isExporting;

  /// Last load failure for the current context, if any.
  String? get loadError => _loadError;

  /// Last export failure for the current loaded document, if any.
  String? get exportError => _exportError;

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

  /// Number of validation issues at warning severity in [issues].
  int get warningCount => _issues
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .length;

  /// Switches the active plugin contract and invalidates the loaded document.
  ///
  /// The workspace path is preserved, but the current document/scene/history are
  /// dropped because they are only valid for the previously selected plugin.
  void setSelectedPluginId(String pluginId) {
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
    if (_isLoading) {
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
    if (_isLoading || _isExporting) {
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

  /// Applies a command that should be merged into one pending undo step.
  ///
  /// Intended for high-frequency interactions (for example pointer drags)
  /// where each intermediate value should update the document, but undo should
  /// roll back the whole interaction as one operation.
  void applyCoalescedCommand(AuthoringCommand command) {
    _applyCommand(command, coalesceUndo: true);
  }

  void _applyCommand(AuthoringCommand command, {required bool coalesceUndo}) {
    final document = _document;
    if (document == null) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final nextDocument = plugin.applyEdit(document, command);
    if (identical(nextDocument, document)) {
      return;
    }
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
    _commitCoalescedUndoStep();
    final document = _document;
    if (document == null || _undoStack.isEmpty) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final previous = _undoStack.removeLast();
    _redoStack.add(document);
    _applyDocumentState(plugin: plugin, document: previous);
    notifyListeners();
  }

  /// Reapplies the next committed document snapshot after an [undo], if any.
  void redo() {
    _commitCoalescedUndoStep();
    final document = _document;
    if (document == null || _redoStack.isEmpty) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final next = _redoStack.removeLast();
    _undoStack.add(document);
    _applyDocumentState(plugin: plugin, document: next);
    notifyListeners();
  }

  /// Exports the current [document] through the active plugin.
  ///
  /// When the plugin reports that files were written, the controller reloads
  /// from disk so the session reflects canonical persisted output rather than
  /// assuming the in-memory document matches post-export repository state.
  Future<void> exportDirectWrite() async {
    _commitCoalescedUndoStep();
    final document = _document;
    final workspace = _workspace;
    if (document == null || workspace == null || _isExporting) {
      return;
    }
    _isExporting = true;
    _exportError = null;
    notifyListeners();
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    try {
      final result = await plugin.exportToRepo(workspace, document: document);
      _lastExportResult = result;
      if (result.outcome.isFailure) {
        _exportError = result.message ?? 'The export was rejected.';
      }
      if (result.applied) {
        // Reload from disk so the session reflects the plugin's persisted
        // output instead of assuming the in-memory document is authoritative.
        await loadWorkspace();
        _lastExportResult = result;
      }
    } catch (error, stackTrace) {
      _exportError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription('while exporting editor changes'),
        ),
      );
    } finally {
      _isExporting = false;
      notifyListeners();
    }
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
