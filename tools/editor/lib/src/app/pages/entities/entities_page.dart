part of 'entities_editor_page.dart';

/// Composes the entities route shell from already-prepared page/controller
/// state.
///
/// This extension is intentionally layout-only: it does not mutate authoring
/// data and delegates behavior to scene/state/panel helpers owned by sibling
/// parts.
extension _EntitiesPage on _EntitiesEditorPageState {
  /// Builds the two-band entities workspace.
  ///
  /// Top band: viewport + inspector + entry list.
  /// Bottom band: validation + pending diff + last apply result.
  Widget _buildEntitiesPage(
    EntityScene? entityScene,
    List<EntityEntry> visibleEntries,
  ) {
    final error = widget.controller.loadError;
    if (error != null) {
      return _ErrorPanel(message: error);
    }
    if (widget.controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entityScene == null) {
      return const Center(child: Text('No scene loaded.'));
    }

    final selectedEntry = _selectedEntry(entityScene);

    return Column(
      children: [
        // Primary authoring surface gets most vertical space so viewport and
        // inspector remain usable on common laptop resolutions.
        Expanded(
          flex: 4,
          child: ClipRect(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRect(child: _buildViewportPanel(selectedEntry)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: ClipRect(child: _buildInspector(selectedEntry)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: ClipRect(
                    child: _buildEntryListPanel(
                      scene: entityScene,
                      visibleEntries: visibleEntries,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Status/diagnostic band is intentionally compact but always visible
        // to keep validation and export feedback in-view during editing.
        Expanded(
          flex: 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildValidationPanel()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildPendingDiffPanel()),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildApplyResultPanel()),
            ],
          ),
        ),
      ],
    );
  }
}
