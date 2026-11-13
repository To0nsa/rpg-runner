import 'dart:convert';
import 'dart:io';

import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:test/test.dart';

CampaignJournalEntry entry(String name) => CampaignJournalEntry(
  title: {'en': name, 'fr': 'FR $name'},
  body: {'en': '$name body\n\nSecond paragraph.', 'fr': 'FR $name texte'},
);

void main() {
  final source = File('../../assets/authoring/campaign/chapter_defs.json')
      .readAsStringSync();

  test('optional entries round-trip at all scopes and preserve stable IDs', () {
    final catalog = CampaignCatalogSource.decode(source);
    final json = catalog.toJson();
    json['journal'] = entry('Opening').toJson();
    final chapter = (json['chapters'] as List).first as Map;
    chapter['journal'] = entry('Chapter').toJson();
    final mission = (chapter['missions'] as List).first as Map;
    mission['journal'] = entry('Mission').toJson();
    final changed = CampaignCatalogSource.decode(jsonEncode(json));
    expect(jsonDecode(changed.encode()), json);
    expect(changed.journal!.bodyFor('fr'), 'FR Opening texte');
    expect(changed.journal!.bodyFor('de'), 'Opening body\n\nSecond paragraph.');
    expect(
      changed.missions.map((m) => m.id),
      catalog.missions.map((m) => m.id),
    );
    expect(changed.settingsToJson()['journal'], entry('Opening').toJson());

    json.remove('journal');
    chapter.remove('journal');
    mission.remove('journal');
    final removed = CampaignCatalogSource.decode(jsonEncode(json));
    expect(removed.journal, isNull);
    expect(removed.chapters.first.journal, isNull);
    expect(removed.missions.first.journal, isNull);
    expect(removed.toJson().containsKey('journal'), isFalse);
  });

  test('entry rejects missing, null, blank, oversized and unknown fields', () {
    for (final invalid in [
      null,
      [],
      {},
      {
        'title': {'en': 'Title', 'fr': 'Titre'},
      },
      {
        'title': {'en': 'Title'},
        'body': {'en': 'Body', 'fr': 'Texte'},
      },
      {
        'title': {'en': 'Title', 'fr': 'Titre'},
        'body': null,
      },
      {
        'title': {'en': 'Title', 'fr': 'Titre'},
        'body': {'en': 'Body', 'fr': ' '},
      },
      {...entry('Good').toJson(), 'unknown': true},
      {
        'title': {'en': 'x' * 121, 'fr': 'Titre'},
        'body': {'en': 'Body', 'fr': 'Texte'},
      },
      {
        'title': {'en': 'Title', 'fr': 'Titre'},
        'body': {'en': 'Body', 'fr': 'x' * 12001},
      },
    ]) {
      expect(() => CampaignJournalEntry.decode(invalid), throwsFormatException);
    }
    for (final scope in ['campaign', 'chapter', 'mission']) {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final chapter = (json['chapters'] as List).first as Map;
      final owner = switch (scope) {
        'campaign' => json,
        'chapter' => chapter,
        _ => (chapter['missions'] as List).first as Map,
      };
      owner['journal'] = null;
      expect(
        () => CampaignCatalogSource.decode(jsonEncode(json)),
        throwsFormatException,
        reason: scope,
      );
    }
    final titles = {'en': 'Immutable', 'fr': 'Immuable'};
    final value = CampaignJournalEntry(
      title: titles,
      body: {'en': 'Body', 'fr': 'Texte'},
    );
    titles['en'] = 'Changed';
    expect(value.titleFor('en'), 'Immutable');
    expect(() => value.title['en'] = 'Changed', throwsUnsupportedError);
  });

  final content = CampaignJournalContent(
    opening: entry('Opening'),
    chapters: [
      CampaignJournalChapter(
        id: 'val',
        introduction: entry('Val'),
        missions: [
          CampaignJournalMission(
            id: 'arrival',
            available: true,
            update: entry('Arrival'),
          ),
          CampaignJournalMission(
            id: 'grove',
            available: false,
            update: entry('Secret grove'),
          ),
          CampaignJournalMission(
            id: 'trail',
            available: true,
            update: entry('Trail'),
          ),
        ],
      ),
      CampaignJournalChapter(
        id: 'future',
        introduction: entry('Future secret'),
        missions: [
          CampaignJournalMission(
            id: 'future_mission',
            available: false,
            update: entry('Future outcome'),
          ),
        ],
      ),
    ],
  );

  test(
    'confirmed clears reveal each published update once in authored order',
    () {
      List<String> visible(Set<String> cleared) => content
          .visibleEntries(isCleared: cleared.contains)
          .map((e) => e.id)
          .toList();
      expect(visible({}), ['opening', 'chapter:val']);
      expect(visible({'arrival'}), [
        'opening',
        'chapter:val',
        'mission:arrival',
      ]);
      final earned = {'arrival', 'trail', 'grove', 'future_mission', 'retired'};
      final expected = [
        'opening',
        'chapter:val',
        'mission:arrival',
        'mission:trail',
      ];
      expect(visible(earned), expected);
      expect(
        visible(earned),
        expected,
        reason: 'replay/refresh does not append duplicates',
      );
      expect(visible({}), [
        'opening',
        'chapter:val',
      ], reason: 'account reset hides earned entries');
    },
  );

  test(
    'editor checkpoint includes drafts only through the selected mission',
    () {
      expect(content.previewAfter(null).map((e) => e.id), ['opening']);
      expect(content.previewAfter('grove').map((e) => e.id), [
        'opening',
        'chapter:val',
        'mission:arrival',
        'mission:grove',
      ]);
      expect(
        content.previewAfter('future_mission').last.entry.titleFor('fr'),
        'FR Future outcome',
      );
      expect(() => content.previewAfter('missing'), throwsArgumentError);
      expect(content.chapters.first.missions[1].available, isFalse);
    },
  );
}
