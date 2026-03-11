# Firebase + Google Sign-In + Play Games + Anonymous Auth + Firestore — EU compliance checklist

This document is a **practical implementation checklist** for a mobile game that uses:

* Firebase Authentication

  * Anonymous auth
  * Google Sign-In
  * Google Play Games sign-in
* Cloud Firestore
* Google Play distribution

It is written for a small game studio / solo developer perspective.

It is **not legal advice**. It is the concrete engineering and product work you should do so the app is materially closer to compliance with **EU GDPR + Google Play policy**.

---

## 1. What you are actually processing

With this stack, you are processing **personal data** under EU law, even if you never ask for a real name manually.

That is because the app can process things such as:

* Firebase UID
* Google account identifiers
* Play Games account identifiers and profile data
* device-linked or account-linked records in Firestore
* gameplay progress tied to a user or pseudonymous account
* authentication logs
* IP/network metadata processed by providers

The GDPR is technology-neutral and applies whenever personal data is processed in an organized way. ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))

**Action:** treat this project as a personal-data processing system from day one.

---

## 2. Your role: controller, and Google/Firebase as processor or separate party depending on the feature

For your game backend and player data model, you are typically the **data controller** for the data you decide to collect and store for your game features.

Google/Firebase provides contractual data-processing terms for Firebase services. Firebase also documents privacy/security information and data transfer mechanisms for its services. ([firebase.google.com](https://firebase.google.com/terms/data-processing-terms?utm_source=chatgpt.com))

For **Google Play Games Services**, Google states that user data made available through PGS may be used **solely to provide and improve your games**, and **must not be used for advertising purposes**. ([developer.android.com](https://developer.android.com/games/pgs/terms?utm_source=chatgpt.com))

**Action:**

* Document internally which systems you control.
* Document which Google/Firebase products you use.
* Do not reuse Play Games user data for ads, profiling, or unrelated marketing.

---

## 3. The minimum legal/operational baseline you need

You need, at minimum:

1. a **privacy policy**
2. an accurate **record of what data you collect and why**
3. a defined **lawful basis** for each processing purpose
4. **data minimization**
5. **retention rules**
6. **user-rights handling**
7. **secure access control** in Firestore
8. Google Play **Data safety** answers that match reality
9. **account deletion** support if users can create/link accounts

This comes directly out of GDPR principles like transparency, purpose limitation, data minimization, storage limitation, integrity/confidentiality, and accountability. Legitimate interest is possible in some cases, but only if you actually assess and justify it. ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))

---

## 4. Lawful basis — do not lump everything together

Do **not** use one vague sentence like “we process data to run the game.”

Break your processing into purposes.

### Recommended purpose map

#### A. Authentication and account management

Examples:

* anonymous sign-in
* Google sign-in
* Play Games sign-in
* account linking
* session restoration
* anti-abuse checks tied to auth state

**Most defensible basis:**

* **contract necessity** for features the user actively requests
* sometimes **legitimate interest** for security/abuse prevention

#### B. Saving progress and cloud-linked player data

Examples:

* save files in Firestore
* unlocked abilities/gears
* progression, inventory, settings

**Most defensible basis:**

* **contract necessity** when these are part of the service the user uses

#### C. Support / account recovery / deletion handling

Examples:

* responding to user requests
* restoring access
* deletion logs

**Most defensible basis:**

* **contract necessity** or **legal obligation**, depending on context

#### D. Product analytics / gameplay telemetry

Examples:

* death causes
* level completion
* weapon pick rate
* session funnel

**Do not assume this is exempt.** This can still be personal-data processing if tied to a persistent identifier. Depending on implementation, this may rely on **legitimate interest** or may require user choice/consent under local tracker rules. The CNIL notes limited consent exemptions can exist for strict audience measurement under conditions, including user information and an objection mechanism. ([cnil.fr](https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications?utm_source=chatgpt.com))

**Action:** separate analytics from auth in both code and legal documentation.

---

## 5. What to build in the app UI

### Mandatory / strongly recommended screens

#### Settings or Profile screen

Add these entries:

* `Privacy Policy`
* `Delete Account`
* `Export / Request My Data` or support contact for this request
* `Linked Accounts`
* `Analytics Preferences` if you later add analytics beyond strictly necessary processing

#### Account-linking UI

For Google / Play Games linking:

* explain the **benefit** first

  * save progress across devices
  * enable achievements / social game features
* link only on explicit user action if not silently auto-authenticated
* state that privacy details are in the privacy policy

This is not the same as a GDPR popup. It is product transparency.

#### Deletion UI

If your app enables account creation or linking, Google Play requires:

* an **in-app path** to delete the app account and associated data
* a **web link** where users can request deletion outside the app

Google Play explicitly requires this for apps with app accounts. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))

