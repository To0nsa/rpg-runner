import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/authoring_types.dart';
import '../../../session/editor_session_controller.dart';

/// Implemented by route pages that keep authoring drafts outside the shared
/// [EditorSessionController].
///
/// This covers transient form/input state that would be lost on route changes
/// even though it has not been committed into the plugin-backed session yet.
abstract interface class EditorPageLocalDraftState {
  bool get hasLocalDraftChanges;
}

/// Implemented by route pages that need to participate in shell-level
/// undo/redo shortcuts.
///
/// Most pages can rely on direct [EditorSessionController.undo]/`redo` calls.
/// Pages with additional local projections of the session document can
/// implement this so the shell delegates shortcuts through page-specific sync
/// logic.
abstract interface class EditorPageSessionShortcutHandler {
  bool get canHandleUndoSessionShortcut;

  bool get canHandleRedoSessionShortcut;

  bool handleUndoSessionShortcut();

  bool handleRedoSessionShortcut();
}

/// Implemented by route pages that need the home shell to delegate reload
/// through page-owned coordination instead of directly calling the shared
/// session controller.
///
/// Most routes can reload by calling [EditorSessionController.loadWorkspace].
/// Pages that project extra local state over the controller, such as prefab
/// authoring, can implement this so shell-owned Reload/Save flows keep page
/// state and controller state in sync.
abstract interface class EditorPageReloadHandler {
  bool get canReloadEditorPage;

  Future<void> reloadEditorPage();
}

/// The result of resolving visible input and saving a route's source document.
///
/// A committed save whose refresh failed cannot authorize departure: the
/// retained page is still needed to reconcile its inputs against canonical data.
enum EditorPageSaveResult {
  saved,
  noChanges,
  blocked,
  failed,
  savedRefreshFailed;

  bool get permitsDeparture =>
      this == EditorPageSaveResult.saved ||
      this == EditorPageSaveResult.noChanges;

  /// Converts the session's completed export into a navigation-safe result.
  /// Callers must first resolve every local field or return [blocked].
  static EditorPageSaveResult fromSession(EditorSessionController controller) {
    if (controller.requiresSavedRefresh) return savedRefreshFailed;
    if (controller.exportError != null ||
        controller.requiresTransactionRecovery) {
      return failed;
    }
    final result = controller.lastExportResult;
    if (result == null) return blocked;
    if (result.outcome.isFailure) return failed;
    if (controller.pendingChanges.hasChanges) return blocked;
    return result.applied ? saved : noChanges;
  }
}

/// Implemented by routes whose Save action needs page-owned input validation
/// or post-export state reconciliation.
///
/// The home shell renders the common control, while this contract keeps
/// domain-specific safety checks and user feedback with the page that owns
/// them. Repository writes still flow through [EditorSessionController].
abstract interface class EditorPageSaveHandler {
  bool get canSaveEditorPage;

  Future<EditorPageSaveResult> saveEditorPage();
}

/// Friendly document-wide scope, including accepted edits and local input.
///
/// The page resolves opaque domain IDs to names; the shell displays this same
/// scope beside Save and before Save all/Discard all navigation decisions.
abstract interface class EditorPagePendingChangesSummary {
  String get pendingChangesSummary;

  List<String> get pendingChangeDescriptions;
}

/// Implemented by a route that temporarily owns shell shortcuts and locking.
///
/// The home shell remains the sole global keyboard/app-lifecycle listener. A
/// page receives commands only while its route is current and no modal or
/// editable text field owns the event.
abstract interface class EditorPagePlaytestHandler {
  /// Prevents route, Reload, Save, Undo, and redo transitions while true.
  bool get locksEditorShell;

  /// Handles one unmodified host key-down admitted by the home shell.
  bool handlePlaytestShortcut(LogicalKeyboardKey key);

  /// Cancels gameplay focus/input on app deactivation without auto-resume.
  void handlePlaytestAppLifecycleState(AppLifecycleState state);
}
