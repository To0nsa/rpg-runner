# Théodonis and the Codex

Town opens the supplied `assets/Théodonis.jpg` city map, with Equipment, Training Hall,
Library and [Hall of Honour](12_achievements.md) callouts inside the walled city.
The image fills the entire screen, including behind the transparent title and
back bar, cropping its edges initially; dragging reveals the remaining map.
Pinch to zoom and a small reset control remain. Service labels use Mist text and icons
with dark shadows, without borders or backgrounds. There is no instruction
footer or plus/minus zoom control. Indicator lines meet the beginning or end
of each label, with a small gap and no crossing through the icon or name.
Both service names and their white dot markers open their destinations. Equipment points to the market streets and the Library to the large
northeastern courtyard complex. Hall of Honour points to the southern courtyard
building and hosts achievement claims. These are game navigation placements.
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
| Val Outpost | Reach 10,000 in one Competitive run on Val Outpost | Its road watch, patrols, training and shelter for travelers in the Long-Eared Owls’ Forest |
| Léonards’ farm | Reach 10,000 in one Competitive run on Léonards’ farm | The largest agricultural estate around Théodonis, overseen by a powerful family |
| Opening journal | Available immediately | Théodonis, La Main and Neyla's traveling company in the tabletop era |

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
lines to their map positions. Léonards’ farm and Val
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

The Library introduces the era of *Les Soleils d’or*, after Éloïse's
disappearance and the attack on the Villa Twinsen. It identifies Neyla's
traveling company without assigning the playable characters to the troupe.
The existing playable Éloïse remains available; her place in this later setting
has not yet been resolved. Enemy field notes describe encounters without
asserting a connection to the earlier black-sky episode.

Val Outpost remains a road-patrol and survival-training post in the Forêt des
Moyen-Ducs, called the Long-Eared Owls’ Forest in the English entry. Its entry
does not introduce the scenario's named personnel.

References: *Les Soleils d’or* Game Master's guide, historical overview and
Val Outpost; *A Layover in Gogne*, background and incipit; companion world brand
and naming references in `C:/dev/Lothringen/Brand/`.
See [implementation and persistence](../tdd/codex.md).
