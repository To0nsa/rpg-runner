class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.displayNameLastChangedAtMs,
    required this.namePromptCompleted,
  });

  final String displayName;
  final int displayNameLastChangedAtMs;
  final bool namePromptCompleted;

  static const UserProfile empty = UserProfile(
    displayName: '',
    displayNameLastChangedAtMs: 0,
    namePromptCompleted: false,
  );

  UserProfile copyWith({
    String? displayName,
    int? displayNameLastChangedAtMs,
    bool? namePromptCompleted,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      displayNameLastChangedAtMs:
          displayNameLastChangedAtMs ?? this.displayNameLastChangedAtMs,
      namePromptCompleted: namePromptCompleted ?? this.namePromptCompleted,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'displayName': displayName,
      'displayNameLastChangedAtMs': displayNameLastChangedAtMs,
      'namePromptCompleted': namePromptCompleted,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final displayNameRaw = json['displayName'];
    final displayNameLastChangedAtMsRaw = json['displayNameLastChangedAtMs'];
    final namePromptCompletedRaw = json['namePromptCompleted'];
    final displayName = displayNameRaw is String ? displayNameRaw.trim() : '';
    final displayNameLastChangedAtMs =
        displayNameLastChangedAtMsRaw is int
        ? displayNameLastChangedAtMsRaw
        : (displayNameLastChangedAtMsRaw is num
              ? displayNameLastChangedAtMsRaw.toInt()
              : 0);
    final namePromptCompleted = namePromptCompletedRaw is bool
        ? namePromptCompletedRaw
        : false;
    return UserProfile(
      displayName: displayName,
      displayNameLastChangedAtMs: displayNameLastChangedAtMs < 0
          ? 0
          : displayNameLastChangedAtMs,
      namePromptCompleted: namePromptCompleted,
    );
  }
}
