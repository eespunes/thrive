# Android AAB Build Setup (CI on Main + Manual Google Play Upload)

This repo includes an automated workflow at `.github/workflows/release-android.yml`.

## What it does
- Runs automatically on every push to `main` (after merge).
- Can also be run manually from GitHub Actions (`workflow_dispatch`).
- Builds Flutter Android release (`.aab`).
- Uploads the `.aab` as a GitHub Actions artifact.
- Does **not** publish to Google Play.
- Validates required secrets before attempting build/sign.

## Required repository secrets
Add these in `GitHub > Settings > Secrets and variables > Actions`:

- `ANDROID_KEYSTORE_BASE64`: Base64 of your upload keystore (`.jks`)
- `ANDROID_STORE_PASSWORD`: Keystore password
- `ANDROID_KEY_PASSWORD`: Key password
- `ANDROID_KEY_ALIAS`: Key alias name
- `ANDROID_PACKAGE_NAME`: App package id (example: `com.thrive.app`)

## Google Play Console requirements (manual upload flow)
1. Create app in Play Console.
2. Ensure package name matches `ANDROID_PACKAGE_NAME`.
3. Enable Play App Signing.
4. Upload the generated `.aab` manually to `Testing > Internal testing` (or desired track).

## Keystore note
The workflow writes keystore to `android/upload-keystore.jks` and `android/key.properties` at runtime.
Your Flutter Android config must read `android/key.properties` in `android/app/build.gradle.kts`.

## Versioning note
Google Play requires a unique increasing `versionCode` per release.
Ensure each release increments Android `versionCode`.

## Usage
1. Merge PR to `main`.
2. Wait for workflow `Build Android AAB (Main)` to complete.
3. Download artifact `android-release-aab` from the workflow run.
4. Upload `.aab` manually in Play Console.
