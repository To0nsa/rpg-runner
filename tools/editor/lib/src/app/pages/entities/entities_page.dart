part of 'entities_editor_page.dart';

extension _EntitiesPage on _EntitiesEditorPageState {
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
