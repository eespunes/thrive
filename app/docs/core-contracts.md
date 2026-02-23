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
| `CanonicalFinanceModelContract` + `CanonicalFinanceEntity` | Mobile Platform + Finance Domain | Define canonical finance identifiers, references, soft deletion, and schema migration rules. |
| `FirestoreSecurityAccessMatrix` | Mobile Platform + Backend Platform + Security | Enforce role/resource access authorization with least-privilege defaults. |
| `CloudFunctionContractExecutor` + `FunctionIdempotencyStore` | Mobile Platform + Backend Platform | Enforce function payload/response contracts, idempotency replay, and retry backoff policy. |
| `OfflineSyncQueue` | Mobile Platform + Data Platform | Define offline mutation queue, sync cycle states, and deterministic conflict semantics. |
| `RealtimeSubscriptionController` + `CursorPaginator` + `RealtimePageCache` | Mobile Platform + Data Platform | Define realtime listener lifecycle, cursor pagination, and TTL cache invalidation behavior. |
| `NotificationInfrastructureContract` | Mobile Platform + Backend Platform | Define push token lifecycle, channel preference mapping, and delivery retry diagnostics. |
| `AuditLogContract` | Mobile Platform + Security + Compliance | Define immutable audit schema, actor/source attribution, and retention-aware history queries. |
| `ObservabilityMonitoringContract` | Mobile Platform + SRE | Define structured logging contract, crash capture flow, and alert routing thresholds. |
| `AnalyticsEventTaxonomyContract` | Product Analytics + Mobile Platform | Define analytics naming/schema governance, privacy-safe payload validation, and deprecation rules. |
| `BackupRestoreExportPolicyContract` | Mobile Platform + Backend Platform + Compliance | Define backup cadence execution, restore drill validation, and export access safeguards. |

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
- Canonical model validation must emit stable codes for invalid entity shape, schema mismatch, soft-delete protection, reference gaps, and schema migration outcomes.
- Firestore access matrix must emit `firestore_access_allowed` for allowed paths and deterministic deny codes (`firestore_access_denied`, `firestore_workspace_invalid`) for blocked paths.
- Cloud functions execution must emit request intake, retry scheduling, idempotent replay, and terminal success/failure with stable failure codes.
- Offline sync must expose deterministic queue states (`idle`, `queued`, `syncing`, `error`) and emit sync conflict/recovery telemetry.
- Realtime contracts must emit subscription start/event/stop signals and deterministic pagination/cache failures (`pagination_cursor_invalid`, `realtime_cache_expired`, `realtime_query_key_invalid`).
- Notifications contract must emit deterministic token lifecycle (`push_token_registered`, `push_token_refreshed`) and delivery diagnostics (`notification_delivery_attempt_failed`, `notification_delivery_failed`).
- Audit contract must emit immutable write/query signals and deterministic failures for attribution and query window violations.
- Observability contract must enforce structured log payload fields, crash capture outcomes, and threshold-based alert routing signals.
- Analytics taxonomy must enforce event naming/schema validation, PII checks, and definition lifecycle/deprecation signaling.
- Backup/restore/export contract must emit scheduled backup, restore drill, and export control signals with stable failure codes.

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
- Canonical finance migration must reject unsafe schema downgrade and keep user messaging non-technical while preserving diagnosable internal context.
- Firestore deny paths must default to least privilege for unknown roles/resources and return user-safe authorization feedback.
- Idempotent function retries must avoid duplicate writes and provide replay-safe responses for repeated requests.
- Offline sync must keep queued mutations when offline and support conflict resolution policy without silently dropping local intent.
- Realtime cache misses/expiry must trigger safe refresh behavior; stale subscription handles must be detached to avoid duplicate listeners.
- Notification delivery retries should fail safely with user-actionable messaging and avoid leaking token internals.
- Audit history retrieval must enforce retention limits while preserving immutable event records for compliance review.
- Observability alerts must include owner metadata to route incidents without manual reassignment.
- Analytics events must reject potential PII and deprecated schemas to prevent data governance violations.
- Export requests must enforce authorization and rate limits before generating user-visible data artifacts.
