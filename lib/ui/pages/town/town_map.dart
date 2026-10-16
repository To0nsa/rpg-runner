import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

/// One transformed scene keeps city-service callouts attached during pan/zoom.
/// Service callouts share the supplied city map’s fitted image coordinates.
class TownMap extends StatefulWidget {
  const TownMap({
    super.key,
    required this.onStorePressed,
    required this.onLibraryPressed,
  });
  final VoidCallback onStorePressed;
  final VoidCallback onLibraryPressed;
  static const assetPath = 'assets/Théodonis.jpg';

  @override
  State<TownMap> createState() => _TownMapState();
}

class _TownMapState extends State<TownMap> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(Size viewport, double factor) {
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      1.0,
      3.0,
    );
    final center = viewport.center(Offset.zero);
    final scene = _transform.toScene(center);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
      ..setTranslationRaw(
        (center.dx - scene.dx * scale).clamp(-viewport.width * (scale - 1), 0),
        (center.dy - scene.dy * scale).clamp(-viewport.height * (scale - 1), 0),
        0,
      );
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = constraints.biggest;
              final fitted = applyBoxFit(
                BoxFit.contain,
                const Size(4096, 3072),
                viewport,
              ).destination;
              final rect = Alignment.center.inscribe(
                fitted,
                Offset.zero & viewport,
              );
              Offset at(double x, double y) => Offset(
                rect.left + rect.width * x,
                rect.top + rect.height * y,
              );
              final store = at(.18, .60);
              final library = at(.72, .33);
              final markerWidth = math.min(180.0, viewport.width - ui.space.lg);
              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            TownMap.assetPath,
                            fit: BoxFit.contain,
                            cacheWidth: 2048,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => Center(
                              child: Text('Théodonis', style: ui.text.display),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _ServiceConnections(
                                storeSite: at(.35, .49),
                                librarySite: at(.47, .405),
                                store: store,
                                library: library,
                                color: ui.colors.accentStrong,
                                outlineColor: ui.colors.background,
                              ),
                            ),
                          ),
                          Positioned(
                            left: (store.dx - markerWidth / 2).clamp(
                              ui.space.xs,
                              math.max(
                                ui.space.xs,
                                viewport.width - markerWidth - ui.space.xs,
                              ),
                            ),
                            top: math.max(0, store.dy - 28),
                            width: markerWidth,
                            child: _MapService(
                              key: const ValueKey('town-store-marker'),
                              label: 'Store',
                              icon: Icons.storefront,
                              onPressed: widget.onStorePressed,
                            ),
                          ),
                          Positioned(
                            left: (library.dx - markerWidth / 2).clamp(
                              ui.space.xs,
                              math.max(
                                ui.space.xs,
                                viewport.width - markerWidth - ui.space.xs,
                              ),
                            ),
                            top: math.min(
                              viewport.height - 56,
                              library.dy - 28,
                            ),
                            width: markerWidth,
                            child: _MapService(
                              key: const ValueKey('town-library-marker'),
                              label: 'Library',
                              icon: Icons.menu_book,
                              onPressed: widget.onLibraryPressed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: ui.space.xs,
                    top: ui.space.xs,
                    child: Material(
                      color: ui.colors.background,
                      borderRadius: BorderRadius.circular(ui.radii.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: () => _zoom(viewport, 1 / 1.4),
                            icon: const Icon(Icons.remove),
                          ),
                          IconButton(
                            tooltip: 'Reset map',
                            onPressed: () =>
                                _transform.value = Matrix4.identity(),
                            icon: const Icon(Icons.center_focus_strong),
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: () => _zoom(viewport, 1.4),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.all(ui.space.xs),
          child: Text(
            'Visit a city service • Drag to explore • Pinch to zoom',
            textAlign: TextAlign.center,
            style: ui.text.body.copyWith(color: ui.colors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _MapService extends StatelessWidget {
  const _MapService({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Material(
      color: ui.colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.sm),
        side: BorderSide(
          color: ui.colors.accentStrong,
          width: ui.sizes.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: ui.sizes.tapTarget),
          child: Padding(
            padding: EdgeInsets.all(ui.space.sm),
            child: Row(
              children: [
                Icon(icon, color: ui.colors.accentStrong),
                SizedBox(width: ui.space.xs),
                Expanded(child: Text(label, style: ui.text.headline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceConnections extends CustomPainter {
  const _ServiceConnections({
    required this.storeSite,
    required this.librarySite,
    required this.store,
    required this.library,
    required this.color,
    required this.outlineColor,
  });
  final Offset storeSite, librarySite, store, library;
  final Color color, outlineColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = outlineColor
      ..strokeWidth = 5;
    canvas.drawLine(storeSite, store, paint);
    canvas.drawLine(librarySite, library, paint);
    canvas.drawCircle(storeSite, 8, paint);
    canvas.drawCircle(librarySite, 8, paint);
    paint
      ..color = color
      ..strokeWidth = 2;
    canvas.drawLine(storeSite, store, paint);
    canvas.drawLine(librarySite, library, paint);
    canvas.drawCircle(storeSite, 5, paint);
    canvas.drawCircle(librarySite, 5, paint);
  }

  @override
  bool shouldRepaint(_ServiceConnections old) =>
      storeSite != old.storeSite ||
      librarySite != old.librarySite ||
      store != old.store ||
      library != old.library ||
      color != old.color ||
      outlineColor != old.outlineColor;
}
