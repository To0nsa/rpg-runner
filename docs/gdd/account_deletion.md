# Account Deletion

The profile page offers account deletion through two confirmations. Backend
deletion requires a linked Play Games identity and recent authentication;
Flutter reauthenticates before sending the request.

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

Completion evidence has a thirty-day expiry deadline, followed by automatic
bounded cleanup. Operational delays can extend physical removal. Public privacy
and deletion notices must describe this accurately before launch; historical
production evidence does not verify the current revision.

Technical contracts and retention details are in
[Account Deletion Workflow](../tdd/account_deletion_workflow.md).
