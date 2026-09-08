import 'package:flutter/material.dart';

import '../../../../atlas/atlas_grid.dart';
import '../../../../atlas/atlas_pixel_rect.dart';
import '../../../../prefabs/domain/atlas_slice_id_convention.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/atlas_grid_controls.dart';
import '../../shared/atlas_image_viewport.dart';
import '../../shared/atlas_region_fields.dart';
import '../../shared/atlas_region_preview_tile.dart';
import '../../shared/atlas_selection_painter.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_panel_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_zoom_controls.dart';
import '../shared/ui/prefab_editor_action_row.dart';
import '../shared/ui/prefab_editor_empty_state.dart';
import '../shared/ui/prefab_editor_panel_summary.dart';
import '../shared/ui/prefab_editor_row_metadata.dart';
import '../shared/ui/prefab_editor_three_panel_layout.dart';

/// Atlas slicing view for prefab and tile source rectangles.
class AtlasSlicerTab extends StatefulWidget {
  const AtlasSlicerTab({
    super.key,
    required this.selectedAtlasPath,
    required this.selectedSliceKind,
    required this.sliceIdController,
    required this.sliceTagsController,
    required this.sliceIdValidationMessage,
    required this.createCorrespondingOwnerAutomatically,
    required this.correspondingPrefabKind,
    required this.atlasZoom,
    required this.zoomMin,
    required this.zoomMax,
    required this.zoomStep,
    required this.selectionXController,
    required this.selectionYController,
    required this.selectionWController,
    required this.selectionHController,
    required this.atlasSize,
    required this.slices,
    required this.existingSliceIds,
    required this.selectedSliceId,
    required this.selectedSlice,
    required this.workspaceRootPath,
    required this.selectionRectInImagePixels,
    required this.autoSliceEnabled,
    required this.gridSettings,
    required this.horizontalScrollController,
    required this.verticalScrollController,
    required this.onBrowseAtlasSource,
    required this.onSelectedSliceKindChanged,
    required this.onSelectedSliceChanged,
    required this.onCreateCorrespondingOwnerAutomaticallyChanged,
    required this.onCorrespondingPrefabKindChanged,
    required this.onAtlasZoomChanged,
    required this.onSelectionInputsChanged,
    required this.onAutoSliceEnabledChanged,
    required this.onGridSettingsChanged,
    required this.onSaveSlice,
    required this.onCancelSliceDraft,
    required this.onStartNewSlice,
    required this.onDeleteSlice,
    required this.onSelectionChanged,
    required this.hasLocalDraftChanges,
  });

  final String? selectedAtlasPath;
  final AtlasSliceKind selectedSliceKind;
  final TextEditingController sliceIdController;
  final TextEditingController sliceTagsController;
  final String? Function(String id) sliceIdValidationMessage;
  final bool createCorrespondingOwnerAutomatically;
  final PrefabKind correspondingPrefabKind;
  final double atlasZoom;
  final double zoomMin;
  final double zoomMax;
  final double zoomStep;
  final TextEditingController selectionXController;
  final TextEditingController selectionYController;
  final TextEditingController selectionWController;
  final TextEditingController selectionHController;
  final Size? atlasSize;
  final List<AtlasSliceDef> slices;
  final Set<String> existingSliceIds;
  final String? selectedSliceId;
  final AtlasSliceDef? selectedSlice;
  final String workspaceRootPath;
  final AtlasPixelRect? selectionRectInImagePixels;
  final bool autoSliceEnabled;
  final AtlasGridSettings gridSettings;
  final ScrollController horizontalScrollController;
  final ScrollController verticalScrollController;
  final VoidCallback onBrowseAtlasSource;
  final ValueChanged<AtlasSliceKind> onSelectedSliceKindChanged;
  final ValueChanged<String> onSelectedSliceChanged;
  final ValueChanged<bool> onCreateCorrespondingOwnerAutomaticallyChanged;
  final ValueChanged<PrefabKind> onCorrespondingPrefabKindChanged;
  final ValueChanged<double> onAtlasZoomChanged;
  final VoidCallback onSelectionInputsChanged;
  final ValueChanged<bool> onAutoSliceEnabledChanged;
  final ValueChanged<AtlasGridSettings> onGridSettingsChanged;
  final VoidCallback onSaveSlice;
  final VoidCallback onCancelSliceDraft;
  final VoidCallback onStartNewSlice;
  final ValueChanged<String> onDeleteSlice;
  final ValueChanged<AtlasPixelRect> onSelectionChanged;
  final bool hasLocalDraftChanges;

