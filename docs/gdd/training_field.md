# Training Field

Training Field is the third tab in character setup, beside Gear and Skills. All
three tabs remain visible while testing the selected character and equipped build.
The transparent app bar overlays the game in this tab; resources and controls
remain below the tabs while the game uses the full page viewport.

Two normal 600 × 270 chunks repeat in order: 1, 2, 1, 2. The character moves
continuously through the world. The existing camera follows forward progress,
with zero automatic runner scrolling. The HUD contains resources, controls, and
an opponent settings cog beside the resource bars.

The field starts empty. The cog offers None and regular enemies whose Library
entries are unlocked. Bosses and their summons are excluded. Choosing an enemy
queues one spawn at the next occurrence of the chunk containing the authored
enemy marker. The previous opponent and its attacks are removed when the new
one spawns. None clears the opponent and any queued spawn. Defeating an opponent
does not automatically respawn it; select again to practise another fight.

Death shows Reset. Reset restores the build's initial resources and cooldowns,
returns to the player start, and clears the enemy selection. Leaving the tab
discards everything; returning creates a fresh field with the current build.
Training grants no currency, experience, scores, Library discoveries, or rewards.

The editor's dedicated Training Field page authors only terrain, platforms,
decorations, the player start, and one enemy spawn. It does not configure camera
behavior, repetition, opponents, HUD, death, or reset. The initial supplied layout
is two flat grass/dirt chunks. See the [technical contract](../tdd/training_field.md).
