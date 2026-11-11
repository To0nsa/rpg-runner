import 'codecs/json_value_reader.dart';

/// Server-selected mission and immutable content/reward policy for one attempt.
/// Progress unlocks use the stable mission ID; replays bind the exact digest.
final class CampaignBinding {
  CampaignBinding({
    required this.missionId,
    required this.contentDigest,
    this.rewardPolicyVersion = 1,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(missionId)) {
      throw ArgumentError.value(missionId, 'missionId', 'invalid mission ID');
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(contentDigest)) {
      throw ArgumentError.value(
        contentDigest,
        'contentDigest',
        'invalid SHA-256',
      );
    }
    if (rewardPolicyVersion != 1) {
      throw ArgumentError.value(
        rewardPolicyVersion,
        'rewardPolicyVersion',
        'unsupported policy',
      );
    }
  }

  final String missionId;
  final String contentDigest;
  final int rewardPolicyVersion;

  Map<String, Object?> toJson() => {
    'missionId': missionId,
    'contentDigest': contentDigest,
    'rewardPolicyVersion': rewardPolicyVersion,
  };

  factory CampaignBinding.fromJson(Object? raw) {
    final json = asObjectMap(raw, fieldName: 'campaign');
    try {
      return CampaignBinding(
        missionId: readRequiredString(json, 'missionId'),
        contentDigest: readRequiredString(json, 'contentDigest'),
        rewardPolicyVersion: readRequiredInt(json, 'rewardPolicyVersion'),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CampaignBinding &&
      missionId == other.missionId &&
      contentDigest == other.contentDigest &&
      rewardPolicyVersion == other.rewardPolicyVersion;
  @override
  int get hashCode =>
      Object.hash(missionId, contentDigest, rewardPolicyVersion);
}
