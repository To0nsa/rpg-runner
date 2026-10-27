# Android build identities

Android uses explicit `dev`, `staging` and `prod` flavors. Build mode controls
debugging/optimization; it does not select the backend. Flutter defaults to dev.
Staging/prod expose release variants only, with separate upload signing; missing
signing inputs fail instead of falling back to the debug key.

| Flavor | Modes | Package | Launcher | Firebase project |
| --- | --- | --- | --- | --- |
| dev | debug, profile, release | `com.example.rpg_runner.dev` | Long Run Dev | `rpg-runner-d7add` |
| staging | release | `com.lothringen.longrun.staging` | Long Run Staging | `lothringen-long-run-staging` |
| prod | release | `com.lothringen.longrun` | Long Run | `lothringen-long-run-prod` |

Separate staging and production Play listings reserve the branded packages.
Production listing `4975092661531994619` replaces the role of the old empty draft;
that draft and its earlier configuration remain intact. Play distribution setup
and installed-app acceptance remain open in the
[active checklist](../building/android_beta_release.md). This table describes
source configuration, not three accepted or published installations.

The flavors share the [game icon source and exports](../release-assets/android/README.md).
Launcher labels distinguish development and staging installations.

## Build and installation

Use `flutter run --flavor dev -d <device-id>` or
`flutter build apk --flavor dev --release` from the repository root.
The APK is `build/app/outputs/flutter-apk/app-dev-release.apk`.
Prepare navigation before standalone builds. Candidates use canonical
Checkout/Prepare, then `tools/release/release.ps1 -Action BuildAndroid
-Environment <name> -AndroidVersionCode <allocated-code>`; see the
[deployment contract](deployment_workflow.md). Allocate codes from Play history.

Keep the normal pub step when switching native build modes. Flutter 3.47.1
regenerates plugin registration there, excluding development-only plugins from
release. `--no-pub` can retain `IntegrationTestPlugin` in generated Java while
Gradle excludes it from the release classpath. Regenerate through Flutter; do not
edit generated Java or add testing plugins to runtime dependencies.

Each package isolates Firebase sessions, preferences, ownership outbox, replay
spool and ghost cache. Separate backend projects isolate Auth and remote game
state, including for the same Google account. No cross-environment migration is
implemented. The sole owner's disposable dev-data exception does not apply to
future players. Existing ordinary updates preserve that installation's state.

Dev retains workstation debug signing in all modes. Developer Practice is
available only in debug, including `--dart-define=DEVELOPER_PRACTICE=true`;
release/profile require account services. Staging/prod use project-local protected
upload keys. Play's distribution certificate is a different installed-app
identity and must be registered separately after Play App Signing enrollment.

Local signing recovery copies and temporary build keys stay outside every
checkout, in `C:\dev\lothringen-secrets/<environment>` on this workstation.
The release tool defaults to the common repository's sibling `lothringen-secrets`
folder; an external absolute `LOTHRINGEN_SECRETS_DIR` overrides it. Recovery copies
use Windows DPAPI and the folder is restricted to the operator and SYSTEM.

## Firebase, Play Games and App Check

Genuine Firebase downloads live at
`android/app/src/<flavor>/google-services.json`. Gradle selects the matching
package; native Firebase initialization supplies no overriding Dart options.
`FirebaseEnvironment` rejects absent/unknown flavors and verifies the initialized
project before constructing app services or activating attestation.

| Flavor | Firebase Android app |
| --- | --- |
| dev | `1:964001571974:android:1a4b98db937af313d81d07` |
| staging | `1:943085064373:android:51c288ba51386d01572efc` |
| prod | `1:696550437718:android:c27d2030dcee3fd2d9dcf7` |

Refresh with `firebase apps:sdkconfig ANDROID <app-id> --project <project-id>
--out <new-temporary-file>`, verify package/project, then replace that flavor's
file. Do not fabricate IDs or edit package strings in downloaded JSON. Earlier
unused registrations remain preserved and are not selected by the new flavors.

