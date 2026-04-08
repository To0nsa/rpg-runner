import 'package:flutter/foundation.dart';

@immutable
class PrefabSceneValues {
  const PrefabSceneValues({
    required this.anchorX,
    required this.anchorY,
    required this.colliderOffsetX,
    required this.colliderOffsetY,
    required this.colliderWidth,
    required this.colliderHeight,
  });

  final int anchorX;
  final int anchorY;
  final int colliderOffsetX;
  final int colliderOffsetY;
  final int colliderWidth;
  final int colliderHeight;
}
