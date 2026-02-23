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
| `appLoggerProvider` + `ThriveProviderObserver` | Mobile Core + SRE | Standardize provider wiring and lifecycle observability. |
| `ThriveFieldValidators` + `ThriveErrorMapper` | Mobile Platform + Backend | Standardize field validation and server/network error mapping. |
| `AuthSessionLifecycle` + `AuthSessionStore` | Mobile Platform + Auth Backend | Define deterministic session creation, refresh, sign-out, and revocation handling. |
| `FamilyWorkspaceRbac` + `FamilyMembership` | Mobile Platform + Family Domain | Define family membership states, role-based protected actions, and ownership transition rules. |
| `FirebaseEnvironmentLoader` + `FirebaseProjectConfigRegistry` + `FirebaseDeployContext` | Mobile Platform + Backend Platform + DevOps | Enforce deterministic Firebase environment resolution and deploy targeting. |

## Operational Criteria

- Every recoverable error must carry both `developerMessage` and `userMessage`.
- Feature modules must log configuration (`feature_module_configured`) and registration (`module_registered`).
- Layer validation must produce deterministic output order for CI diagnostics.
- Duplicated route registration must fail fast via `StateError`.
- Theme bootstrap must emit `theme_loaded`.
- Brand bootstrap must emit `brand_assets_registered`; rendering issues must emit `brand_asset_render_failed`.
- Navigation resolution must emit `route_navigation_resolved`, guard denials must emit `route_guard_blocked`, and unknown routes must emit `route_unknown_fallback`.
- Riverpod lifecycle observability must emit `provider_added`, `provider_updated`, `provider_disposed`, and `provider_failed`.
- Form validation failures must emit `form_validation_failed`; recoverable login failures must expose retry with deterministic failure codes.
- Session lifecycle must emit `auth_session_created`, `auth_token_refreshed`, `auth_session_signed_out`, and `auth_session_revoked`.
- Family workspace authorization must emit `family_member_joined`, `family_action_authorized`, `family_action_forbidden`, and `family_ownership_transferred`.
- Firebase bootstrap must emit `firebase_environment_selected`; invalid env or deploy mismatches must fail fast with deterministic codes.

## Recovery Criteria

- User-facing failures should avoid internal technical details.
- Operational logs must include stable `code` values to support alerting and runbooks.
- Module bootstrap failures stop startup early to prevent partial app states.
- Branding failures must degrade gracefully with user-safe fallback text.
- Route guard failures must redirect to user-safe routes (`/login` or `/family/workspace`) without exposing internal errors.
- Workspace switches must invalidate workspace-scoped providers to avoid stale cross-family state.
- Form recovery actions must support retry without data loss and must not expose backend internals to the user.
- Revoked or expired sessions must clear local auth state and force a safe re-authentication path without exposing token internals.
- Role violations must fail with deterministic, user-safe authorization messages and preserve existing membership records.
- Firebase environment drift must be diagnosable through stable codes and mismatch details (`firebase_environment_drift`) without exposing secrets to end users.
