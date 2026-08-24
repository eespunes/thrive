# Thrive — Family Management App

Flutter app for managing a family's budget, calendar, lists, weekly meal plan
and kitchen wall dashboard, shared in real time between family members.

## Platforms

- Android
- iOS
- Web (scaffold only — used for headless smoke-testing in local/demo mode;
  there is no Firebase web config, so cloud sync is unavailable on web)

## Legal & Play Store compliance pages

The public Privacy Policy and Account Deletion pages required by Google Play live
in [`docs/`](docs/) and are served via **GitHub Pages** (Settings → Pages → deploy
from branch `main`, folder `/docs`). Canonical URLs:

| Page | URL | Play Console field |
| --- | --- | --- |
| Privacy Policy (#110) | https://eespunes.github.io/thrive/privacy/ | App content → Privacy policy |
| Account deletion (#109) | https://eespunes.github.io/thrive/delete-account/ | App content → Data deletion → external URL |
| Landing | https://eespunes.github.io/thrive/ | — |

**Account deletion process (owner: Erik Espuñes Jubero, erik.espunyes7@gmail.com):**

1. Users self-serve in-app (Account → Delete account), which runs
   `deleteUserAccount()` → `_deleteAccountCloud()`: removes the `users/{uid}` doc,
   deletes sole-owner families (meta doc + workspace sections + public handle),
   and deletes the Firebase Auth user.
2. Out-of-app requests arrive by email; verify the sender matches the registered
   account email, then delete the same records from the Firebase console.
3. Security/backup logs are retained up to 90 days, then purged.

Update the page content whenever the app's data flows change so the policy stays
accurate, and keep these URLs in sync with the Play Console listing.

## Run

```sh
flutter pub get
flutter run
```

## Build

```sh
flutter build apk --debug
flutter build ios --no-codesign
```

## Android production release checklist

1. Download Firebase Android config for package `cat.eespunes.thrive` and place it at:
   - `android/app/google-services.json`
2. Create `android/key.properties` from `android/key.properties.example` and point it to your upload keystore.
3. Ensure the keystore file exists at the configured path (typically `android/upload-keystore.jks`).
4. Run:

```sh
flutter build appbundle --release
```

Release builds are configured to fail fast if Firebase config or signing config
is missing. Version numbers are bumped **automatically** by the
`version-bump-on-main.yml` workflow after each merge to `main` (major/minor/patch
inferred from PR labels / conventional-commit markers) — don't bump
`pubspec.yaml` by hand.

## Data persistence & multi-device sync

The app stores data locally in `SharedPreferences` and, when Firebase is
configured, syncs a shared family workspace to Firestore so multiple signed-in
users can share one budget:

- `users/{uid}` — per-user profile + the families they belong to.
- `families/{familyId}` — family metadata (name, members, join hash);
  `memberUids` drives access.
- `families/{familyId}/workspace/{section}` — the shared workspace split into
  small per-section documents (settings, events, lists, weekly plan, one doc
  per budget year, one per imported calendar). Edits upload only the changed
  section; families created before the split migrate automatically on their
  first edit.
- `family_handles/{username}` — public handle resolver (family username →
  `familyId`, plus the non-secret random `joinSalt`). Readable by any
  signed-in user; writable only by the family owner, and only for a handle
  matching the family's own username.

### Family join security

There are **no Cloud Functions** — all persistence is client-direct, and the
join password is verified by the Firestore **security rules**:

- The family doc stores `joinHash`, readable only by members. New families use
  the v2 scheme: 30k-iteration SHA-256 over a random per-family salt (stored on
  the public handle doc); pre-v2 families keep working via a versioned legacy
  scheme.
- A joining client submits `joinProof`; the rules accept the update only when
  it matches `joinHash` and the write appends **only the joiner's own uid** to
  `memberUids`.
- Non-owner members cannot rotate the join credential, evict other members or
  change ownership; owner handoff on leave is rules-enforced.
- The plaintext password is never persisted anywhere (server or device); the
  invite sheet can only show it in the session that typed it.

The rules are tested against the Firestore emulator — see
[`test/rules/`](test/rules/) — and rules changes run CI like any other change.

### Required Firebase setup

1. Add `android/app/google-services.json` for package `cat.eespunes.thrive`.
2. Enable **Email/Password** (and Google) in Firebase Authentication.
3. Create Firestore in production mode.
4. Deploy rules + indexes:

```sh
firebase use thrive-b1545
firebase deploy --only firestore:rules,firestore:indexes
```

> Deploy the rules **before** rolling out an app release that depends on rules
> changes — the rules are written to stay compatible with the previous app
> version so this order is always safe.

5. (Recommended) Enable **Firebase App Check** in the console (Play Integrity
   for Android, DeviceCheck/App Attest for iOS). The client initializes App
   Check at startup when the platform provides it; enforcement is switched on
   per-product in the Firebase console once real traffic is attested.

## Development

```sh
flutter analyze          # must be clean (CI runs with --fatal-infos)
flutter test             # widget + unit suite
cd test/rules && npm test  # Firestore security-rules suite (needs Java 21+)
```

CI (`.github/workflows/pr-flutter.yml`) runs format check, analyze, tests and a
coverage gate on every PR; `rules-tests.yml` runs the security-rules suite when
rules-related files change. Dependabot keeps pub packages and GitHub Actions
current.
