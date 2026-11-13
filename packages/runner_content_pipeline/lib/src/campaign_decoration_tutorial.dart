part of '../campaign_tutorial.dart';

/// One passable-scenery explanation on landing beyond a referenced pool.
/// A unique single-sprite prefab is required: repeated or tiled prefabs cannot
/// silently change which object the author intended to highlight.
final class CampaignDecorationTutorial extends CampaignPanelTutorial {
  CampaignDecorationTutorial._(
    super.json, {
    required this.missionChunkId,
    required this.waterRegionId,
    required this.decorationPrefabKey,
  }) : super._();

  factory CampaignDecorationTutorial.decode(Object? value) {
    final json = _decodePanel(
      value,
      'decoration',
      CampaignTutorialTrigger.waterCleared,
      null,
      extraFields: {'missionChunkId', 'waterRegionId', 'decorationPrefabKey'},
    );
    final chunk = json['missionChunkId'];
    final water = json['waterRegionId'];
    final prefab = json['decorationPrefabKey'];
    if (chunk is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(chunk) ||
        water is! String ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(water) ||
        prefab is! String ||
        !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(prefab)) {
      throw const FormatException(
        'Decoration guidance requires a chunk, water region and prefab key.',
      );
    }
    return CampaignDecorationTutorial._(
      json,
      missionChunkId: chunk,
      waterRegionId: water,
      decorationPrefabKey: prefab,
    );
  }

  @override
  final String missionChunkId;
  final String waterRegionId, decorationPrefabKey;
  @override
  String get kind => 'decoration';
  @override
  CampaignTutorialTrigger get trigger => CampaignTutorialTrigger.waterCleared;
  @override
  CampaignTutorialTarget get target => CampaignTutorialTarget.decoration;

  WaterRegionData resolveWater(CampaignMissionDefinition mission) =>
      _resolveTutorialWater(mission, id, missionChunkId, waterRegionId);

  /// Resolve current captured geometry; invalid attachments fail Build/Play,
  /// including disabled lessons. No tutorial state is stored in Core.
  ChunkVisualSpriteRel resolveDecoration(CampaignMissionDefinition mission) {
    final chunk =
        mission.route.missionChunks[mission.missionChunkIndex(missionChunkId)];
    final sprite = campaignTutorialDecorations(chunk.pattern.visualSprites)
        .where((sprite) => sprite.prefabKey == decorationPrefabKey)
        .firstOrNull;
    if (sprite == null) {
      throw FormatException(
        'Tutorial $id: $decorationPrefabKey must be a unique single-sprite decoration in $missionChunkId.',
      );
    }
    return sprite;
  }

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'missionChunkId': missionChunkId,
      'waterRegionId': waterRegionId,
      'decorationPrefabKey': decorationPrefabKey,
    });

  static CampaignDecorationTutorial introduction({
    required String missionChunkId,
    required String waterRegionId,
    required String decorationPrefabKey,
  }) => CampaignDecorationTutorial.decode({
    'id': 'decoration_introduction',
    'name': 'Decorations and obstacles',
    'enabled': true,
    'trigger': 'waterCleared',
    'kind': 'decoration',
    'missionChunkId': missionChunkId,
    'waterRegionId': waterRegionId,
    'decorationPrefabKey': decorationPrefabKey,
    'title': {'en': 'Scenery or obstacle?', 'fr': 'Décor ou obstacle ?'},
    'instruction': {
      'en': 'Decorations have a pale white tint. You can walk through them. Solid obstacles, like the rock you crossed, block your path. Release, then move again to continue.',
      'fr': 'Les éléments de décor ont une teinte blanchâtre. Tu peux les traverser. Les obstacles solides, comme le rocher que tu as franchi, bloquent ton chemin. Relâche puis bouge à nouveau pour continuer.',
    },
    'spotlight': const TutorialSpotlight(shape: TutorialSpotlightShape.ellipse)
        .toJson(),
    'reveals': <String>[],
  });
}

/// Selectable decoration targets share one rule between authoring and runtime.
/// Prefab identity survives reorder, move, scale and rotation; ambiguity fails.
List<ChunkVisualSpriteRel> campaignTutorialDecorations(
  Iterable<ChunkVisualSpriteRel> sprites,
) {
  final counts = <String, int>{};
  for (final sprite in sprites) {
    final key = sprite.prefabKey;
    if (key != null) counts[key] = (counts[key] ?? 0) + 1;
  }
  return List.unmodifiable(
    sprites.where((s) => s.isDecoration && counts[s.prefabKey] == 1),
  );
}

/// Axis-aligned bounds of the rendered sprite in chunk-local world units,
/// including rotation around its center. Shared by live and authoring previews.
({double x, double y, double width, double height})
campaignTutorialSpriteBounds(ChunkVisualSpriteRel sprite) {
  final angle = sprite.rotationDegrees * math.pi / 180;
  final cos = math.cos(angle).abs(), sin = math.sin(angle).abs();
  final width = sprite.width * cos + sprite.height * sin;
  final height = sprite.width * sin + sprite.height * cos;
  return (
    x: sprite.x + (sprite.width - width) / 2,
    y: sprite.y + (sprite.height - height) / 2,
    width: width,
    height: height,
  );
}
