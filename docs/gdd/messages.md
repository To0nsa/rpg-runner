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
wallet updates. A connection retry cannot pay the gift twice. Opening the list
alone does not mark everything read.

The main menu Messages icon shows a small worn-gold dot for unread mail OR
unclaimed gifts. It clears only when both are empty. Rows label unread mail
and available/claimed gifts. The dot is reusable UI; Library/Store discovery
policies are future work.

Gifts do not expire; this version has no message deletion. The flat reward is
temporary balance policy until individual level rewards are designed. Already
issued gifts retain their promised amount. Item grants are not implemented.

The inbox provides refresh and retry actions. Attention refreshes periodically
while foregrounded; system mail is not live chat. Future player messaging is
intended to be live conversations with its own tab when implemented.

See [technical contract and operator delivery](../tdd/system_inbox.md).
