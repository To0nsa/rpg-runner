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
