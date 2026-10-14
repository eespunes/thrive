# Thrive Cloud Functions

Callable functions (firebase-functions v2 `onCall`, Node 22, region
`europe-west1`, `enforceAppCheck: false`) that let family admins give a
login-less kid profile its own login and manage it. Admin SDK writes bypass
Firestore rules.

- `kid_logic.js` – pure validation / member-row transitions (unit tested).
- `handlers.js` – Firestore + Auth orchestration (`createHandlers({db, auth, FieldValue, now})`).
- `index.js` – wires the handlers to `onCall`.

"Admin" = caller is the family `ownerUid` or in `adminUids`, and not a key of
`kidUids`. Emails are trimmed + lowercased; passwords need ≥ 10 characters.

| Callable | Input | Output |
|---|---|---|
| `kidCreateEmailLogin` | `{familyId, memberId, email, password}` – creates an admin-managed email login (custom claim `managedKid: true`) for a kid row without a login. Auth user is deleted if the Firestore transaction fails. | `{uid}` |
| `kidLinkGoogle` | `{familyId, memberId, email}` – stores a pending Google link in `kid_links/{email}` (replaces an earlier pending link). | `{}` |
| `kidClaimLogin` | `{}` – caller signed in with a verified Google account claims the pending link for their email. | `{familyId, memberId}` |
| `kidResetPassword` | `{familyId, memberId, password}` – managed email login: new password, revoke tokens, `signedOutAt`. | `{}` |
| `kidChangeEmail` | `{familyId, memberId, email}` – managed email login: change sign-in email. | `{}` |
| `kidSignOutEverywhere` | `{familyId, memberId}` – revoke tokens, `signedOutAt`. | `{}` |
| `kidRemoveLogin` | `{familyId, memberId}` – removes pending link / Google login / managed login (managed Auth user + `users/{uid}` are deleted). | `{}` |
| `kidLoginDetails` | `{familyId, memberId}` | `{lastSignInMillis: int\|null}` |
| `loginKind` | `{email}` (no auth needed) | `{managed: bool}` |

Errors (`HttpsError`, `details.reason`):

