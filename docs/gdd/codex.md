# Théodonis and the Codex

Town opens the supplied `assets/Théodonis.jpg` city map, with Store and
Library callouts inside the walled city. The image fills the available view,
cropping its edges initially; dragging reveals the remaining map. Pinch to
zoom and a small reset control remain. Service labels use Mist text and icons
with dark shadows, without borders or backgrounds. There is no instruction
footer or plus/minus zoom control. Indicator lines meet the beginning or end
of each label, with a small gap and no crossing through the icon or name.
Both service names and their white dot markers open their destinations. The Store points to the market streets and the Library to the large
northeastern courtyard complex. These are game navigation placements. Back
from either service returns to Town.

The Store retains its earned-gold offers and refresh rules. The Library is
free to browse; discoveries cannot be purchased.

## Discoveries

| Entry | Requirement | What becomes readable |
| --- | --- | --- |
| Regular enemy | Defeat that enemy type 10 times | Attacks and damage types, resistances, weaknesses, behaviour and field notes |
| Boss | Defeat that boss 5 times | The same complete combat and lore entry |
| Boss summons | Unlock their parent boss | Combat and field notes within that boss’s page |
| Val Outpost | Reach 10,000 in one Competitive run on Val Outpost | Its road watch, patrols, training and shelter for travelers in the Forêt des Moyen-Ducs |
| Léonards’ farm | Reach 10,000 in one Competitive run on Léonards’ farm | Open-land context and the journey |
| Éloïse's opening journal | Available immediately | Her life and leadership before the black sky |

Defeats accumulate in the account's shared per-enemy record across confirmed
Practice, Competitive and Weekly runs, on either character. Library discovery
and Profile totals use that same record. Bosses are Bringer of
Death, Voidborn Goddess, Shoggoth and Voidcaller. Shoggoth Minion and Void
Tentacle appear inside Shoggoth and Voidcaller,
respectively. They share their parent boss’s five-kill discovery gate and have
no separate list entries. Summon kills never substitute for boss kills.

Level scores are separate lifetime bests. Practice and Weekly scores do not
unlock Locations. Scores from multiple runs are not added. Discoveries persist
across seasons. Runs must finish and pass replay validation before progress
appears; pending, rejected and local Developer Practice runs do not count.
Progress starts with runs processed by the Codex-enabled backend; historical
runs are not reconstructed.

The Library shares the main menu's icon column, with identical button sizes
and spacing: Bestiary, Locations and Journal. Icons use tooltips without
visible labels or selection boxes. The app bar names the active section beside
Library. Bestiary lists all eight independent entries together, without category
filters. Locked Bestiary cards conceal the enemy name, show "Entry locked",
and put "Defeat current / target to unlock" inside the bar. The idle portrait
appears after the first defeat of that type; at zero defeats a lock icon remains.
On first viewing Bestiary in an app session, each bar shows
confirmed progress immediately. After that, newly confirmed increases fill
from the last presented value over 1.2 seconds, including progress earned while
the Library is closed or another section is shown. On an unlock, the count
changes to "Open" when the fill reaches the requirement. The same increase
does not replay; already presented unlocked bars show "Open" immediately on
later visits. Unlocked cards show an idle enemy portrait and name.
Locations show an unlabelled map of the Théodonis region. Only Théodonis and
the two discoverable locations have Flutter labels. Léonards’ farm and Val
Outpost have clickable map labels and markers. Their icons show locked or open
status; tapping either opens a modal with the current Competitive best score
and discovery requirement, or the full location lore after unlock. The map can
be panned and zoomed, with a reset control. Locked/discovered status remains
available to screen readers. Opening
a locked Bestiary entry also conceals the enemy name. Locked entries omit
validation boilerplate; locked Locations describe their history gate without
promising other context. There are no partial purchases or additional
currencies.

Combat information reflects the current game catalogs, including mixed damage
shares and secondary boss attacks. Innate resistances and weaknesses are
explicitly separated; an empty category states that none exist.
Grojib's follow-up attack is shown as Second Strike; its behaviour warns that
the hit can stun.

## Narrative continuity

The PDF timeline supersedes the earlier 200-year proposal. The historical
overview places this episode approximately six centuries before the tabletop
campaign. The playable Éloïse is the PDF character, aged seventeen at the
black-sky episode. Her opening journal recounts her birth in Elingen, her
parents' disappearance, Aldebarant's training, her election and victories
against the orcs, and her founding of La Main. It ends as the sky darkens,
without revealing what happens in the forest or her later fate. The in-game
journal contains no reference to the later campaign.

Val Outpost already exists in the runner's earlier period and serves the same
road-patrol and survival-training purpose it has in the later campaign. It is
in the Forêt des Moyen-Ducs near Théodonis. That forest has no black sky: the
darkened ancient forest is at least 50 km farther north. The Val Outpost
location entry describes the outpost in Éloïse's time, not the later campaign's
captain, medic, injured soldier or caravan survivors.

The user's premise is authoritative for the runner: the northern ancient
forest's cultists and associated creatures help the power responsible for the
black sky. The PDF also describes a demonic cult corrupting that forest while
the orc war diverts attention. Enemy field notes connect present encounters to
that crisis. Exact remote origins of bosses remain unknown where the references
do not establish them. These descriptions do not invent a separate pantheon or
transplant later-era named townspeople into this period.

References: *Lothringen - Les Soleils d'or - Guide du maitre.pdf*, historical
overview (physical page 3, printed pages 4–5), Éloïse (physical page 31,
printed pages 60–61), and regional map (physical page 2); companion world
brand and naming references in `C:/dev/Lothringen/Brand/`.

The supplied city map replaces the earlier PDF regional-map extraction. The
map does not change the PDF-based narrative chronology.
See [implementation and persistence](../tdd/codex.md).
