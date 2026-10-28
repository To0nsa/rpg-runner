# Messages and level gifts

Messages is the game's system inbox, using its existing landscape menu shell,
background, typography, colors and controls. Select a message in the left list
to read it on the right. Text scrolls while gift controls remain visible.
Information messages have no claim action.

Each newly reached account level delivers **25 gold** to claim manually. A run
crossing several levels creates one gift per new level. Previously reached
levels receive nothing when the feature is introduced. There is no catch-up
gift or award for opening the inbox. Level 30 remains the cap. Pending/rejected
runs and Developer Practice grant no gifts. Ordinary run gold remains automatic.

Reading and claiming are separate. Selecting mail marks it read; its gift
remains pending until Claim succeeds. The button then shows Claimed and the
wallet and ownership update. A connection retry cannot pay the gift twice. Opening the list
alone does not mark everything read.

The main menu Messages icon shows a small worn-gold dot for unread mail OR
unclaimed gifts. It clears only when both are empty. Rows label unread mail
and available/claimed gifts. The dot is reusable UI; Library/Store discovery
policies are future work.

Unclaimed gifts never expire. Claimed gift messages are automatically removed
after 30 days from claiming. Information messages stay until read, then are
automatically removed after 30 days from the first read. Cleanup runs periodically;
reading again does not restart the timer.

Players can use **Delete message** to remove information or claimed gift messages
immediately. Unclaimed gifts have deletion disabled with a claim-first explanation.
Deletion updates inbox attention and leaves claimed gold and ownership intact. Failed requests can be retried safely.

The flat level reward is temporary balance policy until individual level rewards
are designed. Already issued gifts retain their promised amount.

Authorized operators can attach existing equipment, abilities and projectile
spells to a message alongside optional gold. Gear unlocks are account-wide;
skills show the character they belong to. Claim grants every attachment together
and does not equip them. Already-owned unlocks give no duplicate or compensation.
Gift rows use the same icons and names as the loadout/store. These attachments
follow the same unlimited-until-claimed and 30-day-after-claim retention policy.

The inbox provides refresh and retry actions. Attention refreshes periodically
while foregrounded; system mail is not live chat. Future player messaging is
intended to be live conversations with its own tab when implemented.

See [technical contract and operator delivery](../tdd/system_inbox.md).
