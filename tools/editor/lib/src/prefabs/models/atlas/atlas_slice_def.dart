import 'package:flutter/foundation.dart';

import '../shared/model_json_utils.dart';

/// Authoring-time atlas rectangle definition in pixel units.
///
/// [sourceImagePath] is workspace-relative (for example
/// `assets/images/level/...`) so persisted data remains portable across
/// machines.
@immutable
class AtlasSliceDef {
  const AtlasSliceDef({
    required this.id,
    required this.sourceImagePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.tags = const <String>[],
  });

  final String id;
  final String sourceImagePath;
  final int x;
  final int y;
  final int width;
  final int height;
  final List<String> tags;

  AtlasSliceDef copyWith({
    String? id,
    String? sourceImagePath,
    int? x,
    int? y,
    int? width,
    int? height,
    List<String>? tags,
  }) {
    return AtlasSliceDef(
      id: id ?? this.id,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'sourceImagePath': sourceImagePath,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  static AtlasSliceDef fromJson(Map<String, Object?> json) {
    final rawTags = json['tags'];
    final tags = <String>[];
    if (rawTags is List<Object?>) {
      for (final value in rawTags) {
        if (value is! String) {
          continue;
        }
        final normalized = value.trim();
        if (normalized.isEmpty) {
          continue;
        }
        tags.add(normalized);
      }
    }
    return AtlasSliceDef(
      id: PrefabModelJson.normalizedString(json['id']),
      sourceImagePath: PrefabModelJson.normalizedString(
        json['sourceImagePath'],
      ),
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      tags: tags,
    );
  }
}
