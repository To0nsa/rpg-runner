import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../parallax/parallax_domain_models.dart';
import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_scene_viewport_frame.dart';
import '../../shared/editor_zoom_controls.dart';
import '../../shared/ground_material_render_rules.dart';
import '../../shared/scene_input_utils.dart';

class ParallaxPreviewView extends StatefulWidget {
  const ParallaxPreviewView({
    super.key,
    required this.workspaceRootPath,
    required this.theme,
  });

  final String workspaceRootPath;
  final ParallaxThemeDef? theme;

  @override
  State<ParallaxPreviewView> createState() => _ParallaxPreviewViewState();
}

class _ParallaxPreviewViewState extends State<ParallaxPreviewView> {
  static const double _minZoom = 0.5;
  static const double _maxZoom = 4.0;
  static const double _zoomStep = 0.1;
  static const double _minCameraX = -2048.0;
  static const double _maxCameraX = 2048.0;

  final EditorUiImageCache _imageCache = EditorUiImageCache();
  final Map<String, ui.Rect> _groundMaterialSrcRectsByAbsolutePath =
      <String, ui.Rect>{};
  double _zoom = 1.0;
  double _cameraX = 0.0;
  bool _ctrlPanActive = false;
  int? _activePointer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _ensureImagesLoaded();
  }

  @override
  void didUpdateWidget(covariant ParallaxPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath ||
        oldWidget.theme != widget.theme) {
      _ensureImagesLoaded();
    }
  }

  @override
  void dispose() {
    _imageCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (theme == null) {
      return _buildEmptyState('No parallax theme is authored for this level.');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight.isFinite
            ? math.max(1.0, constraints.maxHeight - 72)
            : 420.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                EditorZoomControls(
                  value: _zoom,
                  min: _minZoom,
                  max: _maxZoom,
                  step: _zoomStep,
                  onChanged: _setZoom,
                ),
                SizedBox(
                  width: 240,
                  child: Slider(
                    value: _cameraX.clamp(_minCameraX, _maxCameraX).toDouble(),
                    min: _minCameraX,
                    max: _maxCameraX,
                    divisions: 128,
                    label: 'Camera X ${_cameraX.round()}',
                    onChanged: (value) {
                      setState(() {
                        _cameraX = value;
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _cameraX = 0.0;
                    });
                  },
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Reset Camera'),
                ),
                Chip(
                  avatar: const Icon(Icons.swap_horiz, size: 16),
                  label: Text('cameraX=${_cameraX.round()}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: EditorSceneViewportFrame(
                height: viewportHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerEnd,
                      onPointerCancel: _onPointerEnd,
                      onPointerSignal: _onPointerSignal,
                      child: CustomPaint(
                        painter: _ParallaxPreviewPainter(
                          workspaceRootPath: widget.workspaceRootPath,
                          imageCache: _imageCache,
                          loadedImageCount: _imageCache.loadedImageCount,
                          theme: theme,
                          zoom: _zoom,
                          cameraX: _cameraX,
                          groundMaterialSourceRect: _groundMaterialSrcRectFor(
                            theme,
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xCC101820),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0x334A6074)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text('Ctrl+drag pans. Ctrl+scroll zooms.'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3C48)),
      ),
      child: Center(child: Text(message)),
    );
  }

  Future<void> _ensureImagesLoaded() async {
    final theme = widget.theme;
    if (theme == null) {
      return;
    }
    final loadGeneration = ++_loadGeneration;
    final absolutePaths = <String>{
      _absolutePath(theme.groundMaterialAssetPath),
      ...theme.layers.map((layer) => _absolutePath(layer.assetPath)),
    }.toList(growable: false);
    await Future.wait(
      absolutePaths.map((absolutePath) => _imageCache.ensureLoaded(absolutePath)),
    );
    final groundMaterialAbsolutePath = _absolutePath(theme.groundMaterialAssetPath);
    final groundImage = _imageCache.imageFor(groundMaterialAbsolutePath);
    if (groundImage != null &&
        !_groundMaterialSrcRectsByAbsolutePath.containsKey(
          groundMaterialAbsolutePath,
        )) {
      final srcRect = await detectGroundMaterialSourceRectForPreview(groundImage);
      if (!mounted || loadGeneration != _loadGeneration) {
        return;
      }
      _groundMaterialSrcRectsByAbsolutePath[groundMaterialAbsolutePath] = srcRect;
    }
    if (!mounted || loadGeneration != _loadGeneration) {
      return;
    }
    setState(() {});
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    _ctrlPanActive = SceneInputUtils.shouldPanWithPrimaryDrag(event.buttons);
    if (_ctrlPanActive) {
      _activePointer = event.pointer;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_ctrlPanActive || _activePointer != event.pointer) {
      return;
    }
    if (!SceneInputUtils.isPrimaryButtonPressed(event.buttons)) {
      _ctrlPanActive = false;
      _activePointer = null;
      return;
    }
    setState(() {
      _cameraX = (_cameraX - (event.delta.dx / _zoom))
          .clamp(_minCameraX, _maxCameraX)
          .toDouble();
    });
  }

  void _onPointerEnd(PointerEvent event) {
    if (_activePointer == event.pointer) {
      _activePointer = null;
      _ctrlPanActive = false;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final signedSteps = SceneInputUtils.signedZoomStepsFromCtrlScroll(event);
    if (signedSteps == 0) {
      return;
    }
    final nextZoom = _zoom + (signedSteps * _zoomStep);
    _setZoom(nextZoom);
  }

  void _setZoom(double value) {
    final next = EditorSceneViewUtils.snapZoom(
      value: value,
      min: _minZoom,
      max: _maxZoom,
      step: _zoomStep,
    );
    if (EditorSceneViewUtils.zoomValuesEqual(next, _zoom)) {
      return;
    }
    setState(() {
      _zoom = next;
    });
  }

  String _absolutePath(String relativePath) {
    return p.normalize(p.join(widget.workspaceRootPath, relativePath));
  }

  ui.Rect? _groundMaterialSrcRectFor(ParallaxThemeDef theme) {
    final groundMaterialAbsolutePath = _absolutePath(theme.groundMaterialAssetPath);
    return _groundMaterialSrcRectsByAbsolutePath[groundMaterialAbsolutePath];
  }
}

class _ParallaxPreviewPainter extends CustomPainter {
  const _ParallaxPreviewPainter({
    required this.workspaceRootPath,
    required this.imageCache,
    required this.loadedImageCount,
    required this.theme,
    required this.zoom,
    required this.cameraX,
    required this.groundMaterialSourceRect,
  });

  final String workspaceRootPath;
  final EditorUiImageCache imageCache;
  final int loadedImageCount;
  final ParallaxThemeDef theme;
  final double zoom;
  final double cameraX;
  final ui.Rect? groundMaterialSourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFF17242C), Color(0xFF0D141A)],
      );
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final groundBandHeight = resolveGroundMaterialBandHeight(
      materialSourceRect: groundMaterialSourceRect,
      zoom: zoom,
      maxHeight: size.height,
    );
    final groundBandRect = buildViewportBottomGroundBandRect(
      viewportSize: size,
      groundBandHeight: groundBandHeight,
    );

    _paintLayers(
      canvas,
      size: size,
      layers: theme.layers
          .where((layer) => layer.group == parallaxGroupBackground)
          .toList(growable: false),
      bottomAnchorY: groundBandRect.top,
      clipRect: Offset.zero & size,
    );

    _paintGround(canvas, groundBandRect: groundBandRect);

    _paintLayers(
      canvas,
      size: size,
      layers: theme.layers
          .where((layer) => layer.group == parallaxGroupForeground)
          .toList(growable: false),
      bottomAnchorY: groundBandRect.bottom,
      clipRect: groundBandRect,
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF7CB7E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(Offset.zero & size, borderPaint);
  }

  void _paintGround(Canvas canvas, {required Rect groundBandRect}) {
    final image = _resolveImage(theme.groundMaterialAssetPath);
    final materialSourceRect = groundMaterialSourceRect;
    if (image == null || materialSourceRect == null) {
      canvas.drawRect(
        groundBandRect,
        Paint()
          ..shader = ui.Gradient.linear(
            groundBandRect.topCenter,
            groundBandRect.bottomCenter,
            const [Color(0xFF5D6D3D), Color(0xFF243018)],
          ),
      );
      return;
    }

    final tileWidth = image.width * zoom;
    if (tileWidth <= 0 || groundBandRect.height <= 0) {
      return;
    }
    final scroll = cameraX * zoom;
    final startX = _positiveMod(-scroll, tileWidth);
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.save();
    canvas.clipRect(groundBandRect);
    for (var x = startX - tileWidth;
        x < groundBandRect.width + tileWidth;
        x += tileWidth) {
      final dstRect = Rect.fromLTWH(
        x,
        groundBandRect.top,
        tileWidth,
        groundBandRect.height,
      );
      canvas.drawImageRect(
        image,
        materialSourceRect,
        dstRect,
        paint,
      );
    }
    canvas.restore();
  }

  void _paintLayers(
    Canvas canvas, {
    required Size size,
    required List<ParallaxLayerDef> layers,
    required double bottomAnchorY,
    required Rect clipRect,
  }) {
    if (layers.isEmpty) {
      return;
    }
    canvas.save();
    canvas.clipRect(clipRect);
    for (final layer in layers) {
      final image = _resolveImage(layer.assetPath);
      if (image == null) {
        continue;
      }
      final tileWidth = image.width * zoom;
      final tileHeight = image.height * zoom;
      if (tileWidth <= 0 || tileHeight <= 0) {
        continue;
      }
      final parallaxFactor = layer.parallaxFactor.clamp(
        minParallaxFactor,
        maxParallaxFactor,
      );
      final scroll = cameraX * parallaxFactor * zoom;
      final startX = _positiveMod(-scroll, tileWidth);
      final topY = resolveBottomAnchoredLayerTopY(
        bottomAnchorY: bottomAnchorY,
        layerHeight: tileHeight,
        yOffset: layer.yOffset * zoom,
      );
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          layer.opacity.clamp(minOpacity, maxOpacity),
        );
      for (var x = startX - tileWidth; x < size.width + tileWidth; x += tileWidth) {
        final dstRect = Rect.fromLTWH(x, topY, tileWidth, tileHeight);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          dstRect,
          paint,
        );
      }
    }
    canvas.restore();
  }

  ui.Image? _resolveImage(String sourceImagePath) {
    final absolutePath = p.normalize(p.join(workspaceRootPath, sourceImagePath));
    return imageCache.imageFor(absolutePath);
  }

  @override
  bool shouldRepaint(covariant _ParallaxPreviewPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.zoom != zoom ||
        oldDelegate.cameraX != cameraX ||
        oldDelegate.groundMaterialSourceRect != groundMaterialSourceRect ||
        oldDelegate.loadedImageCount != loadedImageCount;
  }
}

double _positiveMod(double value, double modulus) {
  if (modulus == 0) {
    return 0;
  }
  final result = value % modulus;
  return result < 0 ? result + modulus : result;
}
