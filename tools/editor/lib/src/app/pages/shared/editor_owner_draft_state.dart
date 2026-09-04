/// Transient create/edit/rename state shared by owner-based editor routes.
///
/// This object deliberately owns no widgets, commands, or repository state.
/// Routes decide when navigation must resolve a draft and wrap mutations in
/// their own rebuild mechanism.
final class EditorOwnerDraftState<TOwner, TCreateSource> {
  TOwner? _editSource;
  bool _editDirty = false;
  bool _renameActive = false;
  bool _createExpanded = false;
  bool _createDirty = false;
  TCreateSource? _createSource;

  TOwner? get editSource => _editSource;
  bool get editDirty => _editDirty;
  bool get renameActive => _renameActive;
  bool get createExpanded => _createExpanded;
  bool get createDirty => _createDirty;
  TCreateSource? get createSource => _createSource;

  /// Whether either mounted form has unresolved user input.
  bool get hasDirtyDraft => _editDirty || _createDirty;

  /// Opens a clean edit draft for [source], replacing any resolved edit state.
  void beginEdit(TOwner source) {
    _editSource = source;
    _editDirty = false;
    _renameActive = false;
  }

  /// Enters rename mode only from a clean, open edit draft.
  ///
  /// Returns false without mutation when that invariant is not satisfied.
  bool beginRename() {
    if (_editSource == null || _editDirty || _renameActive) return false;
    _renameActive = true;
    return true;
  }

  /// Leaves rename mode and restores the clean edit-draft invariant.
  ///
  /// Returns whether state changed.
  bool cancelRename() {
    if (!_renameActive) return false;
    _renameActive = false;
    _editDirty = false;
    return true;
  }

  /// Updates edit dirtiness and returns whether state changed.
  bool setEditDirty(bool dirty) {
    if (_editDirty == dirty) return false;
    _editDirty = dirty;
    return true;
  }

  /// Closes the edit and rename drafts and returns whether state changed.
  bool clearEdit() {
    if (_editSource == null && !_editDirty && !_renameActive) return false;
    _editSource = null;
    _editDirty = false;
    _renameActive = false;
    return true;
  }

  /// Opens creation UI; [source] may be absent for a guidance-only empty state.
  void expandCreate([TCreateSource? source]) {
    _createExpanded = true;
    _createSource = source;
  }

  /// Updates creation dirtiness and returns whether state changed.
  bool setCreateDirty(bool dirty) {
    if (_createDirty == dirty) return false;
    _createDirty = dirty;
    return true;
  }

  /// Closes the creation draft and returns whether state changed.
  bool clearCreate() {
    if (!_createExpanded && !_createDirty && _createSource == null) {
      return false;
    }
    _createExpanded = false;
    _createDirty = false;
    _createSource = null;
    return true;
  }

  /// Clears every route-local draft after a session/document replacement.
  void reset() {
    clearEdit();
    clearCreate();
  }
}
