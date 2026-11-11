import 'package:run_protocol/codecs/json_value_copy.dart';

import '../../campaign/campaign_catalog.dart';

/// Only backend-settled clears can unlock missions or characters.
final class CampaignProgress {
  const CampaignProgress._(this._missions);
  static const empty = CampaignProgress._({});
  final Map<String, Object?> _missions;

  factory CampaignProgress.fromJson(Object? raw) {
    if (raw == null) return empty;
    if (raw is! Map || raw['schemaVersion'] != 1 || raw['missions'] is! Map) {
      throw const FormatException('Invalid campaign progress.');
    }
    final missions = Map<String, Object?>.from(raw['missions'] as Map);
    for (final value in missions.values) {
      if (value is! Map ||
          value['cleared'] is! bool ||
          value['attempts'] is! int ||
          (value['attempts'] as int) < 0 ||
          value['bests'] is! Map) {
        throw const FormatException('Invalid campaign mission progress.');
      }
    }
    return CampaignProgress._(
      immutableJsonObject(missions, fieldName: 'missions'),
    );
  }
  bool isCleared(String id) => (_missions[id] as Map?)?['cleared'] == true;
  int attempts(String id) =>
      ((_missions[id] as Map?)?['attempts'] as int?) ?? 0;
  bool chapterCleared(CampaignChapter chapter) =>
      chapter.missions.every((m) => isCleared(m.id));
  bool isUnlocked(CampaignMission mission) {
    for (final chapter in CampaignCatalog.chapters) {
      final index = chapter.missions.indexWhere((m) => m.id == mission.id);
      if (index >= 0) {
        return chapter.missions.take(index).every((m) => isCleared(m.id));
      }
    }
    return false;
  }

  int? bestScore(String id) {
    final bests = (_missions[id] as Map?)?['bests'] as Map?;
    final key =
        '${CampaignCatalog.contentDigest}_v${CampaignCatalog.rewardPolicyVersion}';
    return (bests?[key] as Map?)?['score'] as int?;
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'missions': mutableJsonObjectCopy(_missions, fieldName: 'missions'),
  };
}
