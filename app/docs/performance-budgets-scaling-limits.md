# Performance Budgets and Scaling Limits

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `PerformanceBudgetsContract` | Mobile Platform + SRE | Evaluate flow budgets, enforce load protection, and provide profiling workflow guidance. |

## Performance Budgets Per Critical Flow

- Budgets track latency, payload size, and throughput for named critical flows.
- Budget evaluation emits deterministic regression codes when thresholds are exceeded.
- Success path emits `performance_budget_passed`; regressions emit `performance_budget_regression_detected`.

## Load Limits and Protection Controls

- Load protection evaluates concurrent request and queue depth limits.
- Overload with shedding enabled returns deterministic shed decision (`load_shedding_applied`).
- Overload with shedding disabled fails with `load_protection_overloaded`.

## Profiling and Optimization Workflow

- Profiling plan includes trace capture, p95 hotspot identification, and post-optimization comparison.
- Workflow setup emits `profiling_workflow_created` with target owner metadata.

## Operational Signals

- `performance_budget_passed`
- `performance_budget_regression_detected`
- `load_protection_allowed`
- `load_protection_shedding_applied`
- `load_protection_overloaded`
- `profiling_workflow_created`

## Recovery Guidance

- Use regression metadata to prioritize optimization by user impact.
- Keep user-facing overload responses non-technical and retry-friendly.
- Treat recurring regressions as release blockers for affected critical flows.
