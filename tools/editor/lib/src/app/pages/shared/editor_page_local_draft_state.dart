/// Implemented by route pages that keep authoring drafts outside the shared
/// [EditorSessionController].
///
/// This covers transient form/input state that would be lost on route changes
/// even though it has not been committed into the plugin-backed session yet.
abstract interface class EditorPageLocalDraftState {
  bool get hasLocalDraftChanges;
}
