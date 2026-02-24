# Thrive App (Flutter)

Thrive mobile application for Android and iOS.

## Requirements
- Stable Flutter SDK
- Dart SDK compatible with `app/pubspec.yaml`
- Java 17 (Android toolchain)

## Run Locally
```bash
cd app
flutter pub get
flutter run
```

## Local Quality Checks
```bash
cd app
flutter analyze --fatal-infos
flutter test
```

## Versioning
- Build version is defined in `app/pubspec.yaml` (`X.Y.Z+N`).
- UI version label is defined in `app/lib/core/version/spec_version.dart` (`vX.Y.Z`).
- Automatic version bump runs from `.github/workflows/version-bump-on-main.yml` using `scripts/bump_version.sh`.

## Core Architecture
- Entry point: `app/lib/main.dart`
- App shell: `app/lib/core/app.dart`
- Global state: Riverpod (`app/lib/core/state/`)
- Modules: `app/lib/modules/`
- Core contracts: `app/lib/core/`

## Branding
- Logos: `app/assets/logos/`

## Related CI/CD
- PR quality: `.github/workflows/pr-flutter.yml`
- Copilot gate: `.github/workflows/copilot-review-gate.yml`
- Auto version bump: `.github/workflows/version-bump-on-main.yml`
- Android release: `.github/workflows/release-android.yml`
