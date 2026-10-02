# World interactions and regeneration shrine

The vasque in Forest's `forest_early_hill_001` is a regeneration shrine.
The player lights it by landing on or walking onto the bowl's flat top.
There is no button, delay, damage, or immediate resource refill. Side contact,
jumping underneath, passing overhead, and enemy contact do not light it.

The fire remains lit after leaving the shrine. Its four supplied frames loop at
10 frames per second. On the first blessing grant, the HUD shows
“Regeneration increased” for two seconds of gameplay, followed by a persistent
“Regen blessing” indicator.

## Blessing

Initial playtest tuning adds these flat rates to existing regeneration:

| Resource | Additional regeneration |
| --- | --- |
| Health | 0.05 HP/second |
| Mana | 0.20 mana/second |
| Stamina | 0.10 stamina/second |

These are additions, not percentages, and can restore a resource whose base
regeneration is zero. Resources remain capped at their current maximum.

The bonus lasts from activation through the remainder of the level attempt.
It stays active when the shrine is offscreen or its chunk unloads. Repeated
contact gives no additional bonus. Another instance of the same shrine can
light independently, but the regeneration blessing does not stack or restart
its feedback message. Restarting or starting another run clears it.

## Current authoring scope

Only the explicitly registered Forest placement has this behavior. Other
vasques remain ordinary prefabs. Attachments and reusable presets are currently
configured manually in Core catalogs; there are no interaction editor controls.
Existing Chunk/Level Play displays the effect using the same gameplay rules.
See the [technical contract](../tdd/world_interactions.md) for configuration,
placement disambiguation, and asset ownership.
