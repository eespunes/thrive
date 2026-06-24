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

## Data persistence & privacy

All budget data (accounts, blocks, monthly items, limits) is stored **locally
on the device** in `SharedPreferences` under the `thrive.v3` key as plain JSON.
There is no backend or cloud sync.

Security assumptions:

- **Local-only, unencrypted.** The data is not encrypted at rest; it relies on
  the OS app sandbox for isolation. Do not store data that requires
  encryption-at-rest without first moving to a secure store
  (e.g. `flutter_secure_storage`).
- **Excluded from backups.** On Android the app sets `allowBackup="false"` and
  ships `res/xml/data_extraction_rules.xml`, which excludes `SharedPreferences`
  from both cloud backups and device-to-device transfers so financial data is
  never copied off-device implicitly.
- **Resilient restore.** Corrupted or out-of-range persisted state is validated
  on boot (month index clamped, screen whitelisted, empty accounts/categories
  replaced with defaults) and falls back to the bundled seed instead of
  crashing.

