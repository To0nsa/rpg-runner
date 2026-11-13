import 'package:flutter/material.dart';
import 'package:rpg_runner/ui/components/map_label_button.dart';
import 'package:rpg_runner/ui/components/map_location_layer.dart';
import 'package:rpg_runner/ui/components/map_viewport.dart';
import 'package:rpg_runner/ui/components/menu_scaffold.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

import 'editor_scene_viewport.dart';
import 'editor_zoom_controls.dart';

/// A geographic location, independent of campaigns or future Library content.
/// Position is normalized against the complete image, never its visible crop.
class EditorMapLocation {
  const EditorMapLocation({
    required this.id,
    required this.label,
    required this.position,
    this.icon = Icons.flag_outlined,
  });
  final String id, label;
  final Offset position;
  final IconData icon;
}

/// Callers supply artwork and local drafts. Preview uses actual game components;
/// authoring reuses editor navigation and only emits normalized point changes.
class EditorLocationMap extends StatefulWidget {
  const EditorLocationMap({
    super.key,
    required this.image,
    required this.imageIdentity,
    required this.aspectRatio,
    required this.locations,
    required this.selectedId,
    required this.onPositionChanged,
    required this.previewTitle,
  });
  final ImageProvider image;
  final String imageIdentity, selectedId;
  final String previewTitle;
  final double aspectRatio;
  final List<EditorMapLocation> locations;
  final ValueChanged<Offset> onPositionChanged;
  @override
  State<EditorLocationMap> createState() => _EditorLocationMapState();
}

class _EditorLocationMapState extends State<EditorLocationMap> {
  final _view = EditorSceneViewportController(minZoom: 1, maxZoom: 6);
  bool _preview = false, _portrait = false, _placing = false;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  Widget _locations(Size scene, Rect visible) => MapLocationLayer(
    anchors: [
      for (final location in widget.locations)
        Offset(
          location.position.dx * scene.width,
          location.position.dy * scene.height,
        ),
    ],
    visibleMap: visible,
    children: [
      for (final location in widget.locations)
        MapLabelButton(
          key: ValueKey('map_location_${location.id}'),
          label: location.label,
          icon: location.icon,
          onPressed: () {},
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Place marker'),
            icon: Icon(Icons.place_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text('Game preview'),
            icon: Icon(Icons.visibility_outlined),
          ),
        ],
        selected: {_preview},
        onSelectionChanged: (value) => setState(() => _preview = value.single),
      ),
      const SizedBox(height: 12),
      if (_preview)
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Landscape'),
              selected: !_portrait,
              onSelected: (_) => setState(() => _portrait = false),
            ),
            ChoiceChip(
              label: const Text('Portrait'),
              selected: _portrait,
              onSelected: (_) => setState(() => _portrait = true),
            ),
          ],
        )
      else
        Row(
          children: [
            Expanded(
              child: EditorZoomControls(
                value: _view.zoom,
                min: 1,
                max: 6,
                step: .25,
                onChanged: (value) => setState(() => _view.setZoom(value)),
              ),
            ),
            IconButton(
              tooltip: 'Fit map',
              onPressed: () => setState(_view.reset),
              icon: const Icon(Icons.fit_screen),
            ),
          ],
        ),
      const SizedBox(height: 12),
      SizedBox(
        height: 340,
        child: _preview
            ? Center(
                child: AspectRatio(
                  aspectRatio: _portrait ? 9 / 16 : 16 / 9,
                  child: Theme(
                    data: createUiTheme(),
                    child: MenuScaffold(
                      title: widget.previewTitle,
                      overlayAppBar: true,
                      automaticallyImplyLeading: false,
                      background: const ColoredBox(color: Colors.black),
                      child: MapViewport(
                        key: const ValueKey('location_game_preview'),
                        assetPath: widget.imageIdentity,
                        imageProvider: widget.image,
                        aspectRatio: widget.aspectRatio,
                        cacheWidth: 1600,
                        overlayBuilder: (_, _, scene, visible) => [
                          _locations(scene, visible),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = constraints.biggest;
                  final scene = applyBoxFit(
                    BoxFit.contain,
                    Size(widget.aspectRatio, 1),
                    viewport,
                  ).destination;
                  final layout = _view.layout(viewport: viewport, scene: scene);
                  void place(Offset local, {bool begin = false}) {
                    final point = layout.toWorld(local);
                    if (begin) _placing = (Offset.zero & scene).contains(point);
                    if (!_placing) return;
                    widget.onPositionChanged(
                      Offset(
                        (point.dx / scene.width).clamp(0.0, 1.0),
                        (point.dy / scene.height).clamp(0.0, 1.0),
                      ),
                    );
                  }

                  final selected = widget.locations.firstWhere(
                    (location) => location.id == widget.selectedId,
                  );
                  return ClipRect(
                    child: EditorScenePointerRegion(
                      key: const ValueKey('location_map_placement'),
                      onPanDelta: (delta) => setState(() => _view.panBy(delta)),
                      onZoomSteps: (steps) => setState(
                        () =>
                            _view.setZoom(_view.zoom + steps * _view.zoomStep),
                      ),
                      onPointerDown: (event) =>
                          place(event.localPosition, begin: true),
                      onPointerMove: (event) => place(event.localPosition),
                      onPointerUp: (_) => _placing = false,
                      onPointerCancel: (_) => _placing = false,
                      // Claim drags inside the map so the enclosing dialog's
                      // scroll view cannot move under an active placement.
                      child: GestureDetector(
                        onPanUpdate: (_) {},
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              left: layout.origin.dx,
                              top: layout.origin.dy,
                              width: layout.contentSize.width,
                              height: layout.contentSize.height,
                              child: Image(
                                key: const ValueKey('location_map_image'),
                                image: ResizeImage.resizeIfNeeded(
                                  1600,
                                  null,
                                  widget.image,
                                ),
                                fit: BoxFit.fill,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text(
                                    'Map preview unavailable. Enter coordinates below.',
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left:
                                  layout.origin.dx +
                                  selected.position.dx *
                                      layout.contentSize.width -
                                  12,
                              top:
                                  layout.origin.dy +
                                  selected.position.dy *
                                      layout.contentSize.height -
                                  12,
                              child: IgnorePointer(
                                child: Container(
                                  key: const ValueKey('location_map_marker'),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      const SizedBox(height: 12),
      Text(
        _preview
            ? 'Game framing and location labels. Pan and zoom to inspect the map.'
            : 'Click or drag to place. Ctrl+drag pans; Ctrl+scroll zooms.',
      ),
    ],
  );
}
