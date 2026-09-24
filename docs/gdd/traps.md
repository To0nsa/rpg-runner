# Environmental traps

These initial safe defaults are implemented in Core and await editor/gameplay
playtest tuning. Authors place a trap and an independent rectangular activation
trigger. A living player or enemy can activate it. Trigger geometry never causes
damage; the visible weapon or separate dart does.

| Trap | Time before damage | Base damage | Attack animation |
| --- | --- | --- | --- |
| Spike | 0.7 seconds | 5 HP physical | 2.52 seconds |
| Swinging Axe | 0.8 seconds | 8 HP physical | 9.38 seconds |
| Poison Darts | 0.5 seconds | 1 HP Poison impact | 1.6 seconds |

These are defaults. Each placed trap has its own **Damage on hit (HP)** and
**Seconds before damage** fields in Chunk Creator, both when creating it and
when editing its saved row. Damage accepts 0.01–1000 HP in 0.01 HP increments;
delay accepts 0–30 seconds in 0.001-second increments. Reset to defaults restores
that type's values for the current creation/edit buffer. Editing one placement
does not change other traps or the catalog defaults.

Each trap also has a **Z-index**, defaulting to **-21**, in both creation and
editing. It uses the same depth scale as prefabs: higher values draw in front.
The chosen depth stays fixed while idle, winding up, attacking and recovering;
previewing animation frames does not raise or lower the trap.

The delay changes animation wind-up, keeping the first harmful pose synchronized
with damage. Attack/recovery animation and the one-second cooldown retain their
duration. Zero starts at the first harmful pose. For Poison Darts, this is the
delay before firing; travel adds time before impact. The damage field changes
impact only, leaving Poison pulses and Slow unchanged.

The Poison Darts launcher rests lowered. Activation plays its rise out of the
ground during the configured delay, then fires one dart, recovers and lowers
again. Lowering takes 0.6 seconds before the one-second cooldown begins. A zero
delay skips the rise and fires immediately. Its placement anchor, facing and
authored depth stay fixed throughout; terrain can hide the lowered art at the
chosen depth. Cancellation on leaving view returns it to the lowered pose.

Timing rounds cumulative animation boundaries up to a simulation tick. Spike
and Axe can damage both player and enemies once each per cycle; a blocked
attempt still counts. Darts travel at 340 world units per second, last three
seconds, and strike the first living actor they reach. They pass through terrain.

A successful dart applies five 2 HP Poison pulses, one per second, plus 25%
movement Slow for five seconds. Acid resistance mitigates impact and Poison
damage, while Slow follows status immunity and vulnerability rules. Poison
does not apply Vulnerable. Fire and Poison can coexist. See
[statuses](combat/status/status_system_design.md).

Activation requires the trap's resting art and attack visibility region to
overlap the game camera. That region is an internal visibility check, not a
visible zone. Leaving view cancels an unfired cycle or stops new contact hits;
a fired dart continues independently. After its animation, a trap waits one second and
requires an empty trigger before another activation. A dart launcher also waits
for its previous dart to disappear. Continuous overlap never auto-repeats.

The trap animation provides its wind-up and attack feedback. Gameplay has no
yellow/red warning zones or exclamation markers. Authored Z-index controls trap
art in every phase. Exact trigger and
damage geometry is available only in authoring and optional hitbox debugging.

Traps are indestructible. Enemy trap deaths use normal enemy kill scoring but
have no attacker gear procs. The Poison dart is environmental and cannot be
learned, bought or equipped. All existing spells, including Thunder Bolt, remain
available.