---

## 6. What must be in your privacy policy

Your privacy policy should be public and also reachable **inside the app**. Google Play requires a publicly accessible privacy policy and, where personal/sensitive data is handled, also requires it within the app. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))

### Include these sections

#### Identity of the controller

* studio / company / sole trader name
* email contact for privacy requests
* postal/business address if applicable

#### Data categories

List clearly:

* authentication identifiers
* linked account data
* player progression/save data
* support/deletion request data
* optional analytics data, if any

#### Purposes

For example:

* authenticate the player
* restore saved progress across devices
* store unlocked items and game state
* provide Play Games features such as achievements/leaderboards
* secure accounts and prevent abuse
* handle support and deletion requests

#### Lawful bases

Map each purpose to its legal basis.

#### Recipients / processors

Disclose that data may be processed using:

* Firebase Authentication
* Cloud Firestore
* Google Play Games Services
* Google Play / Google infrastructure as relevant

#### International transfers

Firebase states Google relies on recognized transfer solutions, including the EU-U.S. Data Privacy Framework where applicable. The European Commission’s adequacy decision for the EU-U.S. DPF remains in force, and the Finnish DPA explains that adequacy decisions allow transfers without additional safeguards to participating companies. ([firebase.google.com](https://firebase.google.com/support/privacy?utm_source=chatgpt.com))

You should still say plainly that some data may be processed outside the EU/EEA through Google/Firebase infrastructure, and reference the safeguards/framework relied upon.

#### Retention

State how long you keep:

* active account/save data
* anonymous guest data
* deletion logs
* support emails/tickets
* backups if applicable

#### User rights

Mention rights to:

* access
* rectification
* erasure
* restriction
* objection where applicable
* complaint to a supervisory authority

#### How to exercise rights

Provide one real channel:

* support email
* web form
* in-app request route

---

## 7. Data minimization rules you should enforce technically

This is where most indie projects get sloppy.

### For Firebase Auth

Do:

* store only the auth identifier(s) you need
* avoid copying profile data you do not actually use
* avoid persisting avatar URL, display name, locale, etc. unless they are required by a real feature

Do not:

* mirror all Google profile fields into Firestore “just in case”
* keep stale linked-provider metadata forever

### For Anonymous Auth

Anonymous does **not** mean outside GDPR. Treat anonymous UID-linked progress as personal data if it remains attributable to a user/device/session pattern.

Do:

* define a clear retention period for abandoned anonymous accounts
* clean up orphaned anonymous user documents after inactivity

### For Firestore

Do:

* store game data under player-owned paths
* keep schemas narrow
* avoid event logs that grow forever
* avoid storing raw debugging blobs in production

Do not:

* store full sign-in tokens
* store secrets client-side in Firestore
* keep free-form sensitive notes about users

---

## 8. Firestore security is not optional

Firestore Security Rules are one of the core technical controls here. Firebase explicitly documents Security Rules as the layer protecting your data and recommends using Firebase Authentication with Firestore Rules for user-based access systems. ([firebase.google.com](https://firebase.google.com/docs/rules?utm_source=chatgpt.com))

### Minimum rule posture

* a user can read/write only their own documents unless a stricter rule applies
* validate document shape on writes
* reject unknown fields where practical
* reject writes to admin/system-owned collections from clients
* separate public game content from private player data

### Minimum engineering tasks

* write Firestore Security Rules for every collection
* add emulator tests for the rules
* verify anonymous users can only touch their own guest data
* verify linked users cannot read another player’s save
* verify account-link migration does not expose old guest data to the wrong UID

If your rules are weak, your compliance story is already broken even if your privacy policy looks polished.

---

## 9. Account deletion flow — build this properly

This matters for both GDPR and Google Play.

### In-app deletion flow

You need a user-visible path like:

`Profile > Account > Delete account`

The flow should:

* explain what will be deleted
* explain what may remain temporarily in backups/logs
* require explicit confirmation
* delete or queue deletion of:

  * Firebase Auth user
  * Firestore player data keyed by UID
  * any linked gameplay profile data

Firebase documents user deletion in Auth, and provides a Delete User Data extension that can delete Firestore/Realtime Database/Storage data keyed by the user ID when the user is deleted. ([firebase.google.com](https://firebase.google.com/docs/auth/web/manage-users?utm_source=chatgpt.com))

### Recommended implementation

* Use Firebase Auth user deletion for the account identity.
* Use the Firebase `delete-user-data` extension or an equivalent backend function to cascade-delete player data by UID.
* Record a minimal deletion audit entry that does **not** retain unnecessary personal data.

### Also required

Provide a **web link** outside the app for deletion requests, because Google Play requires an out-of-app path too. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))

---

## 10. Google Play obligations you must complete

### A. Privacy policy on the Play listing

It must be public and accessible. Google Play requires this. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))

### B. Privacy policy inside the app

If your app accesses, collects, uses, or shares personal and sensitive user data, Google Play requires the privacy policy within the app too. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))

