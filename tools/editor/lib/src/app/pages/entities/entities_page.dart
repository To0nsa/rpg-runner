part of '../home/editor_home_page.dart';

extension _EntitiesPage on _EditorHomePageState {
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildViewportPanel(selectedEntry),
                const SizedBox(height: 12),
                _buildInspector(selectedEntry),
                const SizedBox(height: 12),
                SizedBox(height: 180, child: _buildValidationPanel()),
                const SizedBox(height: 12),
                SizedBox(height: 300, child: _buildPendingDiffPanel()),
                const SizedBox(height: 12),
                SizedBox(height: 230, child: _buildExportPanel()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 5,
          child: _buildEntryListPanel(
            scene: entityScene,
            visibleEntries: visibleEntries,
          ),
        ),
      ],
    );
  }
}
