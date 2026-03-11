# Firebase + Play Games + Anonymous Auth + Firestore - EU compliance checklist

This document is a practical implementation checklist for a mobile game that uses:

- Firebase Authentication
  - Anonymous auth
  - Google Play Games sign-in
- Cloud Firestore
- Google Play distribution

It is written from a small game studio / solo developer perspective.

It is not legal advice. It is concrete engineering and product work that will move the app materially closer to compliance with EU GDPR and Google Play policy.

---

## 1. How to use this document

Use this checklist in three passes:

1. identify what data the current app actually processes
2. make sure the release baseline is covered
3. re-open the document whenever the stack changes, especially if you add analytics, ads, attribution SDKs, child-directed features, or more social features

The goal is not to "show a GDPR popup." The goal is to know what data you process, justify it, disclose it, secure it, and delete it when required.

---

## 2. Why this stack is in scope

With this stack, you are processing personal data under EU law even if you never ask for a real name manually.

Typical examples in this setup:

- Firebase UID
- Google account identifiers
- Play Games account identifiers and profile data
- device-linked or account-linked records in Firestore
- gameplay progress tied to a user or pseudonymous account
- authentication logs
- IP/network metadata processed by providers

The GDPR is technology-neutral and applies whenever personal data is processed in an organized way. ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))

Practical takeaway: treat this project as a personal-data processing system from day one.

---

## 3. Roles and platform constraints

For your game backend and player data model, you are typically the data controller for the data you decide to collect and store for your own features.

