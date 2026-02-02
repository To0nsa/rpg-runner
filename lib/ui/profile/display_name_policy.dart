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

  String? validate(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return 'Name is required.';
    if (name.length < minLen) return 'Name must be at least $minLen characters.';
    if (name.length > maxLen) return 'Name must be at most $maxLen characters.';
    if (!allowed.hasMatch(name)) {
      return 'Only letters, numbers, spaces, "_" and "-" are allowed.';
    }

    final n = normalize(name);
    if (reservedNormalized.contains(n)) {
      return 'That name is reserved.';
    }
    for (final bad in bannedSubstringsNormalized) {
      if (n.contains(bad)) return 'That name is not allowed.';
    }
    return null;
  }
}
