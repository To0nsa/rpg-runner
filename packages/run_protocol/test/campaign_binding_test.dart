import 'package:run_protocol/run_protocol.dart';
import 'package:test/test.dart';

void main() {
  final binding = CampaignBinding(
    missionId: 'reporting_for_duty',
    contentDigest: 'a' * 64,
  );
  RunTicket ticket({
    RunMode mode = RunMode.campaign,
    CampaignBinding? campaign,
  }) => RunTicket(
    runSessionId: 'campaign_run',
    uid: 'player',
    mode: mode,
    campaign: campaign,
    seed: 1,
    tickHz: 30,
    gameCompatVersion: '2026.11.11',
    levelId: 'forest',
    playerCharacterId: 'eloise',
    loadoutSnapshot: const {'mask': 7},
    loadoutDigest: 'digest',
    issuedAtMs: 1,
    expiresAtMs: 2,
    singleUseNonce: 'nonce',
  );
  test(
    'mission binding is mandatory only in campaign and cannot carry a board',
    () {
      expect(RunMode.campaign.requiresBoard, isFalse);
      expect(() => ticket(), throwsArgumentError);
      expect(
        () => ticket(mode: RunMode.practice, campaign: binding),
        throwsArgumentError,
      );
      final issued = ticket(campaign: binding);
      expect(RunTicket.fromJson(issued.toJson()).campaign, binding);
      expect(issued.tickHz, 30);
      expect(
        () => BoardKey(
          mode: RunMode.campaign,
          levelId: 'forest',
          windowId: 'none',
          rulesetVersion: 'v1',
          scoreVersion: 'v1',
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'replay digest includes mission identity without changing old payloads',
    () {
      ReplayBlobV1 replay(CampaignBinding? campaign) =>
          ReplayBlobV1.withComputedDigest(
            runSessionId: 'run',
            tickHz: 30,
            seed: 1,
            levelId: 'forest',
            playerCharacterId: 'eloise',
            loadoutSnapshot: const {'mask': 7},
            totalTicks: 1,
            commandStream: [ReplayCommandFrameV1(tick: 1)],
            campaign: campaign,
          );
      final old = replay(null);
      expect(old.toCanonicalPayloadJson().containsKey('campaign'), isFalse);
      final campaign = replay(binding);
      expect(campaign.canonicalSha256, isNot(old.canonicalSha256));
      expect(ReplayBlobV1.fromJson(campaign.toJson()).campaign, binding);
      final changed = campaign.toJson()
        ..['campaign'] = CampaignBinding(
          missionId: 'holding_the_outpost',
          contentDigest: 'a' * 64,
        ).toJson();
      expect(() => ReplayBlobV1.fromJson(changed), throwsFormatException);
    },
  );
  test(
    'constructors and decoders reject malformed binding versions and IDs',
    () {
      expect(
        () => CampaignBinding(missionId: '../mission', contentDigest: 'a' * 64),
        throwsArgumentError,
      );
      expect(
        () => CampaignBinding(
          missionId: 'mission',
          contentDigest: 'a' * 64,
          rewardPolicyVersion: 2,
        ),
        throwsArgumentError,
      );
      expect(
        () => CampaignBinding.fromJson({
          ...binding.toJson(),
          'contentDigest': 'oops',
        }),
        throwsFormatException,
      );
    },
  );
}
