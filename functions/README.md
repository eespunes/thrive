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

## Develop / deploy

```sh
cd functions && npm install && npm test   # node:test, no emulator needed
firebase emulators:start --only functions,auth,firestore
firebase deploy --only functions
```

Cloud Functions require the Firebase project (`thrive-b1545`) to be on the
**Blaze** (pay-as-you-go) plan.
