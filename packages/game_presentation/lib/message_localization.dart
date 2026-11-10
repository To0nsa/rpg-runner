/// Authored inbox text. English fallback is retained in the message's title/body.
class MessageText {
  const MessageText({required this.title, required this.body});
  final String title, body;
  Map<String, String> toJson() => {'title': title, 'body': body};
}

/// Versioned optional presentation envelope shared by the game and operator tool.
/// Locale never affects delivery identity, rewards or ownership.
class MessageLocalization {
  MessageLocalization._(Map<String, MessageText> translations)
    : translations = Map.unmodifiable(translations);

  final Map<String, MessageText> translations;

  factory MessageLocalization.fromJson(
    Object? raw, {
    bool allowIncompleteDraft = false,
  }) {
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw.keys.any(
          (key) => !{'schemaVersion', 'translations'}.contains(key),
        )) {
      throw const FormatException('Unsupported message localization.');
    }
    final entries = raw['translations'];
    if (entries is! Map || entries.isEmpty || entries.length > 8) {
      throw const FormatException('Use one to eight translations.');
    }
    final result = <String, MessageText>{};
    for (final entry in entries.entries) {
      final locale = entry.key;
      final value = entry.value;
      if (locale is! String ||
          locale == 'en' ||
          !RegExp(r'^[a-z]{2,3}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?$')
              .hasMatch(locale) ||
          value is! Map ||
          value.keys.any((key) => !{'title', 'body'}.contains(key))) {
        throw const FormatException('Invalid translation.');
      }
      result[locale] = MessageText(
        title: _text(value['title'], 120, allowIncompleteDraft),
        body: _text(value['body'], 2000, allowIncompleteDraft),
      );
    }
    return MessageLocalization._(result);
  }

  /// Exact tag, then progressively less specific tags; absent text uses English.
  MessageText? resolve(String localeTag) {
    var tag = localeTag.replaceAll('_', '-');
    while (true) {
      final text = translations[tag];
      if (text != null) return text;
      final separator = tag.lastIndexOf('-');
      if (separator < 0) return null;
      tag = tag.substring(0, separator);
    }
  }

  Map<String, Object> toJson() => {
    'schemaVersion': 1,
    'translations': {
      for (final locale in translations.keys.toList()..sort())
        locale: translations[locale]!.toJson(),
    },
  };

  static String _text(Object? raw, int limit, bool draft) {
    if (raw is! String ||
        (!draft && raw.trim().isEmpty) ||
        raw.length > limit) {
      throw const FormatException('Invalid translated text.');
    }
    return draft ? raw : raw.trim();
  }
}
