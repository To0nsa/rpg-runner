import 'package:flutter/foundation.dart';

import '../entities/entity_domain_models.dart';
import '../domain/authoring_plugin_registry.dart';
import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';

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
  PendingChanges _pendingChanges = const PendingChanges();
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
  bool get hasUnsavedChanges => _pendingChanges.hasChanges;
  Set<String> get dirtyItemIds =>
      Set<String>.unmodifiable(_pendingChanges.changedItemIds);
  int get dirtyItemCount => _pendingChanges.changedItemIds.length;
  int get dirtyFileCount => _pendingChanges.fileDiffs.length;

  EntityScene? get entityScene =>
      _scene is EntityScene ? _scene as EntityScene : null;

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
    _workspace = null;
    _document = null;
    _scene = null;
    _issues = const <ValidationIssue>[];
    _pendingChanges = const PendingChanges();
    _pendingChangesError = null;
    _loadError = null;
    _exportError = null;
    _lastExportResult = null;
    _clearHistory();
    notifyListeners();
  }

  void setSelectedPluginId(String pluginId) {
    if (_selectedPluginId == pluginId) {
      return;
    }
    _selectedPluginId = pluginId;
    _clearHistory();
    _scene = null;
    _document = null;
    _issues = const <ValidationIssue>[];
    _pendingChanges = const PendingChanges();
    _pendingChangesError = null;
    _loadError = null;
    _lastExportResult = null;
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
      final issues = plugin.validate(document);
      final scene = plugin.buildEditableScene(document);

      _workspace = workspace;
      _document = document;
      _issues = issues;
      _scene = scene;
      _lastExportResult = null;
      _exportError = null;
      _clearHistory();
      _refreshPendingChanges(plugin);
    } catch (error, stackTrace) {
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
    _document = nextDocument;
    _issues = plugin.validate(nextDocument);
    _scene = plugin.buildEditableScene(nextDocument);
    _refreshPendingChanges(plugin);
    _lastExportResult = null;
    _exportError = null;
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
    _document = previous;
    _issues = plugin.validate(previous);
    _scene = plugin.buildEditableScene(previous);
    _refreshPendingChanges(plugin);
    _lastExportResult = null;
    _exportError = null;
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
    _document = next;
    _issues = plugin.validate(next);
    _scene = plugin.buildEditableScene(next);
    _refreshPendingChanges(plugin);
    _lastExportResult = null;
    _exportError = null;
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

  void _refreshPendingChanges(AuthoringDomainPlugin plugin) {
    final workspace = _workspace;
    final document = _document;
    if (workspace == null || document == null) {
      _pendingChanges = const PendingChanges();
      _pendingChangesError = null;
      return;
    }

    try {
      _pendingChanges = plugin.describePendingChanges(
        workspace,
        document: document,
      );
      _pendingChangesError = null;
    } catch (error, stackTrace) {
      _pendingChanges = const PendingChanges();
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
