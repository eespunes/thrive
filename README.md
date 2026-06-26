# Family Money Management App

Flutter mobile app for managing the family budget, based on the supplied UI mockup.

## Platforms

- Android
- iOS

The generated web, macOS, Linux, and Windows targets have been removed so the project stays focused on mobile.

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
   deletes sole-owner families (doc + public handle + join credential), and deletes
   the Firebase Auth user.
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

Release builds are configured to fail fast if Firebase config or signing config is missing.

## Data persistence & multi-device sync

The app stores data locally in `SharedPreferences` and, when Firebase is
configured, syncs a shared family workspace to Firestore so multiple signed-in
users can share one budget:

- `users/{uid}` — per-user profile + the families they belong to.
- `families/{familyId}` — the shared workspace; `memberUids` drives access.
- `family_codes/{username}` — **backend-only** credential resolver (salted
  password hash). Clients cannot read or write it.

### Family join security

Joining a shared family is **server-authoritative**. Firestore security rules
cannot verify a password and the password hash must never be client-readable,
so credential storage and password verification live in Cloud Functions:

- `createFamilyCredentials` — the family owner registers the join
  username/password; the salt + hash are computed and stored server-side.
- `joinFamily` — verifies the password with the Admin SDK and adds the caller
  to the family. There is **no** client path to self-add to a family, so an
  attacker who learns a `familyId` still cannot join without the password.
- `onFamilyDeleted` — purges the credential mapping when a family is deleted.

The `family_codes` collection is locked (`allow read, write: if false`); only
the Admin SDK touches it.

> Keep `kFunctionsRegion` in `lib/.../family_cloud.dart` in sync with `REGION`
> in `functions/index.js` (currently `europe-west1`).

### Required Firebase setup

1. Add `android/app/google-services.json` for package `cat.eespunes.thrive`.
2. Enable **Email/Password** (and Google) in Firebase Authentication.
3. Create Firestore in production mode.
4. Install the Functions dependencies and deploy rules + functions:

```sh
firebase use thrive-b1545
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,functions
```

The current `firestore.rules` are the production rules (no longer a starter
sample): `users` and `user_workspaces` are owner-only, `families` are readable
and editable by members (with owner-only create/delete and no client join
path), and `family_codes` is fully private to the backend.
