import 'package:flutter/material.dart';
import 'package:terrain_materials/terrain_materials.dart';

import '../../../atlas/atlas_grid_settings_cache.dart';
import '../../../atlas/atlas_grid.dart';
import '../../../atlas/atlas_pixel_rect.dart';
import '../../../workspace/repository_png_catalog.dart';
import '../shared/atlas_grid_controls.dart';
import '../shared/atlas_image_viewport.dart';
import '../shared/atlas_region_fields.dart';
import '../shared/atlas_selection_painter.dart';
import '../shared/editor_zoom_controls.dart';

/// Selects one exact inline terrain region without creating cropped files.
Future<TerrainMaterialImageRegion?> showTerrainAtlasRegionPicker(
  BuildContext context, {
  required String workspaceRootPath,
  required List<RepositoryPngImage> atlasImages,
  required AtlasGridSettingsCache gridSettingsCache,
  TerrainMaterialImageRegion? initialRegion,
  double? anchorX,
  double? anchorY,
  TerrainMaterialEdgeOrientation? edgeOrientation,
}) => showDialog<TerrainMaterialImageRegion>(
  context: context,
  builder: (context) => _TerrainAtlasRegionPicker(
    workspaceRootPath: workspaceRootPath,
    atlasImages: atlasImages,
    gridSettingsCache: gridSettingsCache,
    initialRegion: initialRegion,
    anchorX: anchorX,
    anchorY: anchorY,
    edgeOrientation: edgeOrientation,
  ),
);

class _TerrainAtlasRegionPicker extends StatefulWidget {
  const _TerrainAtlasRegionPicker({
    required this.workspaceRootPath,
    required this.atlasImages,
    required this.gridSettingsCache,
    required this.initialRegion,
    required this.anchorX,
    required this.anchorY,
    required this.edgeOrientation,
  });

  final String workspaceRootPath;
  final List<RepositoryPngImage> atlasImages;
  final AtlasGridSettingsCache gridSettingsCache;
  final TerrainMaterialImageRegion? initialRegion;
  final double? anchorX;
  final double? anchorY;
  final TerrainMaterialEdgeOrientation? edgeOrientation;

  @override
  State<_TerrainAtlasRegionPicker> createState() =>
      _TerrainAtlasRegionPickerState();
}

class _TerrainAtlasRegionPickerState extends State<_TerrainAtlasRegionPicker> {
  static const double _zoomMin = 0.2;
  static const double _zoomMax = 24;
  static const double _zoomStep = 0.2;

