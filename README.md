# Family Money Management App

Flutter mobile app for managing the family budget, based on the supplied UI mockup.

## Platforms

- Android
- iOS

The generated web, macOS, Linux, and Windows targets have been removed so the project stays focused on mobile.

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
configured, syncs workspace state to Firestore (`user_workspaces/{uid}`) so the
same account can continue on multiple devices.

### Required Firebase setup

1. Add `android/app/google-services.json` for package `cat.eespunes.thrive`.
2. Enable **Email/Password** in Firebase Authentication.
3. Create Firestore in production mode.
4. Deploy restrictive rules before real usage.
5. Deploy Firebase configuration:

```sh
firebase use thrive-b1545
firebase deploy --only firestore:rules,firestore:indexes
```

Suggested starter rule:

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /user_workspaces/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```
