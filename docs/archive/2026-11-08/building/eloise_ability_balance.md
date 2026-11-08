# Éloïse ability balance

Authorized 2026-11-08: implement the reviewed balance issues and repair current docs.
Preserve all preexisting equipment, icon, menu and projectile work.

Acceptance: utility choices retain resource pressure; only full-charge Cleave grants
innate bleed; Quick Shot has a faster execution; Riposte persists through its own
guard and has a visible one-second release window; names/tooltips/starter docs
match runtime; client/issuer/worker compatibility remains aligned. Existing
mobility, Willow tuning and shared status defaults remain unchanged.

- [x] Implement local tuning, charge payloads and guard reward lifecycle.
- [x] Update feedback, descriptions and compatibility consumers.
- [x] Verify targeted combat/UI/replay behavior and deterministic outcomes.
- [x] Update GDD/TDD, record evidence and archive this checklist.

Tuning: Haste +40%/3s/8s cooldown/12 mana; Focus existing bonuses/4s/8s/12 mana;
Ward 40% plus DoT suppression/3s/9s/14 mana; Cleanse 12 mana/8s;
Vital Surge 25% HP over 5s/12s/20 mana; Second Wind 25% stamina over 5s/10s/18 mana.
Mana Infusion remains 35% mana over 5s/7s/15 stamina.
Quick Shot 6/2/6 ticks; Overcharge tiers 0/10/24 ticks; Cleave tiers 0/8/20,
with its existing bleed moved to the final tier. Sword Slash replaces only the
player-facing Bloodletter Slash name; stable ownership ID remains unchanged.

These are a reasoned first balance pass, not evidence of live player balance.
No deployment is authorized by this checklist.

Completed locally on 2026-11-08. [Validation and remaining playtest acceptance](../../../verification/eloise-ability-balance-2026-11-08.md).
