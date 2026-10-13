# Ops: family-only security and cost guardrails

Runbook for epic #463. Thrive is used only by our family. Firestore rules
decide who can read or write, App Check decides which *apps* may call the
backend, and the Blaze plan is capped so a mistake can't cost real money.

Everything here is either in the repo (rules, tests, tools) or a console step
for the owner. Console steps are checklists: tick them in the issue when done.

## Rollout order

1. **Seed the allowlist** (`ops/allowlist`, below) with every current member.
2. **Deploy the rules**: `firebase deploy --only firestore:rules`.
3. Ship the app release that checks the allowlist at sign-in.
4. Watch App Check metrics, then **enforce** (below).

Deploying the rules before seeding would stop every member from saving their
own user doc. Shipping the app before the rules is harmless: the app treats an
unreadable allowlist as "unknown" and lets the rules decide.

---

## Family allowlist (#465)

`allowlist/{email}` (lower-cased email as the doc id) lists the accounts that
may use the backend. Clients can only `get` their own entry; nobody can list
or write it from the app.

The rules require an allowlisted account to:

- create or change its own `users/{uid}` doc (the first write of a new
  account) and its `unsavedChanges`,
- create a family,
- join a family (on top of the family password),
- resolve a family handle (`family_handles/{username}`).

Existing members keep reading and editing their family through `memberUids`,
even if they're removed from the allowlist. Removing someone from a family is
still done in the app.

An entry counts when the sign-in email is **verified** (Google accounts always
are). Email/password accounts get a verification link at sign-in. Existing
unverified accounts keep working because the tool pins their uid on the entry
(`uids`), and only that uid may use the unverified email.

At sign-in the app checks the entry. An uninvited account is signed out with
"This account isn't invited to Thrive…", and a brand-new uninvited account is
deleted again.

### Manage it

```bash
gcloud auth application-default login   # your own Google login, no key file
cd ops/allowlist && npm install
node allowlist.mjs seed            # dry run: every member of every family
node allowlist.mjs seed --apply
node allowlist.mjs add grandma@example.com --note "Grandma"
node allowlist.mjs remove old@example.com
node allowlist.mjs list
```

You can also add an entry by hand in the Firebase console: Firestore →
`allowlist` → add a document whose ID is the lower-cased email.

### Console (owner)

- [ ] Authentication → Sign-in method: keep only **Google** and
      **Email/Password**. Disable every other provider.
