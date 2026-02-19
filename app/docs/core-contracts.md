# Shared Core Contracts

## Ownership

| Contract | Owner | Purpose |
| --- | --- | --- |
| `AppResult<T>` | Mobile Core | Deterministic success/failure response model for all layers. |
| `AppLogger` | Mobile Core + SRE | Unified operational logging contract with structured metadata. |
| `FeatureModule` + `ModuleRegistry` | Mobile Platform | Enforce module bootstrap contract and route registration. |
| `LayerRuleValidator` | Mobile Platform | Validate dependency direction and architecture boundaries. |
| `ThriveTheme` + `design_tokens` | Design System Team | Build token-driven theme with observable startup. |
| `BrandAssetRegistry` + `ThriveLogo` | Design System Team + Mobile Platform | Register official brand assets and provide safe runtime fallback. |
| `AppRouteRegistry` + `AppRouteGuardState` | Mobile Platform + Auth/Family Domain | Resolve routes centrally and enforce auth/workspace guards. |

## Operational Criteria

- Every recoverable error must carry both `developerMessage` and `userMessage`.
- Feature modules must log configuration (`feature_module_configured`) and registration (`module_registered`).
- Layer validation must produce deterministic output order for CI diagnostics.
- Duplicated route registration must fail fast via `StateError`.
- Theme bootstrap must emit `theme_loaded`.
- Brand bootstrap must emit `brand_assets_registered`; rendering issues must emit `brand_asset_render_failed`.
- Navigation resolution must emit `route_navigation_resolved`, guard denials must emit `route_guard_blocked`, and unknown routes must emit `route_unknown_fallback`.

## Recovery Criteria

- User-facing failures should avoid internal technical details.
- Operational logs must include stable `code` values to support alerting and runbooks.
- Module bootstrap failures stop startup early to prevent partial app states.
- Branding failures must degrade gracefully with user-safe fallback text.
- Route guard failures must redirect to user-safe routes (`/login` or `/family/workspace`) without exposing internal errors.
