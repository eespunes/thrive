# Firebase Environments and Deploy Targeting

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `FirebaseEnvironmentLoader` + `FirebaseProjectConfigRegistry` | Mobile Platform + Backend Platform | Resolve runtime environment (`dev`, `stg`, `prod`) and map to deterministic Firebase project config. |
| `FirebaseDeployContext` | DevOps + Backend Platform | Validate service account and deploy targets before CI/CD deployment. |
| `FirebaseEnvironmentDriftDetector` | SRE + Mobile Platform | Detect mismatches between expected environment config and runtime snapshot. |

## Runtime Environment Isolation

- Environment is selected through `THRIVE_ENV` (`dev`, `stg`, `prod`) and defaults to `dev`.
- Unsupported values fail fast with `firebase_environment_invalid`.
- Runtime bootstrap logs `firebase_environment_selected` with environment metadata.

## CI Deploy Targeting Contract

- Every environment has a fixed service account and target pair:
  - `dev`:
    - service account: `github-actions-dev@thrive-dev.iam.gserviceaccount.com`
    - targets: `firebase-dev-firestore`, `firebase-dev-functions`
  - `stg`:
    - service account: `github-actions-stg@thrive-stg.iam.gserviceaccount.com`
    - targets: `firebase-stg-firestore`, `firebase-stg-functions`
  - `prod`:
    - service account: `github-actions-prod@thrive-prod.iam.gserviceaccount.com`
    - targets: `firebase-prod-firestore`, `firebase-prod-functions`
- Validation failures are deterministic:
  - `firebase_service_account_mismatch`
  - `firebase_deploy_target_mismatch`

## Environment Drift Detection

- Compare expected environment config against runtime snapshot (`environment`, `projectId`, `appId`, `storageBucket`).
- Drift returns `firebase_environment_drift` and includes mismatch details in `developerMessage`.
- User messaging remains safe and non-technical to avoid leaking internal setup details.

## Operational Signals

- `firebase_environment_selected`
- `firebase_environment_invalid`
- `firebase_service_account_mismatch`
- `firebase_deploy_target_mismatch`
- `firebase_environment_drift`