- [ ] Authentication → Settings → **Email enumeration protection**: on.
- [ ] Optional, once Cloud Functions exist (#450): a `beforeUserCreated`
      blocking function that rejects non-allowlisted emails. It needs the free
      Identity Platform upgrade. The rules already enforce the same thing.

## Firestore rules and tests (#466)

`firestore.rules` is least-privilege and default-deny:

| Path | Access |
| --- | --- |
| `allowlist/{email}` | `get` own entry only; no list/write (Admin SDK only) |
| `users/{uid}` (+ `unsavedChanges`) | owner only; create/update needs the allowlist |
| `families/{id}` | members read; owner/member/joiner updates as documented inline |
| `families/{id}/{section}/**` | members; writes only to `settings`, `finance`, `calendar`, `meals`, `notes`, `cards`, stamped with `familyId` |
| collection-group record reads | members of the `familyId` on the doc |
| `family_handles/{username}` | `get` for allowlisted accounts; owner-only writes |
| `user_workspaces/{uid}` | legacy: owner read/delete only |
| anything else (FCM tokens, Alexa links, pairing codes, …) | denied. Server-only via the Admin SDK |

When a feature adds a family section, add it to the section list **and** to
the collection-group list in the rules, with tests.

Tests: `test/rules` (`@firebase/rules-unit-testing`, emulator on port 8091).
They cover allow and deny for every collection. CI
(`.github/workflows/rules-tests.yml`) runs them on PRs and on `main`, so a
rules regression fails the build.

```bash
cd test/rules && npm install && npm test
```

## App Check (#464)

The app activates App Check in `lib/src/app/app.dart`: Play Integrity on
Android release builds, DeviceCheck on iOS, and the debug provider in debug
builds.

### Debug tokens (emulators and dev builds)

1. Firebase console → App Check → Apps → Android app → ⋮ → **Manage debug
   tokens** → Add a token (or copy the one the SDK logs on first run:
   `Enter this debug secret into the allow list…` in `adb logcat`).
2. Run with `flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=<token>`.
3. Never commit tokens. Revoke a token when a laptop or phone is retired.

### Enforce (owner)

- [ ] App Check → APIs → **Cloud Firestore**: wait until the metrics show
      ~100% verified requests over a few days of normal use, then **Enforce**.
- [ ] **Authentication**: enforce the same way (needs the free Identity
      Platform upgrade).
- [ ] Cloud Storage: not used today; enforce it if it ever is.
- [ ] Callable/HTTPS functions (#450): declare them with
      `enforceAppCheck: true`. The Alexa endpoint is exempt because Amazon
      calls it, and it verifies Amazon's request signature instead (#453).
- [ ] Verify that an unattested client is rejected:

  ```bash
  # API key from android/app/google-services.json (public by design).
  curl -s "https://firestore.googleapis.com/v1/projects/thrive-b1545/databases/(default)/documents/family_handles/x?key=$API_KEY"
  # Expect 401/403 mentioning App Check, not a rules/permission error.
  ```

## Console hardening (#467, owner)

- [ ] Google Cloud → APIs & Services → Credentials → **Android key**:
  - Application restriction: Android apps → `cat.eespunes.thrive` with the
    SHA-1 of the debug, upload and **Play App Signing** certificates.
  - API restriction: only the APIs the app calls: Identity Toolkit, Token
    Service, Cloud Firestore, Firebase Installations, Firebase App Check
    (and FCM Registration once push lands, #469).
- [ ] Delete the unused web app and its browser key (also listed in #462).
- [ ] IAM: only the owner account has **Owner**. Remove stale principals.
- [ ] Functions runtime service account (#450): give it only the roles it
      needs (Firestore user, Secret Manager accessor for its own secrets,
      logging). Don't use the default Editor role.
- [ ] Organization policy / IAM: **no user-managed service-account keys**.
      Tools use `gcloud auth application-default login` (see `ops/allowlist`).
- [ ] Secrets (Alexa skill ID, etc.) only in Secret Manager via
      `firebase functions:secrets:set`. Never in the repo, which is public.
      `google-services.json` is fine to commit; its API key is an identifier,
      locked down by the restrictions above.
- [ ] GitHub → Settings → Code security: **secret scanning** and **push
      protection** on.
- [ ] 2-step verification on the Google account and the Amazon developer
      account.

Repo check done for #467: a history-wide scan found no private keys, service
account JSON or tokens. The only matches were placeholder samples in
`node_modules` committed by b2bda9f and since removed. `.gitignore` now also
blocks service-account key files.

## Cost guardrails (#468)

### Budget alerts (owner)

```bash
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="Thrive monthly" \
  --budget-amount=5EUR \
  --filter-projects=projects/thrive-b1545 \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

Alerts are emailed to billing admins (the owner). Test one with a temporary
€0.01 budget, then delete it.

### Artifact Registry cleanup (owner, after the first functions deploy)

Keeps the last 2 images, which stays under the free 0.5 GB:

```bash
gcloud artifacts repositories set-cleanup-policies gcf-artifacts \
  --project=thrive-b1545 --location="$FUNCTIONS_REGION" \
  --policy=ops/cost/artifact-cleanup-policy.json --no-dry-run
```

### Cloud Functions rules (apply in #450 and every later function)

- Global options: `setGlobalOptions({ region, maxInstances: 3 })`.
  `maxInstances` is set on every function, and lowered further for
  triggers that don't need parallelism.
- Timeouts: 60 s default; only the scheduled morning summary (#484) may go
  higher.
- No unbounded triggers. A Firestore trigger that writes back must skip its
  own writes (for example a `_by: 'server'` marker, or comparing before and
  after) so it can't loop.
- Fan-out (#472) is bounded by family size; never query across families.
- Optional kill switch: a budget → Pub/Sub topic → function that disables
  billing at 100%. This is only worth it once functions run on a schedule.
