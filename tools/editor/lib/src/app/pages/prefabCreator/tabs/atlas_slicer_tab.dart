part of '../prefab_creator_page.dart';

extension _PrefabCreatorAtlasSlicerTab on _PrefabCreatorPageState {
  Widget _buildAtlasSlicerTab() {
    final selectionRect = _selectionRectInImagePixels();
    final selectionLabel = selectionRect == null
        ? 'Selection: none'
        : 'Selection: x=${selectionRect.left.toInt()} y=${selectionRect.top.toInt()} '
              'w=${selectionRect.width.toInt()} h=${selectionRect.height.toInt()}';
    final selectedAtlasPath = _selectedAtlasPath;
    final atlasSize = selectedAtlasPath == null
        ? null
        : _atlasImageSizes[selectedAtlasPath];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey<String?>(
                    'atlas_${selectedAtlasPath ?? 'none'}',
                  ),
                  initialValue: selectedAtlasPath,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Atlas/Tileset Source',
                  ),
                  items: [
                    for (final path in _atlasImagePaths)
                      DropdownMenuItem<String>(value: path, child: Text(path)),
                  ],
                  onChanged: (value) {
                    _updateState(() {
                      _selectedAtlasPath = value;
                      _clearSelection();
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<AtlasSliceKind>(
                  key: ValueKey<String>(
                    'slice_kind_${_selectedSliceKind.name}',
                  ),
                  initialValue: _selectedSliceKind,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice Kind',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AtlasSliceKind.prefab,
                      child: Text('Prefab Slice'),
                    ),
                    DropdownMenuItem(
                      value: AtlasSliceKind.tile,
                      child: Text('Tile Slice'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _updateState(() {
                      _selectedSliceKind = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sliceIdController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Slice ID',
                    hintText: 'village_crate_01 or ground_tile_01',
                  ),
                ),
                const SizedBox(height: 8),
                EditorZoomControls(
                  value: _atlasZoom,
                  min: _PrefabCreatorPageState._zoomMin,
                  max: _PrefabCreatorPageState._zoomMax,
                  step: _PrefabCreatorPageState._zoomStep,
                  onChanged: (value) {
                    _updateState(() {
                      _atlasZoom = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(selectionLabel),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _selectionXController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection X',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        onChanged: (_) =>
                            _applySelectionFromInputs(silent: true),
                        onSubmitted: (_) =>
                            _applySelectionFromInputs(silent: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _selectionYController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection Y',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        onChanged: (_) =>
                            _applySelectionFromInputs(silent: true),
                        onSubmitted: (_) =>
                            _applySelectionFromInputs(silent: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _selectionWController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection W',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        onChanged: (_) =>
                            _applySelectionFromInputs(silent: true),
                        onSubmitted: (_) =>
                            _applySelectionFromInputs(silent: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _selectionHController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Selection H',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        onChanged: (_) =>
                            _applySelectionFromInputs(silent: true),
                        onSubmitted: (_) =>
                            _applySelectionFromInputs(silent: true),
                      ),
                    ),
                  ],
                ),
                if (atlasSize != null)
                  Text(
                    'Atlas size: ${atlasSize.width.toInt()}x${atlasSize.height.toInt()} px',
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _addSliceFromSelection,
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Add Slice'),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedSliceKind == AtlasSliceKind.prefab
                      ? 'Prefab Slices'
                      : 'Tile Slices',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildSlicesTable(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildAtlasCanvas()),
      ],
    );
  }

  Widget _buildSlicesTable() {
    final slices = _selectedSliceKind == AtlasSliceKind.prefab
        ? _data.prefabSlices
        : _data.tileSlices;
    if (slices.isEmpty) {
      return const Text('No slices yet.');
    }
    return SizedBox(
      height: 320,
      child: ListView.builder(
        itemCount: slices.length,
        itemBuilder: (context, index) {
          final slice = slices[index];
          return Card(
            child: ListTile(
              dense: true,
              title: Text(slice.id),
              subtitle: Text(
                '${slice.sourceImagePath} '
                '[${slice.x},${slice.y},${slice.width},${slice.height}]',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteSlice(slice.id, _selectedSliceKind),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAtlasCanvas() {
    final selectedAtlasPath = _selectedAtlasPath;
    if (selectedAtlasPath == null) {
      return const Center(
        child: Text('Select an atlas/tileset image to start slicing.'),
      );
    }
    final atlasSize = _atlasImageSizes[selectedAtlasPath];
    if (atlasSize == null) {
      return const Center(child: Text('Loading atlas image metadata...'));
    }

    final root = widget.controller.workspacePath.trim();
    final absolutePath = p.normalize(p.join(root, selectedAtlasPath));
    final imageFile = File(absolutePath);
    if (!imageFile.existsSync()) {
      return Center(child: Text('Missing image: $selectedAtlasPath'));
    }

    final scaledWidth = atlasSize.width * _atlasZoom;
    final scaledHeight = atlasSize.height * _atlasZoom;

    final stack = SizedBox(
      width: scaledWidth,
      height: scaledHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.file(
              imageFile,
              width: scaledWidth,
              height: scaledHeight,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: EditorViewportGridPainter(zoom: _atlasZoom),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: AtlasSelectionPainter(
                  zoom: _atlasZoom,
                  selectionRectInImagePixels: _selectionRectInImagePixels(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Listener(
              onPointerSignal: _onAtlasPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  if (SceneInputUtils.isCtrlPressed()) {
                    _atlasCtrlPanActive = true;
                    return;
                  }
                  _updateState(() {
                    final start = _toImagePosition(
                      details.localPosition,
                      atlasSize,
                    );
                    _setSelectionFromPoints(start, start);
                  });
                },
                onPanUpdate: (details) {
                  if (_atlasCtrlPanActive || SceneInputUtils.isCtrlPressed()) {
                    SceneInputUtils.panScrollControllers(
                      horizontal: _atlasHorizontalScrollController,
                      vertical: _atlasVerticalScrollController,
                      pointerDelta: details.delta,
                    );
                    return;
                  }
                  _updateState(() {
                    final current = _toImagePosition(
                      details.localPosition,
                      atlasSize,
                    );
                    final start = _selectionStartImagePx ?? current;
                    _setSelectionFromPoints(start, current);
                  });
                },
                onPanEnd: (_) {
                  _atlasCtrlPanActive = false;
                  _updateState(() {
                    _selectionCurrentImagePx = _selectionCurrentImagePx;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B2A36)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: _atlasVerticalScrollController,
          child: SingleChildScrollView(
            controller: _atlasHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: stack,
          ),
        ),
      ),
    );
  }

  void _onAtlasPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final nextZoom =
        _atlasZoom + (signedSteps * _PrefabCreatorPageState._zoomStep);
    _updateState(() {
      _atlasZoom = nextZoom.clamp(
        _PrefabCreatorPageState._zoomMin,
        _PrefabCreatorPageState._zoomMax,
      );
    });
  }
}
