import 'package:flutter/foundation.dart';

import '../domain/authoring_plugin_registry.dart';
import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';

/// Orchestrates the active authoring session for the selected plugin/workspace.
///
/// Keeps the loaded document snapshot, derived scene, validation issues,
/// pending changes, and undo/redo history in sync so routes can treat the
/// controller as a coherent session boundary. Changing the workspace or plugin
/// invalidates the loaded snapshot instead of reusing potentially stale state.
class EditorSessionController extends ChangeNotifier {
  EditorSessionController({
    required AuthoringPluginRegistry pluginRegistry,
    required String initialPluginId,
    required String initialWorkspacePath,
  }) : _pluginRegistry = pluginRegistry,
       _selectedPluginId = initialPluginId,
       _workspacePath = initialWorkspacePath;

  final AuthoringPluginRegistry _pluginRegistry;
  String _selectedPluginId;
  String _workspacePath;

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

  List<AuthoringDomainPlugin> get availablePlugins => _pluginRegistry.all;

  String get selectedPluginId => _selectedPluginId;

  String get workspacePath => _workspacePath;

  bool get isLoading => _isLoading;
  bool get isExporting => _isExporting;

  String? get loadError => _loadError;
  String? get exportError => _exportError;

  EditorWorkspace? get workspace => _workspace;

  AuthoringDocument? get document => _document;

  EditableScene? get scene => _scene;

  List<ValidationIssue> get issues => _issues;
  PendingChanges get pendingChanges => _pendingChanges;
  String? get pendingChangesError => _pendingChangesError;
  ExportResult? get lastExportResult => _lastExportResult;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  Set<String> get dirtyItemIds =>
      Set<String>.unmodifiable(_pendingChanges.changedItemIds);

  int get errorCount => _issues
      .where((issue) => issue.severity == ValidationSeverity.error)
      .length;

  int get warningCount => _issues
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .length;

  void setWorkspacePath(String workspacePath) {
    final nextPath = workspacePath.trim();
    if (nextPath == _workspacePath) {
      return;
    }
    _workspacePath = nextPath;
    _resetForContextChange(clearWorkspace: true);
    notifyListeners();
  }

  void setSelectedPluginId(String pluginId) {
    if (_selectedPluginId == pluginId) {
      return;
    }
    _selectedPluginId = pluginId;
    _resetForContextChange(clearWorkspace: false);
    notifyListeners();
  }

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

  void applyCommand(AuthoringCommand command) {
    final document = _document;
    if (document == null) {
      return;
    }
    final plugin = _pluginRegistry.requireById(_selectedPluginId);
    final nextDocument = plugin.applyEdit(document, command);
    if (identical(nextDocument, document)) {
      return;
    }
    _undoStack.add(document);
    _redoStack.clear();
    _applyDocumentState(plugin: plugin, document: nextDocument);
    notifyListeners();
  }

  void undo() {
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

  void redo() {
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

  Future<void> exportDirectWrite() async {
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
      final result = await plugin.exportToRepo(
        workspace,
        document: document,
      );
      _lastExportResult = result;
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
  }

  void _applyDocumentState({
    required AuthoringDomainPlugin plugin,
    required AuthoringDocument document,
    EditorWorkspace? workspace,
    bool clearHistory = false,
  }) {
    if (workspace != null) {
      _workspace = workspace;
    }
    // Document, issues, scene, and pending changes are a single derived
    // snapshot; update them together so listeners never observe a mixed state.
    _document = document;
    _setIssues(plugin.validate(document));
    _scene = plugin.buildEditableScene(document);
    if (clearHistory) {
      _clearHistory();
    }
    _refreshPendingChanges(plugin);
    _lastExportResult = null;
    _exportError = null;
  }

  void _setIssues(List<ValidationIssue> issues) {
    _issues = List<ValidationIssue>.unmodifiable(issues);
  }

  void _resetForContextChange({required bool clearWorkspace}) {
    _clearLoadedSessionState(clearWorkspace: clearWorkspace);
    _loadError = null;
    _exportError = null;
  }

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

  void _refreshPendingChanges(AuthoringDomainPlugin plugin) {
    final workspace = _workspace;
    final document = _document;
    if (workspace == null || document == null) {
      _pendingChanges = PendingChanges.empty;
      _pendingChangesError = null;
      return;
    }

    try {
      // Pending-change computation is auxiliary UI state; on failure, keep the
      // loaded document usable and surface the error separately.
      _pendingChanges = plugin.describePendingChanges(
        workspace,
        document: document,
      );
      _pendingChangesError = null;
    } catch (error, stackTrace) {
      _pendingChanges = PendingChanges.empty;
      _pendingChangesError = '$error';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          context: ErrorDescription(
            'while computing pending authoring changes',
          ),
        ),
      );
    }
  }
}
