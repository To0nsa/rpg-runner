import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ui_icon_coords.dart';

class UiIconTile extends StatefulWidget {
  const UiIconTile({
    super.key,
    required this.coords,
    this.size = 32,
    this.assetPath = _defaultAssetPath,
    this.tilePx = _defaultTilePx,
    this.backgroundColor,
  });

  final UiIconCoords coords;
  final double size;
  final String assetPath;
  final int tilePx;
  final Color? backgroundColor;

  static const String _defaultAssetPath =
      'assets/images/icons/transparentIcons.png';
  static const int _defaultTilePx = 32;

  @override
  State<UiIconTile> createState() => _UiIconTileState();
}

class _UiIconTileState extends State<UiIconTile> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant UiIconTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _resolve();
    }
  }

  void _resolve() {
    _unsubscribe();
    final provider = AssetImage(widget.assetPath);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    });
    stream.addListener(_listener!);
  }

  void _unsubscribe() {
    final listener = _listener;
    final stream = _stream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _UiIconTilePainter(
        image: _image,
        row: widget.coords.row,
        col: widget.coords.col,
        tilePx: widget.tilePx,
        backgroundColor: widget.backgroundColor,
      ),
    );
  }
}

class _UiIconTilePainter extends CustomPainter {
  const _UiIconTilePainter({
    required this.image,
    required this.row,
    required this.col,
    required this.tilePx,
    required this.backgroundColor,
  });

  final ui.Image? image;
  final int row;
  final int col;
  final int tilePx;
  final Color? backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = backgroundColor;
    if (bg != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    }

    final img = image;
    if (img == null) return;

    final src = Rect.fromLTWH(
      col * tilePx.toDouble(),
      row * tilePx.toDouble(),
      tilePx.toDouble(),
      tilePx.toDouble(),
    );
    final dst = Offset.zero & size;
    canvas.drawImageRect(img, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant _UiIconTilePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.row != row ||
        oldDelegate.col != col ||
        oldDelegate.tilePx != tilePx ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
