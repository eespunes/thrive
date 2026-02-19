# Design System and Brand Assets

## Purpose

Define reusable tokens, UI primitives and official logo usage rules for all mobile modules.

## Design Tokens

Source of truth: `lib/core/design_system/design_tokens.dart`

- Colors: `ThriveColors`
- Spacing: `ThriveSpacing`
- Radius: `ThriveRadius`
- Typography baseline: `ThriveTypography`
- Titles use `Acme` (Google Fonts) as the official heading family.

## Component Primitives

Source of truth: `lib/core/design_system/components/`

- `ThrivePrimaryButton`: primary action control.
- `ThriveSurfaceCard`: default elevated container for content blocks.

## Theme Contract

Source of truth: `lib/core/design_system/thrive_theme.dart`

- Theme is built from tokens on app start.
- Theme load is observable through `theme_loaded` event.
- Theme must keep Material 3 compatibility (`useMaterial3: true`).

## Official Logo Rules

Source of truth: `lib/core/branding/`

- Official assets:
  - `assets/logos/thrive-colored.svg`
  - `assets/logos/thrive-unicolor.svg`
- Registration MUST happen before use through `BrandAssetRegistry`.
- If a requested variant is unavailable, registry falls back to unicolor deterministically.
- If asset rendering fails at runtime, UI shows user-safe fallback text.

## Operational Signals

- `brand_assets_registered`
- `brand_asset_fallback`
- `brand_asset_render_failed`
- `brand_assets_not_registered`
