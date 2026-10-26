# Account Deletion

The profile page offers account deletion through two confirmations. Backend
deletion requires a linked Play Games identity and recent authentication;
Flutter reauthenticates before sending the request.

The first confirmation explains that deletion can take several hours and that
the same Play Games profile cannot create a fresh game account until it finishes.
Reopening during deletion shows **Game account unavailable**, with the waiting
period and **Try again**, instead of asking the player to sign in to Play Games
again. This message also covers other disabled accounts; because the app cannot
read the disable reason, the deletion guidance starts with **If you recently
deleted it**. After deletion finishes, sign-in can create a fresh account with
reset progress.

An accepted request transfers deletion to the server. Firestore/Storage cleanup
continues asynchronously and does not require the player to remain signed in.
The app immediately clears its in-memory profile, progression, ownership, and
run state, then attempts device cleanup and sign-out.

The app closes when device cleanup succeeds. If cleanup or sign-out fails, it
shows that deletion was accepted and offers **Retry cleanup**. This action only
retries device operations; it does not sign in again or request deletion again.
The retry receipt lasts for the current app instance. A failed device operation
does not imply that local data has been erased.

Missing server acceptance or an invalid response leaves local account state
intact and shows a retryable failure. Server-side retryable erasure stages are
accepted outcomes, distinct from a rejected deletion request.

Deletion removes live game records and replay/ghost objects. The production
replay bucket also retains deleted objects for seven days of recovery.
Completion evidence has a thirty-day expiry deadline, followed by automatic
bounded cleanup. Operational delays can extend physical removal. Public privacy
and deletion notices must describe these windows accurately before launch.
The workflow document records the September server/web production verification
and its native-device limits.

Technical contracts and retention details are in
[Account Deletion Workflow](../tdd/account_deletion_workflow.md).
