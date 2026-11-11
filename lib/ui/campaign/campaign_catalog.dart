import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';

import 'generated_campaign_catalog.dart';

/// Presentation metadata from the same build as the server and Core mission catalog.
final class CampaignCatalog {
  static String get contentDigest =>
      campaignCatalogData['contentDigest'] as String;
  static int get rewardPolicyVersion =>
      campaignCatalogData['rewardPolicyVersion'] as int;
  static final chapters = List<CampaignChapter>.unmodifiable(
    (campaignCatalogData['chapters'] as List).cast<Map<String, Object?>>().map(
      CampaignChapter.new,
    ),
  );
  static CampaignMission? mission(String id) {
    for (final chapter in chapters) {
      for (final mission in chapter.missions) {
        if (mission.id == id) return mission;
      }
    }
    return null;
  }
}

final class CampaignChapter {
  CampaignChapter(Map<String, Object?> source)
    : id = source['id'] as String,
      titles = Map<String, String>.from(source['title'] as Map),
      descriptions = Map<String, String>.from(source['description'] as Map),
      mapX = (source['mapX'] as num).toDouble(),
      mapY = (source['mapY'] as num).toDouble(),
      rewardCharacter = source['rewardCharacterId'] == null
          ? null
          : PlayerCharacterId.values.byName(
              source['rewardCharacterId'] as String,
            ),
      missions = List.unmodifiable(
        (source['missions'] as List).cast<Map<String, Object?>>().map(
          CampaignMission.new,
        ),
      );
  final String id;
  final Map<String, String> titles, descriptions;
  final double mapX, mapY;
  final PlayerCharacterId? rewardCharacter;
  final List<CampaignMission> missions;
  String title(String language) => titles[language] ?? titles['en']!;
  String description(String language) =>
      descriptions[language] ?? descriptions['en']!;
}

final class CampaignMission {
  CampaignMission(Map<String, Object?> source)
    : id = source['id'] as String,
      available = source['available'] as bool,
      levelId = LevelId.values.byName(source['levelId'] as String),
      firstClearXp = source['firstClearXp'] as int,
      rewardAbilityId = source['rewardAbilityId'] as String?,
      titles = Map<String, String>.from(source['title'] as Map),
      descriptions = Map<String, String>.from(source['description'] as Map);
  final String id;
  final bool available;
  final LevelId levelId;
  final int firstClearXp;
  final String? rewardAbilityId;
  final Map<String, String> titles, descriptions;
  String title(String language) => titles[language] ?? titles['en']!;
  String description(String language) =>
      descriptions[language] ?? descriptions['en']!;
}
