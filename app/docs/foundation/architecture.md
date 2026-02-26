# Mobile Architecture and Modules

This project uses a modular architecture with four explicit layers per feature:

- `presentation`: Flutter widgets and view state wiring.
- `application`: use-case orchestration and flow control.
- `domain`: business contracts and entities.
- `data`: repository implementations and infrastructure adapters.

Cross-feature shared primitives live under `lib/core`.

## Dependency Direction

Allowed dependencies are validated by `LayerRuleValidator`:

- `presentation` -> `application`, `domain`, `core`
- `application` -> `domain`, `core`
- `data` -> `domain`, `core`
- `domain` -> `core`
- `core` -> no feature layer

Any violation is reported deterministically with source file, target import and reason.

## Module Contract

Every feature module implements `FeatureModule` and is registered through `ModuleRegistry`.
A module must:

- expose a stable id,
- be configured with `AppLogger`,
- publish routes via `FeatureRoute`.

`ModuleRegistry` logs module registration and rejects duplicated routes.
