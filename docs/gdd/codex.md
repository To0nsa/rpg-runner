# Théodonis and the Codex

Town opens the regional map from the world-reference PDF, with Store and
Library callouts around Théodonis. The map supports dragging, zooming and
resetting. These callouts identify city services, not precise buildings on a
street map. Back from either service returns to Town.

The Store retains its earned-gold offers and refresh rules. The Library is
free to browse; discoveries cannot be purchased.

## Discoveries

| Entry | Requirement | What becomes readable |
| --- | --- | --- |
| Regular enemy, including boss summons | Defeat that enemy type 10 times | Attacks and damage types, resistances, weaknesses, behaviour and field notes |
| Boss | Defeat that boss 5 times | The same complete combat and lore entry |
| Forest | Reach 10,000 in one Competitive run on Forest | Forest history and current crisis |
| Field | Reach 10,000 in one Competitive run on Field | Open-land context and the journey |
| Éloïse's opening journal | Available immediately | The black sky and the expedition's starting premise |

Kills accumulate across confirmed Practice, Competitive and Weekly runs, on
either character. Each enemy type has its own count. Bosses are Bringer of
Death, Voidborn Goddess, Shoggoth and Voidcaller. Their summoned creatures
use the regular ten-kill rule.

Level scores are separate lifetime bests. Practice and Weekly scores do not
unlock Places. Scores from multiple runs are not added. Discoveries persist
across seasons. Runs must finish and pass replay validation before progress
appears; pending, rejected and local Developer Practice runs do not count.
Progress starts with runs processed by the Codex-enabled backend; historical
runs are not reconstructed.

Bestiary supports All, Enemies and Bosses filters. Locked entries show their
name, category, current progress and exact requirement. Opening one explains
its gate without revealing combat details or lore. Unlocked entries expose
the full page. There are no partial purchases or additional currencies.

Combat information reflects the current game catalogs, including mixed damage
shares and secondary boss attacks. Innate resistances and weaknesses are
explicitly separated; an empty category states that none exist.

## Narrative continuity

The PDF timeline supersedes the earlier 200-year proposal. The historical
overview places this episode approximately six centuries before *Les Soleils
d'or*. The playable Éloïse is the PDF character, aged seventeen at the black-sky
episode. The opening journal starts when she sees the black sky above the
forest; it does not reveal her later fate.

The user's premise is authoritative for the runner: the forest's cultists and
associated creatures help the power responsible for the black sky. The PDF
also describes a demonic cult corrupting the ancient forest behind the
diversion of the orc war. Enemy field notes connect present encounters to that
crisis. Exact remote origins of bosses are left unknown where the references
do not establish them; these encounter descriptions do not invent a separate
pantheon or transplant later-era named townspeople into this period.

References: *Lothringen - Les Soleils d'or - Guide du maitre.pdf*, historical
overview (physical page 3, printed pages 4–5), Éloïse (physical page 31,
printed pages 60–61), and regional map (physical page 2); companion world
brand and naming references in `C:/dev/Lothringen/Brand/`.

The regional art provides orientation around Théodonis. Its later-era labels
do not establish the historical date or street plan of the runner's Town.
See [implementation and persistence](../tdd/codex.md).
