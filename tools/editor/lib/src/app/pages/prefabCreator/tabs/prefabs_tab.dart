part of '../prefab_creator_page.dart';

extension _PrefabCreatorPrefabsTab on _PrefabCreatorPageState {
  Widget _buildPrefabInspectorTab() {
    final prefabSlices = _data.prefabSlices;
    final prefabs = _data.prefabs;
    final selectedSliceId = _selectedPrefabSliceId;
    final selectedSlice = _findSliceById(
      slices: prefabSlices,
      sliceId: selectedSliceId,
    );
    final sceneValues = _prefabSceneValuesFromInputs();
    final workspaceRootPath = widget.controller.workspacePath.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prefabSlices.isEmpty)
                  const Text(
                    'No prefab slices yet. Create prefab slices in Atlas Slicer first.',
                  ),
                if (prefabSlices.isNotEmpty) ...[
                  TextField(
                    controller: _prefabIdController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Prefab ID',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'prefab_slice_${selectedSliceId ?? 'none'}',
                    ),
                    initialValue: selectedSliceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Slice',
                    ),
                    items: [
                      for (final slice in prefabSlices)
                        DropdownMenuItem<String>(
                          value: slice.id,
                          child: Text(slice.id),
                        ),
                    ],
                    onChanged: (value) {
                      _updateState(() {
                        _selectedPrefabSliceId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _anchorXController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Anchor X (px)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _anchorYController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Anchor Y (px)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Default Collider',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _colliderOffsetXController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Offset X',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _colliderOffsetYController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Offset Y',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _colliderWidthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Width',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _colliderHeightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Height',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _prefabTagsController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tags (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _upsertPrefabFromForm,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Add/Update Prefab'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildPrefabScenePanel(
                  workspaceRootPath: workspaceRootPath,
                  selectedSlice: selectedSlice,
                  sceneValues: sceneValues,
                ),
              ),
              const SizedBox(height: 12),
              Text('Prefabs', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: prefabs.isEmpty
                    ? const Text('No prefabs yet.')
                    : ListView.builder(
                        itemCount: prefabs.length,
                        itemBuilder: (context, index) {
                          final prefab = prefabs[index];
                          return Card(
                            child: ListTile(
                              title: Text(prefab.id),
                              subtitle: Text(
                                'slice=${prefab.sliceId} '
                                'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                'colliders=${prefab.colliders.length}',
                              ),
                              onTap: () => _loadPrefabIntoForm(prefab),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deletePrefab(prefab.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrefabScenePanel({
    required String workspaceRootPath,
    required AtlasSliceDef? selectedSlice,
    required PrefabSceneValues? sceneValues,
  }) {
    if (selectedSlice == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select a prefab slice to edit anchor/collider visually.',
              ),
            ),
          ),
        ),
      );
    }
    if (sceneValues == null) {
      return const Card(
        child: SizedBox(
          height: 210,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Anchor/collider fields contain invalid values. '
                'Fix them to enable scene editing.',
              ),
            ),
          ),
        ),
      );
    }
    return PrefabSceneView(
      workspaceRootPath: workspaceRootPath,
      slice: selectedSlice,
      values: sceneValues,
      onChanged: _onPrefabSceneValuesChanged,
    );
  }
}
