# Ops: security and cost guardrails

Runbook for the security and cost parts of epic #463. Firestore rules limit
access to each family's members; App Check attests supported client apps.
There is no family email allowlist: a signed-in person may create a family or
join one with its password proof.

## Rollout order

1. Deploy the tested rules: `firebase deploy --only firestore:rules`.
2. Ship the app release.
3. Watch App Check metrics, then enforce it as described below.

Deploy rules before an app release that needs new collection access. Do not
deploy the security-hardening branch's rules over newer rules on `main`; merge
and test the combined rules first.

---

## Firestore rules and tests (#466)

`firestore.rules` is least-privilege and default-deny:

| Path | Access |
| --- | --- |
| `users/{uid}` (+ `unsavedChanges`) | owner only |
| `families/{id}` | members read; owner/member/joiner updates as documented inline |
| `families/{id}/{section}/**` | members; writes only to `settings`, `finance`, `calendar`, `meals`, `notes`, `cards`, stamped with `familyId` |
| collection-group record reads | members of the `familyId` on the doc |
| `family_handles/{username}` | signed-in users can get a known handle; owner-only writes |
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
      Use `gcloud auth application-default login` for owner tools.
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

Set a €1 monthly project budget for notifications. This is an alert threshold,
not a spending ceiling: Cloud Billing can still charge more than €1. Blaze
does not offer a guaranteed project-wide hard cap. If €1 is an absolute
maximum, keep the project on Spark and do not deploy Cloud Functions.

```bash
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="Thrive monthly" \
  --budget-amount=1EUR \
  --filter-projects=projects/thrive-b1545 \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

Alerts are emailed to billing admins (the owner). Test one with a temporary
€0.01 budget, then delete it.

Firebase also offers a preview spend cap for Cloud Functions. It is limited
to that service and can overshoot because billing reports arrive late. It
does not cap Firestore or the whole project. Configure it below €1 in the
Firebase console only if a temporary pause in functions is acceptable.

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
- A budget → Pub/Sub automation can disable billing after a threshold, but
  notifications and shutdown are delayed and charges can exceed it. Disabling
  billing also stops services the app needs.
