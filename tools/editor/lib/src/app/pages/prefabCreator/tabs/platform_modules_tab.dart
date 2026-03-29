part of '../prefab_creator_page.dart';

extension _PrefabCreatorPlatformModulesTab on _PrefabCreatorPageState {
  Widget _buildPlatformModulesTab() {
    final tileSlices = _data.tileSlices;
    final modules = _data.platformModules;
    final selectedModule = _selectedModule();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _moduleIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Platform Module ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _moduleTileSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Tile Size (px)',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _upsertModuleFromForm,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add/Update Module'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'module_${_selectedModuleId ?? 'none'}',
                  ),
                  initialValue: _selectedModuleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Edit Module',
                  ),
                  items: [
                    for (final module in modules)
                      DropdownMenuItem<String>(
                        value: module.id,
                        child: Text(module.id),
                      ),
                  ],
                  onChanged: (value) {
                    _updateState(() {
                      _selectedModuleId = value;
                      if (value != null) {
                        final module = modules.firstWhere((m) => m.id == value);
                        _moduleIdController.text = module.id;
                        _moduleTileSizeController.text = module.tileSize
                            .toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (tileSlices.isEmpty)
                  const Text(
                    'No tile slices yet. Create tile slices in Atlas Slicer first.',
                  ),
                if (tileSlices.isNotEmpty && selectedModule != null) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'tile_slice_${_selectedTileSliceId ?? 'none'}',
                    ),
                    initialValue: _selectedTileSliceId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Tile Slice',
                    ),
                    items: [
                      for (final slice in tileSlices)
                        DropdownMenuItem<String>(
                          value: slice.id,
                          child: Text(slice.id),
                        ),
                    ],
                    onChanged: (value) {
                      _updateState(() {
                        _selectedTileSliceId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _moduleCellGridXController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Grid X',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _moduleCellGridYController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Grid Y',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _addCellToSelectedModule,
                    icon: const Icon(Icons.grid_on_outlined),
                    label: const Text('Add Cell'),
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
              Text(
                'Platform Modules',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: modules.isEmpty
                    ? const Text('No platform modules yet.')
                    : ListView.builder(
                        itemCount: modules.length,
                        itemBuilder: (context, index) {
                          final module = modules[index];
                          return Card(
                            child: ExpansionTile(
                              title: Text(module.id),
                              subtitle: Text(
                                'tileSize=${module.tileSize} '
                                'cells=${module.cells.length}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteModule(module.id),
                              ),
                              children: [
                                if (module.cells.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('No cells yet.'),
                                    ),
                                  ),
                                for (var i = 0; i < module.cells.length; i += 1)
                                  ListTile(
                                    dense: true,
                                    title: Text(module.cells[i].sliceId),
                                    subtitle: Text(
                                      'x=${module.cells[i].gridX} y=${module.cells[i].gridY}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteModuleCell(
                                        moduleId: module.id,
                                        cellIndex: i,
                                      ),
                                    ),
                                  ),
                              ],
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
}
