part of '../prefab_creator_page.dart';

extension _PrefabCreatorPrefabsTab on _PrefabCreatorPageState {
  Widget _buildPrefabInspectorTab() {
    final prefabSlices = _data.prefabSlices;
    final obstaclePrefabs = _data.prefabs
        .where((prefab) => prefab.kind == PrefabKind.obstacle)
        .toList(growable: false);
    final selectedSlice = _findSliceById(
      slices: prefabSlices,
      sliceId: _selectedPrefabSliceId,
    );
    final sceneValues = _prefabSceneValuesFromInputs();
    final editingPrefab = _editingPrefab();
    final editingObstaclePrefab =
        editingPrefab != null && editingPrefab.kind == PrefabKind.obstacle
        ? editingPrefab
        : null;
    final workspaceRootPath = widget.controller.workspacePath.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: _buildObstaclePrefabScenePanel(
                  workspaceRootPath: workspaceRootPath,
                  selectedSlice: selectedSlice,
                  sceneValues: sceneValues,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Obstacle Prefabs',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 1,
                child: obstaclePrefabs.isEmpty
                    ? const Text('No obstacle prefabs yet.')
                    : ListView.builder(
                        itemCount: obstaclePrefabs.length,
                        itemBuilder: (context, index) {
                          final prefab = obstaclePrefabs[index];
                          return Card(
                            child: ListTile(
                              title: Text(prefab.id),
                              subtitle: Text(
                                'key=${prefab.prefabKey} '
                                'rev=${prefab.revision} '
                                'status=${prefab.status.jsonValue} '
                                'source=atlas_slice:${prefab.sliceId} '
                                'anchor=(${prefab.anchorXPx},${prefab.anchorYPx}) '
                                'colliders=${prefab.colliders.length} '
                                'z=${prefab.zIndex} '
                                'snap=${prefab.snapToGrid}',
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
        const SizedBox(width: 12),
        SizedBox(
          width: 420,
          child: _buildObstaclePrefabInspectorPanel(
            prefabSlices: prefabSlices,
            selectedSliceId: _selectedPrefabSliceId,
            editingObstaclePrefab: editingObstaclePrefab,
          ),
        ),
      ],
    );
  }

  Widget _buildObstaclePrefabInspectorPanel({
    required List<AtlasSliceDef> prefabSlices,
    required String? selectedSliceId,
    required PrefabDef? editingObstaclePrefab,
  }) {
    final hasObstacleSources = prefabSlices.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasObstacleSources)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No prefab slices yet. Obstacle prefabs require atlas slices.',
                ),
              ),
            if (editingObstaclePrefab != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Editing key=${editingObstaclePrefab.prefabKey} '
                  'rev=${editingObstaclePrefab.revision} '
                  'status=${editingObstaclePrefab.status.jsonValue}',
                ),
              ),
            TextField(
              controller: _prefabIdController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prefab ID',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visual Source',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            hasObstacleSources
                ? DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'prefab_slice_${selectedSliceId ?? 'none'}',
                    ),
                    initialValue: selectedSliceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Atlas Slice',
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
                  )
                : const Text('Create prefab atlas slices first.'),
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
              controller: _prefabZIndexController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Z Index',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _prefabSnapToGrid,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateState(() {
                  _prefabSnapToGrid = value;
                });
              },
              title: const Text('Snap To Grid'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prefabTagsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tags (comma separated)',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _upsertObstaclePrefabFromForm,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add/Update Prefab'),
                ),
                OutlinedButton.icon(
                  onPressed: _duplicateLoadedObstaclePrefab,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Duplicate'),
                ),
                OutlinedButton.icon(
                  onPressed: _deprecateLoadedObstaclePrefab,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Deprecate'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearPrefabForm,
                  icon: const Icon(Icons.clear_outlined),
                  label: const Text('Clear Form'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObstaclePrefabScenePanel({
    required String workspaceRootPath,
    required AtlasSliceDef? selectedSlice,
    required PrefabSceneValues? sceneValues,
  }) {
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

    return PrefabSceneView(
      workspaceRootPath: workspaceRootPath,
      slice: selectedSlice,
      values: sceneValues,
      onChanged: _onPrefabSceneValuesChanged,
    );
  }

  void _upsertObstaclePrefabFromForm() {
    _updateState(() {
      _selectedPrefabKind = PrefabKind.obstacle;
    });
    _upsertPrefabFromForm();
  }

  void _duplicateLoadedObstaclePrefab() {
    final source = _editingPrefab();
    if (source == null || source.kind != PrefabKind.obstacle) {
      _setError('Load an obstacle prefab before duplicating.');
      return;
    }
    _duplicateLoadedPrefab();
  }

  void _deprecateLoadedObstaclePrefab() {
    final source = _editingPrefab();
    if (source == null || source.kind != PrefabKind.obstacle) {
      _setError('Load an obstacle prefab before deprecating.');
      return;
    }
    _deprecateLoadedPrefab();
  }
}
