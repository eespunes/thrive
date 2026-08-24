# Firestore rules tests

Tests `firestore.rules` against the Firestore emulator using
`@firebase/rules-unit-testing` and Node's built-in test runner.

## Requirements

- Node 20+
- Java 21+ (required by firebase-tools for the Firestore emulator)
- `firebase-tools` on PATH (`npm i -g firebase-tools`)

## Run

```bash
cd test/rules
npm install
npm test
```

`npm test` wraps `firebase emulators:exec --only firestore` (port 8091, see
`firebase.json`), so the emulator starts and stops automatically.

CI: `.github/workflows/rules-tests.yml` runs this on PRs touching
`firestore.rules`, `firebase.json`, or `test/rules/**`.