Google / Firebase provides contractual data-processing terms and service privacy/security materials for Firebase services. ([firebase.google.com](https://firebase.google.com/terms/data-processing-terms?utm_source=chatgpt.com))

Google Play Games Services data is restricted in purpose. Google states that user data made available through PGS may be used solely to provide and improve your games and must not be used for advertising purposes. ([developer.android.com](https://developer.android.com/games/pgs/terms?utm_source=chatgpt.com))

Practical takeaway:

- document which systems you control
- document which Google/Firebase products you use
- do not reuse Play Games data for ads, profiling, or unrelated marketing

---

## 4. Release baseline

Before release, this stack should have all of the following:

- a public privacy policy
- privacy-policy access inside the app
- a data inventory and purpose map
- a lawful-basis map for each processing purpose
- data minimization and retention rules
- a working path for user rights handling
- secure backend access control and tests
- in-app account deletion plus a web deletion resource if app accounts exist
- accurate Google Play Data Safety and account-deletion answers

This baseline comes directly from GDPR principles like transparency, purpose limitation, data minimization, storage limitation, integrity/confidentiality, and accountability. ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))

---

## 5. Workstream A - data inventory and lawful basis

Do not use one vague sentence like "we process data to run the game."

Break processing into purposes and record the data used for each one.

### Recommended purpose map

#### A. Authentication and account management

Examples:

- anonymous sign-in
- Play Games sign-in
- account linking
- session restoration
- anti-abuse checks tied to auth state

Most defensible basis:

- contract necessity for features the user actively requests
- sometimes legitimate interest for security / abuse prevention

#### B. Saving progress and cloud-linked player data

Examples:

- save files in Firestore
- unlocked abilities / gear
- progression, inventory, settings

Most defensible basis:

- contract necessity when these are part of the service the user uses

#### C. Support, account recovery, and deletion handling

Examples:

- responding to user requests
- restoring access
- deletion logs

Most defensible basis:

- contract necessity or legal obligation, depending on context

#### D. Analytics / telemetry later

Examples:

- death causes
- level completion
- weapon pick rate
- session funnel

Do not assume analytics is exempt. If it is tied to a persistent identifier, it can still be personal-data processing. Depending on implementation, this may rely on legitimate interest or may require user choice / consent under local tracker rules. As a France-specific example, the CNIL notes limited consent exemptions can exist for strict audience measurement under conditions, including user information and an objection mechanism. ([cnil.fr](https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications?utm_source=chatgpt.com))

Practical takeaway:

- keep a simple data inventory table
- map each purpose to a lawful basis
- keep analytics separate from auth and core gameplay processing

---

## 6. Workstream B - transparency and player-facing controls

### In-app UI baseline

The app should expose the following in a settings or profile area:

- `Privacy Policy`
- `Delete Account`
- `Export / Request My Data` or a support contact for that request
- `Linked Accounts`
- `Analytics Preferences` if analytics is added later beyond strictly necessary processing

### Account-linking UX

For Google / Play Games linking:

- explain the benefit first
- link only on explicit user action if not silently auto-authenticated
- state that privacy details are in the privacy policy

This is product transparency, not the same thing as a generic GDPR popup.

### Privacy policy contents

The privacy policy should be public and also reachable inside the app. Google Play's current User Data policy requires all apps to provide a privacy policy link in Play Console and a privacy policy link or text within the app itself. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en&utm_source=chatgpt.com))

The privacy policy should cover, at minimum:

- controller identity and privacy contact details
- data categories collected
- purposes of processing
- lawful bases
- recipients / processors
- international transfers
- retention periods
- user rights
- how users can exercise those rights

For user rights, mention at least:

- access
- rectification
- erasure
- data portability where applicable
- restriction
- objection where applicable
- complaint to a supervisory authority

### Deletion UX

If your app lets users create an app account from within the app, Google Play requires:

- an in-app path to delete the app account and associated data, or an in-app link to that deletion resource
- a web resource outside the app where account deletion can also be requested

([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))

Practical takeaway:

- keep privacy policy, deletion, linked accounts, and support / export access visible in one place
- use one real support or privacy contact channel

---

## 7. Workstream C - data handling and backend controls

### Data minimization

For Firebase Auth:

- store only the auth identifiers you need
- avoid copying profile data you do not actually use
- avoid persisting avatar URL, display name, locale, or similar fields unless a real feature requires them

Do not:

- mirror all Google profile fields into Firestore "just in case"
- keep stale linked-provider metadata forever

For anonymous auth:

- do not treat anonymous auth as outside GDPR
- define a retention period for abandoned anonymous accounts
- clean up orphaned anonymous user documents after inactivity

For Firestore:

- store game data under player-owned paths or server-controlled canonical paths
- keep schemas narrow
- avoid unbounded logs in production
- do not store full sign-in tokens
- do not store secrets client-side in Firestore

### Access control

Firestore Security Rules are one of the core technical controls here. Firebase explicitly documents Security Rules as the layer protecting your data and recommends using Firebase Authentication with Firestore Rules for user-based access systems. ([firebase.google.com](https://firebase.google.com/docs/rules?utm_source=chatgpt.com))

Minimum posture:

- users only access data they are supposed to access, unless a stricter deny-all design is used
- writes are shape-validated where practical
- admin/system collections are not writable from clients
- private player data is clearly separated from public game content

Minimum engineering tasks:

- write rules for every collection involved in player data
- add emulator-backed tests
- verify anonymous users cannot touch other users' data
- verify linked users cannot read another player's save
- verify account-link migration does not expose data to the wrong UID

### Account deletion implementation

A compliant deletion flow should:

- explain what will be deleted
- explain what may remain temporarily in backups or logs
- require explicit confirmation
- delete or queue deletion of the Firebase Auth user and associated backend data

Firebase documents Auth user deletion and provides a Delete User Data extension that can delete configured Firestore / Realtime Database / Storage data keyed by user ID. This is useful infrastructure, but it does not by itself guarantee legal compliance, and Firestore deletion behavior depends on how you configure it. ([firebase.google.com](https://firebase.google.com/docs/extensions/official/delete-user-data?utm_source=chatgpt.com))

Recommended implementation:

- use Firebase Auth user deletion for identity removal
- use the Firebase `delete-user-data` extension or an equivalent backend function to delete UID-scoped data
- verify the exact deletion scope you configured
- record only minimal deletion audit data

### Retention

If you do not define retention, you will keep junk forever.

Reasonable first pass:

- linked-account save data: keep while the account is active
- anonymous guest accounts with no activity: auto-delete after a defined inactivity period, for example 90-180 days depending on recovery design
- deletion request records: keep only what is necessary to prove handling and defend against disputes, for a limited period
- support emails: define a retention period, for example 12-24 months unless legally needed longer
- operational logs: keep short and narrow

### Rights handling

You need an operational response path for:

- access requests
- deletion requests
- correction requests
- objection requests where applicable
- portability requests where applicable
- complaint escalation details

If you cannot locate, export, or delete a user's data by UID / provider link, your system is not operationally compliant.

Practical takeaway:

- minimization, access control, deletion, retention, and rights handling should be treated as one workstream, not five disconnected tasks

---

## 8. Workstream D - Google Play obligations

Google Play work should be handled as a release checklist, not as an afterthought.

Required items:

- privacy policy link in Play Console
- privacy policy link or text inside the app
- accurate Data Safety form answers
- accurate account-deletion answers
- consistency between the Play listing, the app UI, and the backend behavior

Prominent disclosure and affirmative consent are not automatically required just because the app uses Firebase Auth. They become relevant when personal or sensitive user data is collected, used, or shared in ways that are not reasonably expected or not clearly disclosed. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))

For the current stack, auth plus cloud save / sync is usually part of expected core functionality if it is disclosed properly.

---

## 9. Special topics and later-scope items

### Google Play Games specific note

Document that Play Games Services data is used only to:

- authenticate or link the player where applicable
- provide Play Games features
- improve the game experience in relation to those features

Do not use Play Games data for advertising use cases.

### International transfers

Practical baseline:

- review Firebase / Google contractual terms in the project owner account
- note the transfer mechanism you rely on
- mention international processing / transfers in the privacy policy
- do not add extra third-party SDKs without checking transfers and contracts first

Firebase states it uses recognized transfer solutions including the Data Privacy Framework where applicable, and the EU adequacy decision for the EU-U.S. DPF remains in force. ([firebase.google.com](https://firebase.google.com/support/privacy?utm_source=chatgpt.com))

### Out of scope for now

This checklist does not fully cover, unless you add them later:

- ads consent frameworks
- children-directed processing / age-gating regimes
- biometric, location, contact-list, or similar sensitive categories
- employee / contractor internal compliance
- full Records of Processing Activities formalization
- DPIA requirements in edge cases

If you later add ads, attribution SDKs, broader analytics, or child-targeted features, reopen this document and expand the compliance scope.

---

## 10. Repo status snapshot (current implementation only)

This section is based only on the repository state as of March 11, 2026.

It is a practical engineering status check against the checklist above. It is not a legal sign-off, and it can go stale as soon as the implementation changes.

### Done

- [x] Firebase-backed app accounts already exist in practice through anonymous auth and optional Play Games linking (`lib/ui/state/firebase_auth_api.dart`).
- [x] There is an in-app Delete Account flow with two-step confirmation (`lib/ui/pages/profile/profile_page.dart`).
- [x] There is a backend account-deletion callable that deletes the Firebase Auth user and UID-scoped Firestore data including player profile, ownership data, and ghost data (`functions/src/index.ts`, `functions/src/account/delete.ts`).
- [x] Backend callables require authentication and reject mismatched `userId` values (`functions/src/index.ts`).
- [x] Firestore client access is locked down with deny-by-default rules (`firestore.rules`).
- [x] Emulator-backed backend tests exist for ownership and account-deletion flows (`functions/package.json`, `functions/test/account/account_delete_callable.test.ts`, `functions/test/ownership/ownership_callable.test.ts`).
- [x] Remote profile persistence now covers display name, display-name cooldown timestamp, and onboarding completion, while ownership stores server-side selection/meta/progression state (`functions/src/profile/store.ts`, `functions/src/ownership/contracts.ts`, `lib/ui/state/firebase_user_profile_remote_api.dart`).
- [x] The app still stores local leaderboard data in `SharedPreferences`, so that local data should still be disclosed (`lib/ui/leaderboard/shared_prefs_leaderboard_store.dart`).
- [x] No ads or analytics SDKs are visible in the current app dependencies (`pubspec.yaml`).

### Missing

- [ ] A public privacy-policy page / URL.
- [ ] A privacy-policy link or privacy-policy text inside the app. The current support page is still a placeholder (`lib/ui/pages/meta/support_page.dart`).
- [ ] An out-of-app account-deletion page or form on the web.
- [ ] A real support / privacy contact channel such as a support email or web form.
- [ ] A privacy policy that covers the exact data already processed today, including Firebase Auth identifiers, Play Games linking, display name, `displayNameLastChangedAtMs`, onboarding-completion status, server-side ownership / loadout / progression data, and local leaderboard data.
- [ ] Defined retention periods, especially for abandoned anonymous accounts and local / cloud player data.
- [ ] An operational path for access, export, correction, and deletion requests.
- [ ] Accurate Google Play Data Safety answers and account-deletion answers aligned to the current implementation.
- [ ] An internal note confirming that Firebase / Google terms and international-transfer wording are handled in the project owner setup and privacy policy.

### Not needed yet

- Ads consent / CMP is not needed yet unless ad SDKs are added later.
- Analytics consent UI or analytics preferences are not needed yet unless analytics / telemetry is added later.
- Extra prominent-disclosure UX is not automatically needed for the current auth / save / delete behavior unless data use expands beyond what a player would reasonably expect.

### Important interpretation

Because the app currently creates Firebase-authenticated anonymous users during bootstrap (`lib/ui/state/firebase_auth_api.dart`), the safest Google Play interpretation is to treat this as an app-account implementation and meet the account-deletion policy accordingly.

---

## 11. Source anchors

Key official references used for this checklist:

- European Commission - GDPR / data protection overview and individuals' rights ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))
- European Commission - legitimate interest overview ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/legal-grounds-processing-data/grounds-processing/what-does-grounds-legitimate-interest-mean_en?utm_source=chatgpt.com))
- EDPB - Guidelines 1/2024 on legitimate interest (consultation-stage draft at time of writing) ([edpb.europa.eu](https://www.edpb.europa.eu/system/files/2024-10/edpb_guidelines_202401_legitimateinterest_en.pdf?utm_source=chatgpt.com))
- CNIL - France-specific analytics / audience-measurement conditions and objection requirement ([cnil.fr](https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications?utm_source=chatgpt.com))
- Firebase - privacy / security information and data-transfer information ([firebase.google.com](https://firebase.google.com/support/privacy?utm_source=chatgpt.com))
- Firebase - Security Rules / Firestore access-control documentation ([firebase.google.com](https://firebase.google.com/docs/rules?utm_source=chatgpt.com))
- Firebase - delete-user-data extension ([firebase.google.com](https://firebase.google.com/docs/extensions/official/delete-user-data?utm_source=chatgpt.com))
- Google Play - User Data policy (privacy policy, account deletion, prominent disclosure) ([support.google.com](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en&utm_source=chatgpt.com))
- Google Play - Data Safety requirements ([support.google.com](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en&utm_source=chatgpt.com))
- Google Play - privacy policy + prominent disclosure guidance ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))
- Google Play - account deletion requirements ([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))
- Google Play Games Services terms ([developer.android.com](https://developer.android.com/games/pgs/terms?utm_source=chatgpt.com))
- EU-U.S. Data Privacy Framework adequacy decision ([eur-lex.europa.eu](https://eur-lex.europa.eu/eli/dec_impl/2023/1795/oj/eng?utm_source=chatgpt.com))

---

## 12. Next practical deliverables

After this checklist, the highest-value next deliverables are:

1. a data inventory table for the exact Firebase / Auth / Firestore / local-storage fields in the current app
2. a privacy-policy draft tailored to the current implementation
3. a deletion and retention design for anonymous and linked users
4. a Play Console Data Safety answer sheet for the current implementation