Flavor `res/values/strings.xml` owns launcher, Play Games project and server
OAuth client. Dev's server client is
`964001571974-dajrtiro395fjpise2ibskleearagtgm.apps.googleusercontent.com`;
the Android OAuth credential ending `clto6jp9c5a1g46jmoiahanmlcodggbt` is not a
server client. Existing dev credentials are preserved. New environments need
their own game/Cloud linkage, Android package/certificate credentials, server
OAuth client, Firebase Play Games provider and tester/publication configuration.
Staging's game is linked to its Cloud project, and Firebase's enabled Play Games
provider uses web client
`943085064373-cgchd3tftpkgv4f30q01k3aqblqa5vls.apps.googleusercontent.com`.
The same client is saved as its draft Play Games game-server credential and is
present in the downloaded Firebase config and explicit native resource. Android
distribution credentials are configured for all three Play signing certificates.
Production's server client is
`696550437718-6n2bu175hk96rn77o8cob7ht6pcr2h4s.apps.googleusercontent.com`,
shared by its enabled Firebase provider, native resource and draft Play Games
server credential. Both OAuth audiences remain External/Testing, owner only,
with the explicitly approved `games`, `games_lite` and `drive.appdata` scopes.
Production Android credentials, publication and installed-app acceptance remain pending.
There is no cross-project authentication bridge or bypass.

Dev uses App Check's debug provider in every mode; register installation tokens
only in its dev Firebase app and keep them out of source/log evidence.
Staging/prod require Play Integrity and reject configured debug tokens.
App Check does not replace authentication or backend authorization. Acceptance
must use the actual Play-distributed certificate and integrity verdict; an
upload-signed sideload or successful hub screen is insufficient evidence.

Update-required links open that flavor's package. Dev asks for the current
development build instead. Maintenance gates new issuance while existing
submission/recovery and account navigation remain available. See
[run startup](run_startup.md) for structured responses.

## Diagnostics and other platforms

Crashlytics is disabled by native default, then enabled only after verifying an
Android staging/prod release environment. Uploaded Dart errors retain stack
frames and error type without exception text, account IDs or request payloads.
Previous handlers are retained; reporting failures do not recursively report
themselves. No Analytics SDK or custom behavioral telemetry was added.
Real event delivery and readable release traces remain acceptance checks.

Options > Settings exposes Privacy policy and Contact support in both online
and local Practice profiles. They open the shared public dev-Hosting policy path
`https://rpg-runner-d7add.web.app/privacy-policy.html` and the confirmed support
mailbox in an external handler. A missing handler leaves navigation usable and
shows the address. `web/privacy-policy.html` identifies the confirmed operator,
Nicolas Louis, and documents account/gameplay processing, diagnostics, provider
transfers, retention and rights. It links to `web/account-deletion.html`.
The owner confirmed Finland and deletion of support correspondence 90 days after
resolution. Both pages are prepared source, not evidence of publication or live
acceptance. The mailbox retention policy requires operator handling; the app does
not automatically manage support email.

Web stays local Practice without Firebase. Apple/Windows generated Firebase
options still refer to dev and are outside this Android production rollout;
their bundle identities are unchanged.

## Validation and historical evidence

The [beta execution record](../verification/android-beta-2026-10-26.md) records
current builds, failures/retries, signing and remaining device/online acceptance.
Unit tests compare native configuration with the registry and reject wrong-project
pairings. Artifact inspection verifies actual resources, signatures, navigation,
permissions, APIs, ABIs and page alignment. Three side-by-side Play-authenticated
installations remain a release gate.

Before flavors both packages shared the old backend. The October 21 CPH2465 setup
and October 25 `a4f99b89` builds are historical, not new-environment acceptance.
Workstation debug SHA-1
`74:B0:81:6A:97:FE:84:86:35:C8:BD:30:F9:70:A9:18:E3:EB:6A:6E`,
dev Play credential and device App Check registration were preserved.
See [previous release evidence](../verification/game-compat-2026.10.21-production.md).

References: [Android variants](https://developer.android.com/build/build-variants),
[Firebase config selection](https://firebase.google.com/docs/android/google-services-plugin-and-file),
[Play Games credentials](https://developer.android.com/games/pgs/console/setup),
[Crashlytics Flutter setup](https://firebase.google.com/docs/crashlytics/flutter/get-started).
