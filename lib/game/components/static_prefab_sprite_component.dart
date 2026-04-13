import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

/// World-space static sprite rendered from a cropped atlas region.
class StaticPrefabSpriteComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  StaticPrefabSpriteComponent({
    required this.assetPath,
    required this.srcRect,
    required Vector2 position,
    required Vector2 size,
    this.flipX = false,
    this.flipY = false,
  }) : super(position: position, size: size, anchor: Anchor.topLeft);

  final String assetPath;
  final ui.Rect srcRect;
  final bool flipX;
  final bool flipY;
  bool _spriteLoadFailed = false;
  ui.Image? _image;

  static final ui.Paint _spritePaint = ui.Paint()
    ..filterQuality = ui.FilterQuality.none;
  static final ui.Paint _fallbackPaint = ui.Paint()
    ..color = const ui.Color(0x66FF00FF);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    Object? lastError;
    for (final candidate in _assetPathCandidates(assetPath)) {
      try {
        _image = await game.images.load(candidate);
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }

    _spriteLoadFailed = true;
    assert(() {
      debugPrint(
        'StaticPrefabSpriteComponent failed to load asset "$assetPath" '
        '(tried: ${_assetPathCandidates(assetPath).join(', ')}): $lastError',
      );
      return true;
    }());
  }

  List<String> _assetPathCandidates(String path) {
    final out = <String>[path];
    const rootPrefix = 'assets/images/';
    const assetsPrefix = 'assets/';

    if (path.startsWith(rootPrefix)) {
      out.add(path.substring(rootPrefix.length));
    } else if (path.startsWith(assetsPrefix)) {
      out.add(path.substring(assetsPrefix.length));
    } else {
      out.add('$rootPrefix$path');
    }

    return out.toSet().toList(growable: false);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final image = _image;
    if (image != null) {
      if (flipX || flipY) {
        canvas.save();
        canvas.translate(flipX ? size.x : 0, flipY ? size.y : 0);
        canvas.scale(flipX ? -1 : 1, flipY ? -1 : 1);
      }
      canvas.drawImageRect(
        image,
        srcRect,
        ui.Rect.fromLTWH(0, 0, size.x, size.y),
        _spritePaint,
      );
      if (flipX || flipY) {
        canvas.restore();
      }
      return;
    }

    if (!_spriteLoadFailed) {
      return;
    }

    canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.x, size.y), _fallbackPaint);
  }
}
