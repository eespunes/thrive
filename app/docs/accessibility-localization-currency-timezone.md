# Accessibility, Localization, Currency, and Timezone

## Ownership

| Contract | Owner | Responsibility |
| --- | --- | --- |
| `AccessibilityLocalizationContract` | Mobile Platform + Design System + Localization | Enforce baseline accessibility semantics and locale/currency/timezone-safe formatting. |

## Accessibility Baseline and Semantics

- Accessibility validation requires non-empty node identity, role, and label.
- Contrast ratio must meet baseline threshold (>= 4.5).
- Font scaling baseline must support readability (>= 1.0).

## Localization and Dynamic Formatting

- Supported locales are explicit and validated before formatting.
- Currency codes must be valid ISO-style uppercase 3-letter codes.
- Currency formatting applies locale-specific separators and currency symbols.

## Timezone-Safe Date Calculations

- Timezone offsets are validated and normalized before month-bound calculations.
- Month start/end are computed in local timezone and converted back to UTC.
- This avoids month-boundary drift when UTC dates cross local offsets.

## Operational Signals

- `accessibility_baseline_validated`
- `accessibility_baseline_failed`
- `localization_settings_resolved`
- `timezone_month_bounds_computed`
- `localization_locale_unsupported`
- `localization_currency_invalid`
- `localization_timezone_invalid`

## Recovery Guidance

- Reject unsupported locale/timezone inputs with user-safe guidance.
- Keep formatting deterministic per locale to avoid calculation mismatches.
- Treat accessibility baseline failures as release-blocking for impacted screens.