  @override
  State<AtlasSlicerTab> createState() => _AtlasSlicerTabState();
}

class _AtlasSlicerTabState extends State<AtlasSlicerTab> {
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void dispose() {
    _previewImageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrefabEditorThreePanelLayout(
      inspector: _buildInspectorCard(context),
      scene: _buildScenePanel(),
      display: _buildSliceDisplayCard(),
    );
  }

  Widget _buildInspectorCard(BuildContext context) {
    final isEditing = widget.selectedSlice != null;
    return SingleChildScrollView(
      key: const ValueKey<String>('atlas_slice_authoring_sidebar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorSectionCard(
            key: const ValueKey<String>('atlas_slice_source_section'),
            expansionKey: const ValueKey<String>(
              'atlas_slice_source_section_toggle',
            ),
            title: 'Source',
            collapsible: true,
            initiallyExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: ValueKey<String?>(
                    'atlas_${widget.selectedAtlasPath ?? 'none'}',
                  ),
                  initialValue: widget.selectedAtlasPath,
                  readOnly: true,
                  onTap: widget.onBrowseAtlasSource,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Atlas/Tileset Source',
                    hintText: 'Select a PNG atlas or tileset',
                    suffixIcon: IconButton(
                      key: const ValueKey<String>('atlas_source_file_picker'),
                      tooltip: 'Browse atlas or tileset PNGs',
                      onPressed: widget.onBrowseAtlasSource,
                      icon: const Icon(Icons.folder_open_outlined),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          if (isEditing)
            EditorSectionCard(
              key: const ValueKey<String>('atlas_slice_create_section'),
              title: 'Create slice',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('atlas_slice_new'),
                onPressed: widget.onStartNewSlice,
                icon: const Icon(Icons.post_add_outlined),
                label: Text('New $_sliceKindDisplayName Slice'),
              ),
            )
          else ...<Widget>[
            EditorSectionCard(
              key: const ValueKey<String>('atlas_slice_setup_section'),
              expansionKey: const ValueKey<String>(
                'atlas_slice_setup_section_toggle',
              ),
              title: 'Slice Setup',
              collapsible: !widget.hasLocalDraftChanges,
              initiallyExpanded: false,
              expanded: widget.hasLocalDraftChanges ? true : null,
              child: _buildSliceSetupFields(
                includeKind: true,
                includeAutomaticOwner: true,
              ),
            ),
            const SizedBox(height: EditorUiTokens.controlGap),
            EditorSectionCard(
              key: const ValueKey<String>('atlas_slice_selection_section'),
              expansionKey: const ValueKey<String>(
                'atlas_slice_selection_section_toggle',
              ),
              title: 'Selection',
              collapsible: !widget.hasLocalDraftChanges,
              initiallyExpanded: false,
              expanded: widget.hasLocalDraftChanges ? true : null,
              child: _buildSelectionControls(),
            ),
            const SizedBox(height: EditorUiTokens.controlGap),
            _buildActionRow(isEditing: false),
          ],
        ],
      ),
    );
  }

  Widget _buildSliceSetupFields({
    required bool includeKind,
    required bool includeAutomaticOwner,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (includeKind) ...<Widget>[
          DropdownButtonFormField<AtlasSliceKind>(
            key: ValueKey<String>(
              'slice_kind_${widget.selectedSliceKind.name}',
            ),
            initialValue: widget.selectedSliceKind,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Slice Kind',
            ),
            items: const <DropdownMenuItem<AtlasSliceKind>>[
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
              if (value == null) return;
              widget.onSelectedSliceKindChanged(value);
            },
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
        ],
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.sliceIdController,
          builder: (context, idValue, _) => TextField(
            key: const ValueKey<String>('atlas_slice_id_field'),
            controller: widget.sliceIdController,
            readOnly: !includeKind,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Slice ID',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: AtlasSliceIdConvention.exampleId(
                kind: widget.selectedSliceKind,
                sourcePath: widget.selectedAtlasPath,
                width: widget.selectionRectInImagePixels?.width,
                height: widget.selectionRectInImagePixels?.height,
              ),
              errorText: widget.sliceIdValidationMessage(idValue.text),
              suffixIcon: includeKind
                  ? IconButton(
                      key: const ValueKey<String>(
                        'atlas_slice_naming_convention_button',
                      ),
                      tooltip: 'Show slice naming convention',
                      onPressed: () => _showNamingConventionDialog(context),
                      icon: const Icon(Icons.info_outline),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        TextField(
          key: const ValueKey<String>('atlas_slice_tags_field'),
          controller: widget.sliceTagsController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Slice Tags (comma separated)',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'obstacle, decoration, wall, ground',
          ),
        ),
        if (includeAutomaticOwner) ...<Widget>[
          const SizedBox(height: EditorUiTokens.sectionGap),
          _buildAutomaticOwnerControls(),
        ],
      ],
    );
  }

  Widget _buildSelectionControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EditorZoomControls(
          value: widget.atlasZoom,
          min: widget.zoomMin,
          max: widget.zoomMax,
          step: widget.zoomStep,
          onChanged: widget.onAtlasZoomChanged,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        AtlasRegionFields(
          xController: widget.selectionXController,
          yController: widget.selectionYController,
          widthController: widget.selectionWController,
          heightController: widget.selectionHController,
          onChanged: widget.onSelectionInputsChanged,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('atlas_auto_slice_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-slice grid'),
          value: widget.autoSliceEnabled,
          onChanged: widget.onAutoSliceEnabledChanged,
        ),
        if (widget.autoSliceEnabled) ...<Widget>[
          const SizedBox(height: EditorUiTokens.controlGap),
          AtlasGridControls(
            settings: widget.gridSettings,
            onChanged: widget.onGridSettingsChanged,
          ),
        ],
        if (widget.atlasSize != null) ...<Widget>[
          const SizedBox(height: EditorUiTokens.controlGap),
          Text(
            'Atlas size: '
            '${widget.atlasSize!.width.toInt()}x'
            '${widget.atlasSize!.height.toInt()} px',
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow({required bool isEditing, String? deleteSliceId}) {
    return PrefabEditorActionRow(
      key: const ValueKey<String>('atlas_slice_action_row'),
      children: <Widget>[
        FilledButton.icon(
          key: const ValueKey<String>('atlas_slice_save'),
          onPressed: widget.onSaveSlice,
          icon: Icon(isEditing ? Icons.save_outlined : Icons.add_box_outlined),
          label: Text(
            isEditing
                ? 'Update Slice'
                : widget.createCorrespondingOwnerAutomatically
                ? widget.selectedSliceKind == AtlasSliceKind.prefab
                      ? 'Create Slice & Prefab'
                      : 'Create Slice & Platform'
                : 'Create Slice',
          ),
        ),
        if (!isEditing)
          OutlinedButton.icon(
            key: const ValueKey<String>('atlas_slice_cancel_draft'),
            onPressed: widget.hasLocalDraftChanges
                ? widget.onCancelSliceDraft
                : null,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        if (deleteSliceId != null)
          OutlinedButton.icon(
            key: const ValueKey<String>('atlas_slice_delete'),
            onPressed: () => widget.onDeleteSlice(deleteSliceId),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
      ],
    );
  }

  Widget _buildAutomaticOwnerControls() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.sliceIdController,
      builder: (context, idValue, _) {
        final normalizedId = idValue.text.trim().toLowerCase();
        final sliceAlreadyExists =
            normalizedId.isNotEmpty &&
            widget.existingSliceIds.any(
              (id) => id.toLowerCase() == normalizedId,
            );
        final isPrefabSlice = widget.selectedSliceKind == AtlasSliceKind.prefab;
        final canCreate = !sliceAlreadyExists;
        final canToggle =
            canCreate || widget.createCorrespondingOwnerAutomatically;
        final kindEnabled =
            canCreate && widget.createCorrespondingOwnerAutomatically;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile.adaptive(
              key: const ValueKey<String>(
                'atlas_create_corresponding_owner_toggle',
              ),
              contentPadding: EdgeInsets.zero,
              title: Text(
                isPrefabSlice
                    ? 'Create corresponding prefab automatically'
                    : 'Create corresponding platform automatically',
              ),
              value: widget.createCorrespondingOwnerAutomatically,
              onChanged: canToggle
                  ? widget.onCreateCorrespondingOwnerAutomaticallyChanged
                  : null,
            ),
            if (isPrefabSlice) ...<Widget>[
              const SizedBox(height: EditorUiTokens.controlGap),
              SegmentedButton<PrefabKind>(
                key: const ValueKey<String>('atlas_corresponding_prefab_kind'),
                segments: const <ButtonSegment<PrefabKind>>[
                  ButtonSegment<PrefabKind>(
                    value: PrefabKind.decoration,
                    label: Text('Decoration'),
                    icon: Icon(Icons.park_outlined),
                  ),
                  ButtonSegment<PrefabKind>(
                    value: PrefabKind.obstacle,
                    label: Text('Obstacle'),
                    icon: Icon(Icons.warning_amber_outlined),
                  ),
                ],
                selected: <PrefabKind>{widget.correspondingPrefabKind},
                showSelectedIcon: false,
                onSelectionChanged: kindEnabled
                    ? (selection) => widget.onCorrespondingPrefabKindChanged(
                        selection.single,
                      )
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _showNamingConventionDialog(BuildContext context) {
    final kind = widget.selectedSliceKind;
    final isPrefabSlice = kind == AtlasSliceKind.prefab;
    final selection = widget.selectionRectInImagePixels;
    final pattern = AtlasSliceIdConvention.pattern(kind);
    final contextualPattern = AtlasSliceIdConvention.contextualPattern(
      kind: kind,
      sourcePath: widget.selectedAtlasPath,
      width: selection?.width,
      height: selection?.height,
    );
    final example = AtlasSliceIdConvention.exampleId(
      kind: kind,
      sourcePath: widget.selectedAtlasPath,
      width: selection?.width,
      height: selection?.height,
    );
    final selectedSize = selection == null
        ? null
        : '_${selection.width}x${selection.height}';
    final dialogTitle = isPrefabSlice
        ? 'Prefab Slice naming convention'
        : 'Tile Slice naming convention';
    final contextLabel = !isPrefabSlice && selectedSize != null
        ? 'For the current source and selection'
        : 'For the current source';
    final rules = isPrefabSlice
        ? 'Use lowercase snake_case, keep the collection prefix, name the '
              'object, and end with a zero-padded _01 through _99 variant. '
              'Pixel size is not part of a Prefab Slice ID.'
        : 'Use lowercase snake_case, keep the collection and source-filename '
              'prefix, name the object, and put a zero-padded _01 through _99 '
              'variant before the pixel-size suffix. The editor appends or '
              'updates that suffix automatically. '
              '${selectedSize == null ? 'A valid selection supplies the required size.' : 'The current required suffix is $selectedSize.'}';

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('atlas_slice_naming_convention_dialog'),
        title: Text(dialogTitle),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Pattern', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: EditorUiTokens.rowTitleGap),
                _NamingPatternBox(text: pattern),
                const SizedBox(height: EditorUiTokens.sectionGap),
                Text(
                  contextLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: EditorUiTokens.rowTitleGap),
                _NamingPatternBox(text: contextualPattern),
                const SizedBox(height: EditorUiTokens.sectionGap),
                Text('Example', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: EditorUiTokens.rowTitleGap),
                SelectableText(example),
                const SizedBox(height: EditorUiTokens.sectionGap),
                Text(rules),
                const SizedBox(height: EditorUiTokens.sectionGap),
                const Text(
                  'This convention is enforced only when creating a new '
                  'slice; existing IDs are kept for compatibility.',
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            key: const ValueKey<String>('atlas_slice_naming_convention_close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildScenePanel() {
    return EditorPanelCard(
      key: const ValueKey<String>('atlas_scene_card'),
      title: 'Atlas Slicer View',
      bodyMode: EditorPanelBodyMode.expanded,
      child: _buildAtlasCanvas(),
    );
  }

  Widget _buildSliceDisplayCard() {
    final selectedSlice = widget.selectedSlice;
    final selectionBelongsToCurrentSource =
        selectedSlice != null &&
        widget.selectedAtlasPath != null &&
        selectedSlice.sourceImagePath.trim() ==
            widget.selectedAtlasPath!.trim();

    return SingleChildScrollView(
      key: const ValueKey<String>('atlas_slice_display_sidebar'),
      child: EditorSectionCard(
        key: const ValueKey<String>('atlas_slice_library_section'),
        expansionKey: const ValueKey<String>(
          'atlas_slice_library_section_toggle',
        ),
        title: 'Existing $_sliceKindDisplayName slices',
        trailing: Text('${widget.slices.length} total'),
        collapsible: widget.selectedSliceId == null,
        initiallyExpanded: false,
        expanded: widget.selectedSliceId == null ? null : true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.selectedSliceId != null &&
                selectedSlice != null &&
                !selectionBelongsToCurrentSource) ...<Widget>[
              const PrefabEditorPanelSummary(
                noticeText: 'The current selection belongs to another source.',
              ),
              const SizedBox(height: EditorUiTokens.sectionGap),
            ],
            if (widget.slices.isEmpty)
              PrefabEditorEmptyState(
                message: widget.selectedAtlasPath == null
                    ? 'Select an atlas/tileset image first.'
                    : 'No ${_sliceKindDisplayName.toLowerCase()} '
                          'slices for this source yet.',
              )
            else
              for (final slice in widget.slices) _buildSliceRow(slice),
          ],
        ),
      ),
    );
  }

  Widget _buildSliceRow(AtlasSliceDef slice) {
    final isSelected = widget.selectedSliceId == slice.id;

    return EditorListCard(
      key: ValueKey<String>('atlas_slice_row_${slice.id}'),
      isSelected: isSelected,
      onTap: () => widget.onSelectedSliceChanged(slice.id),
      semanticLabel:
          '${slice.id}, ${slice.width} by ${slice.height} pixels, '
          '${slice.tags.isEmpty ? 'no tags' : slice.tags.join(', ')}',
      preview: AtlasRegionPreviewTile(
        key: ValueKey<String>('atlas_slice_preview_${slice.id}'),
        imageCache: _previewImageCache,
        workspaceRootPath: widget.workspaceRootPath,
        sourceImagePath: slice.sourceImagePath,
        region: AtlasPixelRect(
          x: slice.x,
          y: slice.y,
          width: slice.width,
          height: slice.height,
        ),
      ),
      details: isSelected
          ? Padding(
              key: ValueKey<String>('atlas_slice_selected_editor_${slice.id}'),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: _buildSelectedSliceEditor(slice),
            )
          : null,
      child: PrefabEditorRowMetadata(
        key: ValueKey<String>('atlas_slice_row_header_${slice.id}'),
        title: slice.id,
        isSelected: isSelected,
        metadataLines: const <String>[],
      ),
    );
  }

  Widget _buildSelectedSliceEditor(AtlasSliceDef slice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildSliceSetupFields(
          includeKind: false,
          includeAutomaticOwner: false,
        ),
        const SizedBox(height: EditorUiTokens.sectionGap),
        Text('Selection', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: EditorUiTokens.controlGap),
        _buildSelectionControls(),
        const SizedBox(height: EditorUiTokens.sectionGap),
        _buildActionRow(isEditing: true, deleteSliceId: slice.id),
      ],
    );
  }

  Widget _buildAtlasCanvas() {
    final selectedAtlasPath = widget.selectedAtlasPath;
    if (selectedAtlasPath == null) {
      return const PrefabEditorEmptyState(
        message: 'Select an atlas/tileset image to start slicing.',
      );
    }
    final atlasSize = widget.atlasSize;
    if (atlasSize == null) {
      return const PrefabEditorEmptyState(
        message: 'Loading atlas image metadata...',
      );
    }

    return AtlasImageViewport(
      workspaceRootPath: widget.workspaceRootPath,
      sourceImagePath: selectedAtlasPath,
      imageWidth: atlasSize.width.toInt(),
      imageHeight: atlasSize.height.toInt(),
      zoom: widget.atlasZoom,
      zoomMin: widget.zoomMin,
      zoomMax: widget.zoomMax,
      zoomStep: widget.zoomStep,
      autoSliceEnabled: widget.autoSliceEnabled,
      gridSettings: widget.gridSettings,
      selection: widget.selectionRectInImagePixels,
      existingRegions: <AtlasSelectionOverlay>[
        for (final slice in widget.slices)
          AtlasSelectionOverlay(
            id: slice.id,
            rect: AtlasPixelRect(
              x: slice.x,
              y: slice.y,
              width: slice.width,
              height: slice.height,
            ),
          ),
      ],
      selectedRegionId: widget.selectedSliceId,
      horizontalScrollController: widget.horizontalScrollController,
      verticalScrollController: widget.verticalScrollController,
      onZoomChanged: widget.onAtlasZoomChanged,
      onSelectionChanged: widget.onSelectionChanged,
    );
  }

  String get _sliceKindDisplayName {
    switch (widget.selectedSliceKind) {
      case AtlasSliceKind.prefab:
        return 'Prefab';
      case AtlasSliceKind.tile:
        return 'Tile';
    }
  }
}

class _NamingPatternBox extends StatelessWidget {
  const _NamingPatternBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(EditorUiTokens.controlGap),
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: SelectableText(text),
  );
}
