# Thrive App (Flutter)

Aplicacion movil de Thrive para Android e iOS.

## Requisitos
- Flutter estable
- Dart SDK compatible con `app/pubspec.yaml`
- Java 17 (Android toolchain)

## Ejecutar local
```bash
cd app
flutter pub get
flutter run
```

## Calidad local
```bash
cd app
flutter analyze --fatal-infos
flutter test
```

## Versionado
- La version de build se define en `app/pubspec.yaml` (`X.Y.Z+N`).
- La version visible en la UI se define en `app/lib/core/version/spec_version.dart` (`vX.Y.Z`).
- El bump automatico se realiza desde `.github/workflows/version-bump-on-main.yml` usando `scripts/bump_version.sh`.

## Arquitectura base
- Entrada: `app/lib/main.dart`
- App shell: `app/lib/core/app.dart`
- Estado global: Riverpod (`app/lib/core/state/`)
- Modulos: `app/lib/modules/`
- Contratos core: `app/lib/core/`

## Branding
- Logos: `app/assets/logos/`

## CI/CD relacionado
- PR quality: `.github/workflows/pr-flutter.yml`
- Copilot gate: `.github/workflows/copilot-review-gate.yml`
- Auto bump version: `.github/workflows/version-bump-on-main.yml`
- Release Android: `.github/workflows/release-android.yml`
