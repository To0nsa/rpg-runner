# App Check Client Rollout Evidence — July 19, 2026

## Scope and authorization

The repository owner authorized direct production deployment to
`rpg-runner-d7add` because no staging project exists and the game is not live.
This record covers the web client rollout and one controlled production-origin
attestation. It supplements the
[production deployment](production-deployment-2026-07-19.md) and
[production verification](production-verification-2026-07-19.md) records. It
does not alter the immutable July 18 audit.

App Check enforcement remained in `monitor` mode throughout. Firebase Auth,
exact UID authorization, request bounds, and all existing server-side guards
remained unchanged.

## Production configuration

The Firebase App Check and reCAPTCHA Enterprise APIs were enabled. A
score-based reCAPTCHA Enterprise key named
`RPG Runner Firebase App Check web` was created with exactly these allowed
domains:

- `rpg-runner-d7add.web.app`;
- `rpg-runner-d7add.firebaseapp.com`.

Firebase App Check binds that key to web app
`1:964001571974:web:97acd9d8974e215dd81d07` with:

- token TTL: 3,600 seconds;
- minimum score: 0.5;
- integration type: `SCORE`.

The public site key is injected into the Flutter release with
`FIREBASE_APP_CHECK_WEB_SITE_KEY`. It is not stored in source, documentation,
or the smoke output. Release web clients use
`ReCaptchaEnterpriseProvider`; debug behavior remains unchanged.

## Build and deployment

Validation and build results:

- `dart analyze`: passed with no issues;
- targeted auth/bootstrap Flutter suite: 12/12 passed;
- `flutter build web --release` with the production site-key define: passed;
- the release bundle contained the injected key;
- bundle size: 3,452,545 bytes.

Firebase Hosting release details:

- site: `rpg-runner-d7add`;
- version:
  `projects/964001571974/sites/rpg-runner-d7add/versions/4a5f6b9928bdc2ea`;
- live release:
  `projects/964001571974/sites/rpg-runner-d7add/channels/live/releases/1784473690236000`;
- release time: `2026-07-19T15:08:10.236Z`;
- URL: `https://rpg-runner-d7add.web.app`;
- live/local `main.dart.js` SHA-256 match: yes;
- SHA-256:
  `6588584c24a96b1fda182c7fd74901926c33b7a704fe97172652bbdb8ba96b95`.

The Firebase CLI reported that `firebase.json` contains an unknown top-level
`flutter` property. This did not prevent the Hosting deployment and is
unrelated to App Check, but it should be considered during the final repository
cleanup review.

## Controlled production attestation

`tool/app_check_production_smoke.mjs` launched headless Edge with a fresh
temporary profile on the live Hosting origin. The smoke used the same Firebase
web app and Enterprise provider configuration as the deployed Flutter bundle,
obtained an App Check token, and sent it to the auth-gated
`playerProfileLoad` callable. The token and site key were never printed.

Observed client result:

- production origin: `rpg-runner-d7add.web.app`;
- token exchange: succeeded;
- token length: 960 bytes;
- callable response: HTTP 401;
- response reached the expected Firebase Auth gate: yes.

The HTTP 401 is the expected result because the controlled request deliberately
did not include Firebase Auth. Server-side Cloud Logging at
`2026-07-19T15:19:05Z` recorded:

- function: `playerProfileLoad`;
- rollout mode: `monitor`;
- token status: `verified`;
- app ID: the configured production web app.

This gives one verified production-origin web observation out of one
controlled attempt. It proves the web provider, domain restriction, App Check
exchange, token attachment, Functions verification, and subsequent Auth gate
are compatible. It is not a statistically meaningful success rate and does
not represent Android, iOS, macOS, or Windows.

## Readiness decision

Web is deployment-capable and has a verified end-to-end attestation sample.
Global callable App Check enforcement is not ready:

- no Android Play Integrity release measurement exists;
- no iOS App Attest/DeviceCheck release measurement exists;
- macOS has no release measurement;
- Windows App Check remains unsupported by the current client SDK;
- the game has no live traffic from which to calculate a sustained,
  platform-specific verified-token rate.

Before global enforcement, every in-scope release platform must either produce
measured legitimate attestations or be explicitly excluded from the
Firebase-backed release. The current `monitor` default is the rollback:
missing or invalid App Check context remains observable without weakening Auth
or UID checks.

The subsequent
[native readiness preflight](native-app-check-readiness-2026-07-19.md)
inventoried the registered providers, release identities, signing state,
available devices, and current production observations. It added a reusable
native smoke entrypoint but found that Android and Apple still lack the
prerequisites for a legitimate release-device measurement. Global enforcement
therefore remains off.
