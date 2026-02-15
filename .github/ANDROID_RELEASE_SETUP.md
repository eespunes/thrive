# Android Release Setup (GitHub Actions + Google Play)

This repo includes an automated workflow at `.github/workflows/release-android.yml`.

## What it does
- Triggers automatically when you push a tag like `v1.2.3`.
- Builds Flutter Android release (`.aab`).
- Uploads the bundle to Google Play.
- Default tag behavior publishes to `production`.
- You can also run it manually from Actions and choose track (`internal`, `alpha`, `beta`, `production`).

## Required repository secrets
Add these in `GitHub > Settings > Secrets and variables > Actions`:

- `ANDROID_KEYSTORE_BASE64`: Base64 of your upload keystore (`.jks`)
- `ANDROID_STORE_PASSWORD`: Keystore password
- `ANDROID_KEY_PASSWORD`: Key password
- `ANDROID_KEY_ALIAS`: Key alias name
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Full JSON of Play Console service account key
- `ANDROID_PACKAGE_NAME`: App package id (example: `com.thrive.app`)

## Google Play Console requirements
1. Create app in Play Console.
2. Create Service Account in Google Cloud project linked to Play Console.
3. Grant service account access in Play Console (`Release manager` or appropriate role).
4. Enable API access in Play Console.
5. Upload at least one initial release manually once if Play Console requests bootstrap setup.

## Keystore note
The workflow writes keystore to `android/upload-keystore.jks` and `android/key.properties` at runtime.
Your Flutter Android config must read `android/key.properties` in `android/app/build.gradle`.

## Versioning note
Google Play requires a unique increasing `versionCode` per release.
Ensure each tagged release increments Android versionCode.

## Usage
- Auto release:
  - Create and push tag: `git tag v1.0.0 && git push origin v1.0.0`
- Manual release:
  - Open GitHub Actions > `Release Android to Google Play` > `Run workflow`
