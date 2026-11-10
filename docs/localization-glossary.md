# French localization glossary

French addresses the player as **tu**, with direct singular imperatives:
« Choisis », « Réessaie », « Récupère ». Avoid switching to *vous*. Error messages
state the problem and a useful action without exposing backend diagnostics.
Keep the grounded Lothringen tone; avoid modern slang in lore.

| English/source meaning | French | Usage |
| --- | --- | --- |
| Lothringen: The Long Run | Lothringen: The Long Run | Product name |
| Éloïse, Willow, Théodonis, Val | Unchanged | Canonical names and accents |
| Les Soleils d’or | Les Soleils d’or | Canonical proper name |
| Val Outpost | Avant-poste du Val | Location title |
| Léonards’ farm | Ferme des Léonards | Location title |
| Health | Santé | Resource/stat |
| Mana | Mana | Spellcaster resource |
| Supplies | Provisions | Willow resource; selected semantically before formatting |
| Stamina | Endurance | Resource/stat |
| Gold | Or | Currency; amounts use localized formatting |
| Damage | Dégâts | Combat quantity |
| Physical / Fire / Ice / Water | Physique / Feu / Glace / Eau | Damage types |
| Bleed / Burn / Stun | Saignement / Brûlure / Étourdissement | Status terminology |
| Silence | Silence | Status, not audio settings |
| Ability | Capacité | General action/skill |
| Spell | Sort | Magic action/projectile |
| Spellbook | Grimoire | Equipment slot |
| Accessory | Accessoire | Equipment slot |
| Build | Configuration | Player equipment/ability setup |
| Loadout | Équipement | Equipped setup; use context for a whole configuration |
| Claim | Récupérer | Reward action |
| Claimed | Récupéré | Reward state; agree with the surrounding noun when needed |
| Retry | Réessayer | Button; « Réessaie » in an instruction |
| Library / Store | Bibliothèque / Boutique | Town buildings |
| Equipment / Training Hall | Équipement / Salle d’entraînement | Permanent purchase services |
| Training Field | Terrain d’entraînement | Local build-testing surface |
| Level | Niveau | Account progression; location names are separate |
| Unoco Demon | Démon Unoco | Canonical enemy label |
| Grojib / Hashash / Derf | Unchanged | Canonical enemy names |
| Bringer of Death | Porteur de mort | Enemy label |
| Voidborn Goddess | Déesse née du Vide | Enemy label; match the shared catalog |
| Shoggoth | Shoggoth | Canonical enemy name |
| Voidcaller | Invocateur du Vide | Enemy label |
| Shoggoth Minion | Serviteur de Shoggoth | Enemy label |
| Void Tentacle | Tentacule du Vide | Enemy label |

The ARBs are the runtime source. This glossary records decisions, not a second
catalog: update it when terminology changes and keep descriptions, Codex and
shared labels consistent. Review generic roles separately from proper names.
Consult the parent repository's `Brand/Naming&Terminology.md`,
`Brand/Identity.md`, `Brand/CrossMediaExpressionRules.md` and world snapshots
before introducing or renaming canon. Those references are creative guidance,
not runtime dependencies.

Use real accents and typographic apostrophes in French. Let `intl` supply decimal
commas and non-breaking spaces for quantities/percentages. Preserve placeholder
names, IDs, URLs, markup and player-authored names. Do not translate a finished
string by replacing “Mana” or any other word; use the typed resource variant.

For ambiguous new terminology, record the context and chosen translation here
before using it across catalogs. French linguistic and device acceptance are
human review steps; automated key/placeholder checks cannot certify translation
quality or every screen layout.
