# World interactions and regeneration shrine

The vasque in Forest's `forest_default_early_008` and the garden pot in Field's
`field_default_easy_008` are regeneration shrines. The player lights one by
landing on or walking onto its flat top.
There is no button, delay, damage, or immediate resource refill. Side contact,
jumping underneath, passing overhead, and enemy contact do not light it.

The fire remains lit after leaving the shrine. Its four supplied frames loop at
10 frames per second. The Forest vasque has orange fire and the Field pot has
smaller blue fire. On the first blessing grant, Holy VFX 01 Impact plays once
around the player. The HUD shows “Regeneration increased” for two seconds of
gameplay, followed by a persistent
“Bénédiction des Dames de la forêt” indicator.

## Blessing

Initial playtest tuning adds these flat rates to existing regeneration:

| Resource | Additional regeneration |
| --- | --- |
| Health | 0.10 HP/second |
| Mana | 0.10 mana/second |
| Stamina | 0.10 stamina/second |

These flat additions combine with base and equipment-derived regeneration and
can restore a resource whose base regeneration is zero. Resources remain capped
at their current maximum.

The bonus lasts from activation through the remainder of the level attempt.
It stays active when the shrine is offscreen or its chunk unloads. Repeated
contact gives no additional bonus. Another shrine can light independently, but
another grant of this same blessing does not add a second bonus or restart its
animation or feedback message. Restarting or starting another run clears it.

## Current authoring scope

The explicitly registered Forest and Field placements retain this behavior.
Campaign's **Markers → Blessing fire** also attaches it to an existing shrine or
platform top in one mission occurrence. Choose ember or blue fire, then point at
the flat top; the preview shows the fire and its contact width. This places only
the effect. The shared platform stays unchanged, and other uses of it remain
ordinary geometry unless separately attached. Moving the fire reattaches it to
a valid top. Multiple fires light independently and share one regeneration bonus.
Existing Chunk/Level Play displays the effect using the same gameplay rules.
See the [technical contract](../tdd/world_interactions.md) for configuration,
placement disambiguation, and asset ownership.
