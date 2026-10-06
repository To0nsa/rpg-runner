# Derf

Derf begins as the normal fire cultist on his authored perch. He stands still
and retains his predicted-target explosion, mana cost, damage, cooldown and
delayed damaging effect poses.

When his body first enters the player's camera, he transforms once. The
12-frame sequence takes one second at 60 Hz. He cannot move, cast or strike
during it and keeps his remaining health and identity. Damage can kill him;
stun can keep him disabled after transformation finishes.

Transformation cancels an explosion still being prepared. An already-released
explosion finishes its effect. Twisted Derf never casts another explosion and
never returns to his original form.

Twisted Derf follows the selected combat target using shared ground pursuit.
This normally means the player; allied-NPC encounter priorities remain intact.
He walks, jumps, drops and swims within his actual movement limits, supporting
slopes up to 45 degrees while remaining upright. Gravity and terrain contact
stay active in every form; normal-form immobility is an AI restriction.

His tentacle strike has a 0.30-second telegraph, 0.20-second damaging extension
and 0.20-second retraction at 60 Hz. Cooldown starts on commit. Only the two
full-extension poses deal damage: 8 physical, once per target. The tentacle
reaches roughly 100 world units; empty surrounding sprite space is harmless.

Derf keeps his 22-health maximum and existing resistance modifiers. Death uses
the ground-enemy fall/impact lifecycle and the form's death art. Authoring
previews show the normal caster. Both source sheets live under
`assets/images/entities/enemies/derf/`.
