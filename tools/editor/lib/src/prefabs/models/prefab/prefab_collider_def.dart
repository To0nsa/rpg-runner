import 'package:flutter/foundation.dart';

/// Axis-aligned collider authored in prefab-local pixel space.
///
/// Offsets are stored relative to the prefab anchor and represent collider
/// center coordinates.
@immutable
class PrefabColliderDef {
  const PrefabColliderDef({
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
  });

  final int offsetX;
  final int offsetY;
  final int width;
  final int height;

  PrefabColliderDef copyWith({
    int? offsetX,
    int? offsetY,
    int? width,
    int? height,
  }) {
    return PrefabColliderDef(
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'offsetX': offsetX,
      'offsetY': offsetY,
      'width': width,
      'height': height,
    };
  }

  static PrefabColliderDef fromJson(Map<String, Object?> json) {
    return PrefabColliderDef(
      offsetX: (json['offsetX'] as num?)?.toInt() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}