  final TextEditingController _x = TextEditingController();
  final TextEditingController _y = TextEditingController();
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();
  String? _selectedPath;
  AtlasPixelRect? _selection;
  double _zoom = 2;
  bool _autoSliceEnabled = true;
  String? _manualError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRegion;
    final paths = widget.atlasImages.map((image) => image.relativePath).toSet();
    _selectedPath = initial != null && paths.contains(initial.assetPath)
        ? initial.assetPath
        : widget.atlasImages.firstOrNull?.relativePath;
    if (initial != null && _selectedPath == initial.assetPath) {
      _setSelection(
        AtlasPixelRect(
          x: initial.x,
          y: initial.y,
          width: initial.width,
          height: initial.height,
        ),
      );
    }
  }

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _width.dispose();
    _height.dispose();
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _selectedImage;
    final dimensionsValid = image?.hasValidDimensions ?? false;
    return AlertDialog(
      key: const ValueKey<String>('terrain_atlas_region_picker'),
      title: const Text('Select terrain atlas region'),
      content: SizedBox(
        width: 1080,
        height: 700,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 290,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const ValueKey<String>('terrain_atlas_source'),
                      initialValue: _selectedPath,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Terrain atlas',
                      ),
                      items: [
                        for (final atlas in widget.atlasImages)
                          DropdownMenuItem<String>(
                            value: atlas.relativePath,
                            child: Text(
                              atlas.relativePath,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _selectSource,
                    ),
                    const SizedBox(height: 12),
                    EditorZoomControls(
                      value: _zoom,
                      min: _zoomMin,
                      max: _zoomMax,
                      step: _zoomStep,
                      fieldWidth: 80,
                      sliderWidth: 190,
                      onChanged: (value) => setState(() => _zoom = value),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      key: const ValueKey<String>(
                        'terrain_atlas_auto_slice_toggle',
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-slice grid'),
                      value: _autoSliceEnabled,
                      onChanged: (value) =>
                          setState(() => _autoSliceEnabled = value),
                    ),
                    if (_autoSliceEnabled && _selectedPath != null) ...[
                      const SizedBox(height: 8),
                      AtlasGridControls(
                        keyPrefix: 'terrain_atlas_grid',
                        settings: widget.gridSettingsCache.settingsFor(
                          _selectedPath!,
                        ),
                        onChanged: (settings) => setState(
                          () => widget.gridSettingsCache.setSettings(
                            _selectedPath!,
                            settings,
                          ),
                        ),
                      ),
                      if (dimensionsValid && _gridHasNoCompleteCells(image!))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'This grid has no complete cells. Manual X/Y/W/H '
                            'selection remains available.',
                            key: const ValueKey<String>(
                              'terrain_atlas_empty_grid',
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    AtlasRegionFields(
                      keyPrefix: 'terrain_atlas_region',
                      xController: _x,
                      yController: _y,
                      widthController: _width,
                      heightController: _height,
                      onChanged: _applyManualSelection,
                    ),
                    if (_manualError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _manualError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: image == null
                  ? const Center(
                      child: Text(
                        'No PNGs found under assets/images/terrain/.',
                      ),
                    )
                  : !dimensionsValid
                  ? Center(
                      child: Text(
                        'Could not read PNG dimensions for '
                        '${image.relativePath}.',
                      ),
                    )
                  : AtlasImageViewport(
                      workspaceRootPath: widget.workspaceRootPath,
                      sourceImagePath: image.relativePath,
                      imageWidth: image.width!,
                      imageHeight: image.height!,
                      zoom: _zoom,
                      zoomMin: _zoomMin,
                      zoomMax: _zoomMax,
                      zoomStep: _zoomStep,
                      autoSliceEnabled: _autoSliceEnabled,
                      gridSettings: widget.gridSettingsCache.settingsFor(
                        image.relativePath,
                      ),
                      selection: _selection,
                      guides: _anchorGuides,
                      horizontalScrollController: _horizontal,
                      verticalScrollController: _vertical,
                      onZoomChanged: (value) => setState(() => _zoom = value),
                      onSelectionChanged: (rect) =>
                          setState(() => _setSelection(rect)),
                      canvasKey: const ValueKey<String>(
                        'terrain_atlas_region_canvas',
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('terrain_atlas_region_assign'),
          onPressed: dimensionsValid && _selection != null
              ? _assignSelection
              : null,
          child: const Text('Assign'),
        ),
      ],
    );
  }

  RepositoryPngImage? get _selectedImage {
    for (final image in widget.atlasImages) {
      if (image.relativePath == _selectedPath) return image;
    }
    return null;
  }

  List<AtlasGuideOverlay> get _anchorGuides {
    final rect = _selection;
    final anchorY = widget.anchorY;
    if (rect == null || anchorY == null) return const <AtlasGuideOverlay>[];
    final anchorX = widget.anchorX;
    if (anchorX != null) {
      final validY = anchorY >= 0 && anchorY <= rect.height;
      return <AtlasGuideOverlay>[
        AtlasGuideOverlay.point(
          position: Offset(rect.x + anchorX, rect.y + anchorY),
          isValid: validY && anchorX >= 0 && anchorX <= rect.width,
        ),
      ];
    }
    final orientation = widget.edgeOrientation;
    if (orientation != null) {
      final maximum = terrainMaterialEdgeTileHeight(
        orientation: orientation,
        sourceWidth: rect.width,
        sourceHeight: rect.height,
      );
      final isValid = anchorY >= 0 && anchorY <= maximum;
      final guide = switch (orientation) {
        TerrainMaterialEdgeOrientation.top => (
          start: Offset(rect.x.toDouble(), rect.y + anchorY),
          end: Offset(rect.right.toDouble(), rect.y + anchorY),
        ),
        TerrainMaterialEdgeOrientation.leftWall => (
          start: Offset(rect.x + anchorY, rect.y.toDouble()),
          end: Offset(rect.x + anchorY, rect.bottom.toDouble()),
        ),
        TerrainMaterialEdgeOrientation.rightWall => (
          start: Offset(rect.right - anchorY, rect.y.toDouble()),
          end: Offset(rect.right - anchorY, rect.bottom.toDouble()),
        ),
        TerrainMaterialEdgeOrientation.underside => (
          start: Offset(rect.x.toDouble(), rect.bottom - anchorY),
          end: Offset(rect.right.toDouble(), rect.bottom - anchorY),
        ),
      };
      return <AtlasGuideOverlay>[
        AtlasGuideOverlay.line(
          start: guide.start,
          end: guide.end,
          isValid: isValid,
        ),
      ];
    }
    final validY = anchorY >= 0 && anchorY <= rect.height;
    return <AtlasGuideOverlay>[
      AtlasGuideOverlay.line(
        start: Offset(rect.x.toDouble(), rect.y + anchorY),
        end: Offset(rect.right.toDouble(), rect.y + anchorY),
        isValid: validY,
      ),
    ];
  }

  bool _gridHasNoCompleteCells(RepositoryPngImage image) {
    final settings = widget.gridSettingsCache.settingsFor(image.relativePath);
    return AtlasGridGeometry.completeColumnCount(
              settings: settings,
              imageWidth: image.width!,
            ) ==
            0 ||
        AtlasGridGeometry.completeRowCount(
              settings: settings,
              imageHeight: image.height!,
            ) ==
            0;
  }

  void _selectSource(String? path) {
    setState(() {
      _selectedPath = path;
      _selection = null;
      _manualError = null;
      _syncFields(null);
    });
  }

  void _applyManualSelection() {
    final image = _selectedImage;
    if (image == null || !image.hasValidDimensions) return;
    final result = parseAtlasPixelRect(
      rawX: _x.text,
      rawY: _y.text,
      rawWidth: _width.text,
      rawHeight: _height.text,
      imageWidth: image.width!,
      imageHeight: image.height!,
    );
    setState(() {
      _manualError = result.error;
      _selection = result.rect;
    });
  }

  void _setSelection(AtlasPixelRect rect) {
    _selection = rect;
    _manualError = null;
    _syncFields(rect);
  }

  void _syncFields(AtlasPixelRect? rect) {
    _x.text = rect?.x.toString() ?? '';
    _y.text = rect?.y.toString() ?? '';
    _width.text = rect?.width.toString() ?? '';
    _height.text = rect?.height.toString() ?? '';
  }

  void _assignSelection() {
    final path = _selectedPath;
    final rect = _selection;
    if (path == null || rect == null) return;
    Navigator.of(context).pop(
      TerrainMaterialImageRegion(
        assetPath: path,
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: rect.height,
      ),
    );
  }
}
