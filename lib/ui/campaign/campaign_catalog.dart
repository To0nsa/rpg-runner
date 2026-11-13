import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_content_pipeline/campaign_journal.dart';
import 'package:game_presentation/catalog_gift.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/player_character_definition.dart';

import 'generated_campaign_catalog.dart';

/// Presentation metadata from the same build as the server and Core mission catalog.
final class CampaignCatalog {
  static String title(String language) {
    final titles = campaignCatalogData['title'] as Map;
    return (titles[language] ?? titles['en']) as String;
  }

  static final map = Map<String, Object?>.unmodifiable(
    campaignCatalogData['map'] as Map,
  );
  static String get mapAssetPath => map['assetPath'] as String;
  static double get mapAspectRatio =>
      (map['width'] as int) / (map['height'] as int);
  static String get contentDigest =>
      campaignCatalogData['contentDigest'] as String;
  static int get rewardPolicyVersion =>
      campaignCatalogData['rewardPolicyVersion'] as int;
  static final chapters = List<CampaignChapter>.unmodifiable(
    (campaignCatalogData['chapters'] as List).cast<Map<String, Object?>>().map(
      CampaignChapter.new,
    ),
  );
  static final journal = CampaignJournalContent(
    opening: campaignCatalogData.containsKey('journal')
        ? CampaignJournalEntry.decode(campaignCatalogData['journal'])
        : null,
    chapters: [
      for (final chapter in chapters)
        CampaignJournalChapter(
          id: chapter.id,
          introduction: chapter.journal,
          missions: [
            for (final mission in chapter.missions)
              CampaignJournalMission(
                id: mission.id,
                available: mission.available,
                update: mission.journal,
              ),
          ],
        ),
    ],
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
      journal = source.containsKey('journal')
          ? CampaignJournalEntry.decode(source['journal'])
          : null,
      mapX = (source['mapX'] as num).toDouble(),
      mapY = (source['mapY'] as num).toDouble(),
      rewardCharacter = source['rewardCharacterId'] == null
          ? null
          : PlayerCharacterId.values.byName(
              source['rewardCharacterId'] as String,
            ),
      rewardXp = source['rewardXp'] as int,
      rewardGold = source['rewardGold'] as int,
      rewardItems = List.unmodifiable(
        (source['rewardItems'] as List).map(
          (v) => CatalogGift.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
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
  final int rewardXp, rewardGold;
  final List<CatalogGift> rewardItems;
  final List<CampaignMission> missions;
  final CampaignJournalEntry? journal;
  String title(String language) => titles[language] ?? titles['en']!;
  String description(String language) =>
      descriptions[language] ?? descriptions['en']!;
}

final class CampaignMission {
  CampaignMission(Map<String, Object?> source)
    : initialTutorialHud = source.containsKey('initialTutorialHud')
          ? decodeTutorialHud(source['initialTutorialHud'], initial: true)
          : allTutorialHud,
      tutorialSequences = decodeCampaignTutorials(
        source['tutorialSequences'] ?? const [],
      ),
      id = source['id'] as String,
      available = source['available'] as bool,
      levelId = LevelId.values.byName(source['levelId'] as String),
      firstClearXp = source['firstClearXp'] as int,
      firstClearGold = source['firstClearGold'] as int,
      firstClearItems = List.unmodifiable(
        (source['firstClearItems'] as List).map(
          (v) => CatalogGift.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
      ),
      titles = Map<String, String>.from(source['title'] as Map),
      descriptions = Map<String, String>.from(source['description'] as Map),
      journal = source.containsKey('journal')
          ? CampaignJournalEntry.decode(source['journal'])
          : null;
  final CampaignJournalEntry? journal;
  final String id;
  final bool available;
  final List<CampaignTutorialSequence> tutorialSequences;
  final Set<TutorialHudElement> initialTutorialHud;
  final LevelId levelId;
  final int firstClearXp, firstClearGold;
  final List<CatalogGift> firstClearItems;
  final Map<String, String> titles, descriptions;
  String title(String language) => titles[language] ?? titles['en']!;
  String description(String language) =>
      descriptions[language] ?? descriptions['en']!;
}
