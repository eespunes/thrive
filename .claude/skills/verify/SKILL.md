---
name: verify
description: Build, launch and drive the Thrive app for runtime verification (web smoke-test recipe, local/demo mode).
---

# Verifying Thrive at runtime

The fastest real surface is **Flutter web in headless Chromium**, running in
local/demo mode (Firebase init fails on web — no web config — and the app
falls through to SharedPreferences-backed local mode).

## Build & serve

```bash
flutter build web --release          # needs web/index.html (already in repo)
cd build/web && python3 -m http.server 8124 &
```

Do NOT use `flutter run -d web-server --release` directly — it serves from
`build/web` but doesn't build it first (500s until you `flutter build web`).

## Drive

Playwright (`npm i playwright` in a scratch dir) with a **persistent
context** (`chromium.launchPersistentContext(profileDir)`) — a fresh context
loses localStorage, so sign-in/state won't survive between script runs.
Viewport 420×900 matches a phone layout. The app renders to canvas, so drive
by screenshot + coordinate clicks; `page.keyboard.type` works after clicking
a text field.

Useful flows (coordinates at 420×900):
- Auth screen: email (210,471), password (210,544), Sign in (210,603).
  Any email/password works in local mode.
- Bottom nav: Home 45 / Calendar 127 / Lists 210 / Finance 292 / More 375,
  all at y=870.
- More → profile row (210,106) → profile sheet: Create (111,788),
  Join (308,788), Sign out (210,851).
- More → Invite someone (210,758) shows the join credentials sheet.

## Inspect persisted state

SharedPreferences lives in localStorage with `flutter.` key prefix:
`flutter.thrive.v4` (main state blob), `flutter.thrive.registry` (local
family registry), `flutter.thrive.user`. Dump via `page.evaluate` — don't
truncate values if grepping for content, the v4 blob is large.

## Caveats

- Cloud/Firestore paths can't be exercised on web (no Firebase web config);
  they need a device build against live Firebase — don't smoke-test those
  against production data.
- `flutter test` covers local-mode logic well (368+ tests) but is CI, not
  verification.
