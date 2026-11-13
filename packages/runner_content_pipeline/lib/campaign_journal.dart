/// Bilingual authored prose. Journal visibility is presentation over confirmed
/// mission clears; it never grants progress or changes simulation state.
final class CampaignJournalEntry {
  CampaignJournalEntry({
    required Map<String, String> title,
    required Map<String, String> body,
  }) : title = _translations(title, 'journal.title', maxTitleLength),
       body = _translations(body, 'journal.body', maxBodyLength);

  static const maxTitleLength = 120;
  static const maxBodyLength = 12000;

  factory CampaignJournalEntry.decode(Object? value) {
    if (value is! Map ||
        value.length != 2 ||
        !value.containsKey('title') ||
        !value.containsKey('body')) {
      throw const FormatException('Journal entries require title and body.');
    }
    return CampaignJournalEntry(
      title: _translations(value['title'], 'journal.title', maxTitleLength),
      body: _translations(value['body'], 'journal.body', maxBodyLength),
    );
  }

  final Map<String, String> title, body;
  String titleFor(String language) => title[language] ?? title['en']!;
  String bodyFor(String language) => body[language] ?? body['en']!;
  Map<String, Object?> toJson() => {'title': title, 'body': body};
}

/// One update inherits the stable mission ID rather than a second unlock ID.
final class CampaignJournalMission {
  const CampaignJournalMission({
    required this.id,
    required this.available,
    required this.update,
  });
  final String id;
  final bool available;
  final CampaignJournalEntry? update;
}

final class CampaignJournalChapter {
  CampaignJournalChapter({
    required this.id,
    required this.introduction,
    required Iterable<CampaignJournalMission> missions,
  }) : missions = List.unmodifiable(missions);
  final String id;
  final CampaignJournalEntry? introduction;
  final List<CampaignJournalMission> missions;
}

typedef CampaignJournalItem = ({String id, CampaignJournalEntry entry});

/// Shared by the game and editor preview, in authored chapter/mission order.
/// Callers supply confirmed account progress or an explicit preview assumption.
final class CampaignJournalContent {
  CampaignJournalContent({
    required this.opening,
    required Iterable<CampaignJournalChapter> chapters,
  }) : chapters = List.unmodifiable(chapters);
  final CampaignJournalEntry? opening;
  final List<CampaignJournalChapter> chapters;

  /// Editorial checkpoint: include draft missions through this stable identity,
  /// without changing source inclusion or pretending to earn account progress.
  List<CampaignJournalItem> previewAfter(String? missionId) {
    if (missionId == null) {
      return [if (opening case final entry?) (id: 'opening', entry: entry)];
    }
    final preceding = <String>{};
    final visibleChapters = <CampaignJournalChapter>[];
    for (final chapter in chapters) {
      final missions = <CampaignJournalMission>[];
      for (final mission in chapter.missions) {
        preceding.add(mission.id);
        missions.add(
          CampaignJournalMission(
            id: mission.id,
            available: true,
            update: mission.update,
          ),
        );
        if (mission.id == missionId) break;
      }
      visibleChapters.add(
        CampaignJournalChapter(
          id: chapter.id,
          introduction: chapter.introduction,
          missions: missions,
        ),
      );
      if (preceding.contains(missionId)) {
        return CampaignJournalContent(
          opening: opening,
          chapters: visibleChapters,
        ).visibleEntries(isCleared: preceding.contains);
      }
    }
    throw ArgumentError.value(
      missionId,
      'missionId',
      'Unknown Journal checkpoint',
    );
  }

  List<CampaignJournalItem> visibleEntries({
    required bool Function(String missionId) isCleared,
  }) => [
    if (opening case final entry?) (id: 'opening', entry: entry),
    for (final chapter in chapters)
      if ((chapter.missions.firstOrNull?.available ?? false) ||
          chapter.missions.any((m) => m.available && isCleared(m.id))) ...[
        if (chapter.introduction case final entry?)
          (id: 'chapter:${chapter.id}', entry: entry),
        for (final mission in chapter.missions)
          if (mission.available && isCleared(mission.id))
            if (mission.update case final entry?)
              (id: 'mission:${mission.id}', entry: entry),
      ],
  ];
}

Map<String, String> _translations(Object? value, String path, int maximum) {
  if (value is! Map ||
      value.length != 2 ||
      !value.containsKey('en') ||
      !value.containsKey('fr')) {
    throw FormatException('$path requires English and French.');
  }
  return Map.unmodifiable({
    for (final language in ['en', 'fr'])
      language: switch (value[language]) {
        final String text
            when text.trim().isNotEmpty && text.length <= maximum =>
          text,
        _ => throw FormatException(
          '$path.$language needs text (max $maximum characters).',
        ),
      },
  });
}
