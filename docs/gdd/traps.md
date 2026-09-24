# Environmental traps

These initial safe defaults are implemented in Core and await editor/gameplay
playtest tuning. Authors place a trap and an independent rectangular activation
trigger. A living player or enemy can activate it. Trigger geometry never causes
damage; the visible weapon or separate dart does.

| Trap | Time before damage | Base damage | Attack animation |
| --- | --- | --- | --- |
| Spike | 0.7 seconds | 5 HP physical | 2.52 seconds |
| Swinging Axe | 0.8 seconds | 8 HP physical | 9.38 seconds |
| Poison Darts | 0.5 seconds | 1 HP Poison impact | 1 second |

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
yellow/red warning zones or exclamation markers. Idle machinery sits behind
terrain; active art sits above terrain and behind actors. Exact trigger and
damage geometry is available only in authoring and optional hitbox debugging.

Traps are indestructible. Enemy trap deaths use normal enemy kill scoring but
have no attacker gear procs. The Poison dart is environmental and cannot be
learned, bought or equipped. All existing spells, including Thunder Bolt, remain
available.