- `unauthenticated` – not signed in.
- `permission-denied` – caller is not a family admin.
- `not-found` – unknown family / member, or no pending link (`kidClaimLogin`).
- `invalid-argument` – reason `email` (invalid email), `password` (< 10 chars), `input` (missing `familyId`/`memberId`).
- `already-exists` – reason `member` (+ `memberName`): another member uses that email/loginEmail; reason `thrive`: an Auth user (or another member's pending Google link) already has that email.
- `failed-precondition` – reason `state`: member is in the wrong state for the action; reason `provider`: `kidClaimLogin` caller isn't a verified Google sign-in.

## Push notifications (epic #469)

- `push_logic.js` – pure rules (unit tested): `notifPrefs` defaults + kid
  restrictions, scope filtering, §5 copy/channel/tag/group per row, FCM
  message shape, quiet hours (device timezone), digest, debounce buckets,
  money-day projection.
- `push_handlers.js` – Firestore/FCM orchestration
  (`createPushHandlers({db, messaging, enqueue, now})`).

Recipients = family members with a `uid` (not `invited`), minus the writer
(trigger auth context, falling back to the record's `_by`), filtered by
`users/{uid}.notifPrefs` (missing ⇒ defaults; type on + event ticked + scope).
Kids only get chores (scope me), calendar (scope me), money (own member id),
family and wall. Sent to `families/{fid}/members/{uid}/devices/{token}` docs
that are `enabled` and whose `channelState[channel]` isn't `false`; a
`messaging/registration-token-not-registered` error deletes the device doc.
Every message carries `data.{title, body, link, channel, tag, group?}`;
Reward claimed is **data-only** (client renders "Approve"/"Open";
`data.actions`, `data.approve` = JSON args for `approveReward`).

| Export | Kind | Does |
|---|---|---|
| `pushOnCalendarEvent` / `pushOnCalendarSeries` | `onDocumentWrittenWithAuthContext` `calendar/main/months/{m}/events/{id}`, `calendar/main/recurring/{id}` | Event added / moved / cancelled pushes; queues cloud reminders and event starts. Kitchen-origin chores ticked done → `chores` bucket. |
| `pushOnCalendarImport` | `onDocumentWrittenWithAuthContext` `calendar/main/imports/{id}` | Queues reminders for visible imported events. |
| `pushOnDevice` | `onDocumentWrittenWithAuthContext` `members/{uid}/devices/{token}` | Backfills reminders when a phone first registers or changes timezone. |
| `pushEventReminders` | `onSchedule` every minute | Rechecks queued events, recipients, quiet hours, and device settings; sends due FCM reminders and event starts. |
| `pushReminderRefresh` | `onSchedule` daily | Backfills existing events and extends recurring schedules over the next 30 days. Run the Cloud Scheduler job once after first deploy. |
| `sendTestPush` | `onCall`, App Check enforced | Sends a test FCM push to the signed-in family member's devices. |
| `pushOnListLine` | `notes/{listId}/lines/{lineId}` | Line added / ticked → `list_{listId}` bucket. |
| `pushOnMoneyEntry` / `pushOnMoneyOccurrence` / `pushOnMoneySeries` | `finance/main/months/{m}/entries/{id}`, `…/months/{m}/recurring/{id}`, `finance/main/recurring/{id}` | Added (3+ expenses by one person in 10 min → bundle), edited, removed; marked paid → "Paid out"/"Received" now (skips the 09:00 one). |
| `pushOnKitchen` | `settings/kitchen` | `starsMap[kid]` 5+ → 0 = Reward claimed; writes `rewardClaims/{memberId}`. |
| `pushOnFamily` | `families/{fid}` | Joined / left or removed / role changed (also sent to the person). |
| `pushFlush` | `onTaskDispatched` (Cloud Tasks) | Flushes a debounce bucket: chores 15 min after the first tick (grouped "Liv and Leo finished 3 chores"), lists 10 min after the last change ("List finished" replaces "Items added"). |
| `pushMoneyDay` | `onSchedule` `0 * * * *` | For users whose local time is 09:xx: planned entries due today (series projected like the app), group `money-day`. |
| `pushQuietDigest` | `onSchedule` `*/15 * * * *` | One `family_digest` per user whose quiet hours are over, then clears held items. |
| `approveReward` | `onCall`, **`enforceAppCheck: true`** | `{familyId, memberId, claimId?}` – any adult (non-kid) family member; sets `approvedBy`/`approvedAt` on `rewardClaims/{memberId}` (idempotent). Returns `{ok: true}`. |

Server-only collections (Admin SDK; clients never need them – deny in rules;
enable Firestore TTL on `expireAt` for each):

- `families/{fid}/pushLog/{eventId}` – trigger dedupe (no duplicates on retries).
- `families/{fid}/pushQueue/{chores|list_{id}|money_{uid}}` – debounce/bundle state.
- `families/{fid}/pushMoney/{yyyy-mm}_{itemId}` – `paidSentAt`, `scheduledUids` (paid vs 09:00 dedupe).
- `families/{fid}/rewardClaims/{memberId}` – `claimId`, `cost`, `claimedAt`, `approvedBy`, `approvedAt`.
- `users/{uid}/pushHeld/{fid}_{tag}` – messages held during quiet hours (same tag replaces).
- `pushReminders/{hash}` – server-only due queue for family and imported calendar reminders; `expireAt` TTL. On first deployment, run the `pushReminderRefresh` Cloud Scheduler job once to backfill existing events.

Quiet hours use the timezone of the user's most recently updated device
(default `Europe/Amsterdam`). Event reminders bypass quiet hours when
`letReminders` is on; otherwise the server skips them. The cloud queue covers
30 days and checks due reminders every minute. FCM delivery can add delay,
and a five-minute FCM time-to-live prevents very late alerts. Reminders do
not fire offline and no longer need Android exact-alarm access.

This needs **Blaze**, the **Cloud Tasks** and **Cloud Scheduler** APIs, and
FCM. The PR defines four Cloud Scheduler jobs, including two for reminders;
Cloud Scheduler currently includes three jobs per billing account at no
charge and bills additional jobs. The project's €1 budget is an alert, not a
spending limit. Tests live in `push_logic.test.js`, `reminder_logic.test.js`,
and `push_handlers.test.js`.

## Develop / deploy

```sh
cd functions && npm install && npm test   # node:test, no emulator needed
firebase emulators:start --only functions,auth,firestore
firebase deploy --only functions
```

Cloud Functions require the Firebase project (`thrive-b1545`) to be on the
**Blaze** (pay-as-you-go) plan.
