import '../l10n/app_localization.dart';

enum DisplayNameProblem {
  required,
  tooShort,
  tooLong,
  characters,
  reserved,
  disallowed;

  String message(AppLocalizations l10n) => switch (this) {
    required => l10n.nameRequired,
    tooShort => l10n.nameTooShort(min: DisplayNamePolicy.minLen),
    tooLong => l10n.nameTooLong(max: DisplayNamePolicy.maxLen),
    characters => l10n.nameCharacters,
    reserved => l10n.nameReserved,
    disallowed => l10n.nameDisallowed,
  };
}

class DisplayNamePolicy {
  const DisplayNamePolicy();

  static const int minLen = 3;
  static const int maxLen = 16;

  static final RegExp allowed = RegExp(r'^[a-zA-Z0-9 _-]+$');

  static const Set<String> reservedNormalized = <String>{
    'admin',
    'moderator',
    'mod',
    'support',
    'staff',
    'developer',
    'dev',
    'system',
  };

  static const List<String> bannedSubstringsNormalized = <String>[
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'cunt',
    'nazi',
  ];

  String normalize(String input) {
    final trimmed = input.trim();
    final collapsed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.toLowerCase();
  }

  DisplayNameProblem? validate(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return DisplayNameProblem.required;
    if (name.length < minLen) return DisplayNameProblem.tooShort;
    if (name.length > maxLen) return DisplayNameProblem.tooLong;
    if (!allowed.hasMatch(name)) {
      return DisplayNameProblem.characters;
    }

    final n = normalize(name);
    if (reservedNormalized.contains(n)) {
      return DisplayNameProblem.reserved;
    }
    for (final bad in bannedSubstringsNormalized) {
      if (n.contains(bad)) return DisplayNameProblem.disallowed;
    }
    return null;
  }
}
