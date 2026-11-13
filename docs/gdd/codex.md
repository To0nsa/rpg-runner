# Théodonis and the Codex

Town opens the supplied `assets/Théodonis.jpg` city map, with Equipment store, Training Hall,
Library and [Hall of Honour](12_achievements.md) callouts inside the walled city.
The image fills the entire screen, including behind the transparent title and
back bar, cropping its edges initially; dragging reveals the remaining map.
Pinch to zoom and a small reset control remain. Service labels use Mist text and icons
with dark shadows, without borders or backgrounds. There is no instruction
footer or plus/minus zoom control. Labels sit around the city walls: Equipment
store west, Library north, Hall of Honour east and Training Hall southeast
(portrait pairs the northern labels and places Training Hall south).
Connectors meet the edge of each label without crossing its icon or name.
Straight connectors are a layout preference; routed or bent connectors may be
used when they improve readability, avoid overlaps or fit the available space.
Both service names and their white dot markers open their destinations. Equipment
store points to the southwestern building and the Library to the large
northeastern courtyard complex. Training Hall points to the southern courtyard.
Hall of Honour points to the small building beside the eastern wall and hosts
achievement claims. These are game navigation placements.
Back from each service returns to Town.

[Equipment and Training](town_services.md) offer permanent earned-gold catalogues. Their gold balance
appears at the far right of the app bar as a number and coin icon, without a label.
The Library is free to browse; discoveries cannot be purchased.

## Discoveries

| Entry | Requirement | What becomes readable |
| --- | --- | --- |
| Regular enemy | Defeat that enemy type 10 times | Attacks and damage types, resistances, weaknesses, behaviour and field notes |
| Boss | Defeat that boss 5 times | The same complete combat and lore entry |
| Boss summons | Unlock their parent boss | Combat and field notes within that boss’s page |
| Val Outpost | Reach 10,000 in one Competitive run on Val Outpost | Its tent camp, Théo’s forest guards, Hanna, the bugbear pressure and its role as a road post, message relay and refuge |
| Léonards’ farm | Reach 10,000 in one Competitive run on Léonards’ farm | The largest agricultural estate around Théodonis, overseen by a powerful family |
| Opening journal | Available immediately | Val Outpost’s spoiler-free location description |
| Chapter introduction | Its first mission is published, or a published mission has already been cleared | After Le feu de joie: the survivors are in Théodonis and Éloïse is summoned to investigate Val |
| Mission journal update | First confirmed successful Campaign clear of that published mission | Its outcome, appended in authored story order |

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
Locations show an unlabelled map of the Théodonis region across the entire
screen, including behind the transparent AppBar and left navigation icons.
The map crops to fill the screen; dragging reveals its edges. Location buttons
start clear of the toolbar and rail.
Only Théodonis and the two discoverable locations have Flutter labels, with
lines to their map positions. Théodonis sits close below its marker; Léonards’
farm sits farther to the right, near its marker's height. Léonards’ farm and Val
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

Discovered enemy entries use a static field-guide layout. The creature name,
combat role and compact idle portrait lead the page; only bosses and summons
receive classification labels. The toolbar returns to Library without repeating
the creature name or adding a Bestiary heading. A concise combat recommendation
precedes structured attack rows, behaviour and grouped innate defences. Each
attack separates its name from its category and damage composition; empty
resistance/weakness categories show “None”. Field notes follow a quiet divider
in italic Crimson Text. All entry text uses the same Crimson Text family as
the game, with compact 24px titles, 14px reading text and 12px supporting details.
Boss summons retain their own complete sections within the parent entry.
Landscape phones and wider screens place attacks beside behaviour and
defences when space permits; narrow screens and enlarged text stack them
without truncating content. Portraits remain still; entries have no animation
playback controls.

## Narrative continuity

The Long Run begins after *Le feu de joie*. The surviving members of Neyla’s
company have reached Théodonis. Éloïse is called to Val Outpost to investigate
cultists appearing nearby. They do not seem to follow the undead goddess, but
their arrival so soon after the attack is suspicious. Their relationship to the
caravan’s attackers remains unproven.

Journal accumulates the campaign opening, available chapter introductions and
confirmed mission outcomes. Earlier entries remain readable. Failed attempts,
pending validation, local Developer Practice and replaying an already cleared
mission cannot add entries. Switching accounts rebuilds visibility from that
account’s progress; restored clears reveal the corresponding passages immediately.
Excluded draft missions reveal neither their Journal titles nor their text.
English and French prose is authored in Campaign, including a preview after any
mission; the Library reads the built content in the selected language.

Val’s later mission drafts currently record only their stated assignment outcomes
and leave the cultists’ identity and connection unresolved. Authors should revise
them alongside the final encounters and evidence before including those missions.

Val Outpost is a guarded camp of half a dozen large tents in the Forêt des
Moyen-Ducs, called the Long-Eared Owls’ Forest in the English entry. Three
spoiler-free paragraphs cover its road presence and survival training, Captain
Théo’s twenty-four elite forest guards and field medic Hanna, their mission to
contain a bugbear tribe’s expansion across the Vosga, and the camp’s message
relay and refuge. The entry does not reveal the events at Neyla’s caravan.

The location and personnel follow the [Game Master’s guide](https://docs.google.com/document/d/1GAveRYZwzPEUEoo08fCQPKRKzG3BUwY2wPCWSa82yt4/edit),
sections *L’avant-poste du Val* and *L’escouade de Théo*. The relay and refuge
follow [Les Soleils d’or](https://docs.google.com/document/d/1e4dBP417l0UscOELsXn7DEhkzFlz-PTwR7yiucTIi6w/edit),
chapter 3, *Le feu de joie*.

References: *Les Soleils d’or* Game Master's guide, historical overview and
Val Outpost; *A Layover in Gogne*, background and incipit; companion world brand
and naming references in `C:/dev/Lothringen/Brand/`.
See [implementation and persistence](../tdd/codex.md).