### C. Data Safety form

You must complete the Play Console **Data safety** form accurately. The Data Safety section is shown on the store listing; it is not the same as an in-app disclosure. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en&utm_source=chatgpt.com))

### D. Data deletion section

You must answer the Play Console data deletion questions consistently with your actual in-app deletion flow. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))

### E. Prominent disclosure and consent

This is **not automatically required** just because you use Firebase Auth. But if you collect/use/share personal or sensitive user data in ways not reasonably expected or not clearly disclosed, Google Play may require prominent in-app disclosure and affirmative consent. ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))

For your current stack, auth + save-sync generally belongs in the expected core functionality bucket if disclosed properly.

---

## 11. What to say about Google Play Games specifically

Google Play Games Services data is restricted in purpose.

You should document that PGS data is used only to:

* authenticate/link the player where applicable
* provide Play Games features
* improve the game experience in relation to those features

And you should explicitly avoid using PGS data for advertising use cases, because Google forbids that. ([developer.android.com](https://developer.android.com/games/pgs/terms?utm_source=chatgpt.com))

---

## 12. International transfers — what you need to do in practice

Do not panic here, but do not ignore it either.

### Practical baseline

* Review Firebase/Google contractual terms in the project owner account.
* Keep a note of the Google/Firebase terms and transfer mechanism you rely on.
* Mention international processing/transfers in the privacy policy.
* Avoid adding extra third-party SDKs without checking transfers and contracts first.

Firebase states it uses recognized transfer solutions including the Data Privacy Framework where applicable, and Google’s cloud contractual materials also refer to data transfer solutions and SCC-based alternatives where needed. The EU adequacy decision for the EU-U.S. DPF is in force. ([firebase.google.com](https://firebase.google.com/support/privacy?utm_source=chatgpt.com))

This does **not** remove your accountability. It just means the provider-side transfer framework is not something you should invent yourself.

---

## 13. Retention policy — define one now

If you do not define retention, you will keep junk forever. That is bad engineering and bad GDPR hygiene.

### Recommended first pass

* **Linked account save data:** keep while account is active
* **Anonymous guest accounts with no activity:** auto-delete after a defined inactivity period, for example 90–180 days, depending on your recovery design
* **Deletion request records:** keep only what is necessary to prove handling and defend against disputes, for a limited period
* **Support emails:** define a retention period, e.g. 12–24 months unless legally needed longer
* **Operational logs:** keep short and narrow

**Action:** put the exact periods in your policy and backend ops checklist.

---

## 14. Data subject rights — what you must actually be able to do

You need an operational response path for:

* access request
* deletion request
* correction request
* objection request where applicable
* complaint escalation details

For a small game, this can be simple:

* one support email address
* one internal playbook
* one export path for player save/profile data

If you cannot locate, export, or delete a user’s data by UID/provider link, your system is not operationally compliant.

---

## 15. Concrete backlog: what to build now

### P0 — mandatory before release

* [ ] Create a public privacy policy page
* [ ] Add `Privacy Policy` inside the app
* [ ] Inventory all data fields stored in Firebase Auth + Firestore
* [ ] Write the purpose + lawful-basis map
* [ ] Implement Firestore Security Rules for every collection
* [ ] Add tests for Firestore Rules
* [ ] Add in-app `Delete Account` flow
* [ ] Add out-of-app deletion request page/link
* [ ] Implement actual user-data deletion by UID
* [ ] Complete Google Play Data Safety form accurately
* [ ] Complete Google Play data deletion section accurately
* [ ] Ensure PGS data is not reused for ads/marketing

### P1 — strongly recommended

* [ ] Add retention rules for anonymous and linked users
* [ ] Add scheduled cleanup for abandoned anonymous accounts
* [ ] Add a support workflow for data-access and deletion requests
* [ ] Add an internal data map document
* [ ] Avoid duplicating Google profile metadata in Firestore
* [ ] Add privacy/version tracking so policy changes are auditable

### P2 — needed later when analytics/ads arrive

* [ ] Separate analytics preference controls from auth/account linking
* [ ] Assess whether analytics can rely on legitimate interest or need consent
* [ ] Add EU consent flow for ads/marketing tracking if introduced
* [ ] Re-check Data Safety answers when SDKs/features change

---

## 16. Recommended architecture decisions for your game

### Good

* guest play allowed by default
* optional account linking
* Firestore player document keyed by UID
* strict per-user security rules
* account deletion cascade
* minimal profile data copy

### Bad

* auto-copying all provider profile fields into Firestore
* no retention for anonymous accounts
* weak or global Firestore rules
* no delete path
* mixing auth consent, analytics consent, and ads consent into one vague popup
* using Play Games data for anything ad-related

---

## 17. What this does **not** cover completely

This checklist is focused on:

* GDPR basics relevant to your current stack
* Google Play obligations
* technical implementation hygiene

It does **not** fully cover, unless you add them later:

* ads consent frameworks
* children-directed processing / age-gating regimes
* biometric/location/contact data
* employee/contractor internal compliance
* full Records of Processing Activities formalization
* DPIA requirements in edge cases

If you later add ads, attribution SDKs, broader analytics, or child-targeted features, re-open this document and expand the compliance scope.

---

## 18. The blunt version

For your current stack, the work is not “show a GDPR popup.”

The real work is:

* know what data you collect
* justify why you collect it
* disclose it clearly
* secure it properly
* delete it when requested
* answer Google Play honestly
* do not over-collect

That is the actual compliance backbone.

---

## 19. Source anchors

Key official references used for this checklist:

* European Commission — GDPR/data protection overview and individuals’ rights ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/data-protection-explained_en?utm_source=chatgpt.com))
* European Commission — legitimate interest overview ([commission.europa.eu](https://commission.europa.eu/law/law-topic/data-protection/rules-business-and-organisations/legal-grounds-processing-data/grounds-processing/what-does-grounds-legitimate-interest-mean_en?utm_source=chatgpt.com))
* EDPB — Guidelines 1/2024 on legitimate interest ([edpb.europa.eu](https://www.edpb.europa.eu/system/files/2024-10/edpb_guidelines_202401_legitimateinterest_en.pdf?utm_source=chatgpt.com))
* CNIL — analytics/audience measurement conditions and objection requirement ([cnil.fr](https://www.cnil.fr/en/sheet-ndeg16-use-analytics-your-websites-and-applications?utm_source=chatgpt.com))
* Firebase — privacy/security information and data transfer information ([firebase.google.com](https://firebase.google.com/support/privacy?utm_source=chatgpt.com))
* Firebase — Security Rules / Firestore access control documentation ([firebase.google.com](https://firebase.google.com/docs/rules?utm_source=chatgpt.com))
* Firebase — delete user / delete user data extension ([firebase.google.com](https://firebase.google.com/docs/extensions/official/delete-user-data?utm_source=chatgpt.com))
* Google Play — Data Safety requirements ([support.google.com](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en&utm_source=chatgpt.com))
* Google Play — privacy policy + prominent disclosure guidance ([support.google.com](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en&utm_source=chatgpt.com))
* Google Play — account deletion requirements ([support.google.com](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en&utm_source=chatgpt.com))
* Google Play Games Services terms ([developer.android.com](https://developer.android.com/games/pgs/terms?utm_source=chatgpt.com))
* EU-U.S. Data Privacy Framework adequacy decision and Finnish DPA summary ([eur-lex.europa.eu](https://eur-lex.europa.eu/eli/dec_impl/2023/1795/oj/eng?utm_source=chatgpt.com))

---

## 20. Next practical step

After this checklist, the highest-value next deliverables are:

1. a **data inventory table** for your exact Firebase/Auth/Firestore fields
2. a **privacy policy draft** tailored to your game
3. a **Firestore deletion + retention design**
4. a **Play Console Data Safety answer sheet** for your current implementation
