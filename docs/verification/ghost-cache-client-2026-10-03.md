# Ghost cache client release: October 3, 2026

Published to [production Hosting](https://rpg-runner-d7add.web.app) on
October 3, 2026 at 10:37 Helsinki time from frozen commit
`8d7d9bdcf492efb38622622489df6b6cf694f5ad`.
Gameplay remains `2026.10.3`, with `rules-v2`, `score-v3`, and `ghost-v1`.

## Failure and fix

The installed Android app reproduced a Forest Competitive ghost-launch failure.
The debugger captured `FileSystemException: Cannot open file` with
`OS Error: File name too long, errno = 36` while saving the verified replay.
The leaderboard catch handler presented a generic connection message.

Ghost cache filenames now use SHA-256 hashes of JSON identity arrays. The
147-byte name includes the full board/entry identity and replay version without
embedding arbitrarily long IDs. Entry pruning also uses the full identity, so
ghosts sharing a long board prefix cannot evict one another. Superseded versions
of the same entry are still pruned; replay integrity checks remain unchanged.
Old Base64-named temporary files are cold misses and remain subject to OS cleanup.

## Validation and deployment

- Focused analysis and nine ghost cache/application-state tests passed.
- Frozen `Prepare` passed client analysis (`lib`, `test`, `test_driver`), all
  876 client tests with no skips or failures, and the production web build.
- `Plan` selected `Hosting`. The initial ordinary checkout reported a gameplay
  mismatch because of source line endings; the canonical LF checkout matched
  the production simulation inputs without a compatibility change.
- `Deploy` verified the existing Functions identity, healthy unchanged worker,
  preceding web artifact, unpaused healthy issuer, and running replay queues
  before publishing. The new live `main.dart.js` matched the prepared hash.
- No run cancellation, issuance pause, backend deployment, or worker deployment
  was needed. Historical run, reward, leaderboard, and ghost data were retained.

Artifact evidence:

- Source fingerprint:
  `dade71497bb18271a8056dd9f355f86390918613daf6d4e38c9b4d4f5bc8e2d5`.
- Prepared web tree:
  `b2cba038845dff143e071a09407c12ad3b9d92e15513bf06f101245c2380a95d`.
- Verified live `main.dart.js`:
  `de79d4d6faf4f2f11b56e8a8f57b5404b17fb1d1a3064cd467095c20abc48ac3`.
- Unchanged worker image digest:
  `sha256:623b70d08d69ae65ea6018839504fb31ab63efe5b057d9c476018d643119b082`.
- Hosting checkpoint: `2026-10-03T07:36:52.9307961Z`;
  verified deployment: `2026-10-03T07:37:04.7301365Z`.

The release manifest, component logs, and JSON test report remain under the
frozen checkout's `.tmp/releases/rpg-runner-d7add/<source-fingerprint>/`.

## Android installation and device verification

The fixed debug APK was built and installed on the connected CPH2465 running
Android 15, retaining app data. Android reports installation at 10:18:43 on
October 3. APK SHA-256:
`389ddda287dbdd7fead5597e7cb154e6766c4a8b60199c60ed551abab51eb0e9`.
This was a direct device installation, not an app-store release.

After the owner unlocked the phone, the Forest Competitive rank-1 ghost
(score 9350, distance 962m, duration 02:18) launched successfully at about 11:24
Helsinki time. The app reached `Tap to start` and wrote a 166,878-byte replay
under the new 147-byte filename. Gameplay started and rendered the translucent
ghost independently of the live character. The stationary smoke player fell
behind after three seconds; the existing best leaderboard entry remained intact.

A second launch of the same entry also reached the start screen, reused the
cache file without changing its timestamp, and rendered the ghost ahead of the
player. It was left paused at `00:01` for the owner. The local screenshot
`.tmp/ghost-diagnostic/ghost-verify-paused.png` records that state. No source or
production changes were needed for this follow-up check.

This completes the specific Android ghost-launch/cache/render regression check.
The broader linked Play Games gameplay/replay/once-only settlement and
retired-version smoke in the
[release checklist](../building/rescue_release_operations.md) remains open;
this short playback observation does not establish those outcomes.
