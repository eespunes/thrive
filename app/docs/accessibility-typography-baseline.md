# Accessibility and Typography Baseline

## Ownership

| Area | Owner | Responsibility |
| --- | --- | --- |
| Color tokens and contrast checks | Design System Team | Keep token palette and minimum contrast policy up to date. |
| Typography scale | Design System Team | Maintain readable hierarchy and default font metrics. |
| Runtime diagnostics | Mobile Platform + SRE | Monitor design-system and branding runtime events. |

## Contrast Baseline

| Pair | Ratio | Status |
| --- | --- | --- |
| `ThriveColors.forest` on white | 6.51:1 | Pass (AA normal text) |
| `ThriveColors.midnight` on `ThriveColors.cloud` | 14.40:1 | Pass (AA/AAA normal text) |
| White text on `ThriveColors.forest` | 6.51:1 | Pass (AA normal text) |

Minimum policy:

- Normal text: at least 4.5:1
- Large text (18+ px regular or 14+ px bold): at least 3:1

## Typography Baseline

- Heading: 28/1.2, weight 700
- Body: 16/1.4, weight 400
- Label: 15/1.2, weight 600
- Default family: `Roboto`

## Operational Criteria

- Theme load event (`theme_loaded`) must include color seed and font family metadata.
- Brand registration event (`brand_assets_registered`) must include asset count.
- Failures in branding must never expose internal stack traces to users.

## Recovery Guidance

- If logo rendering fails, show fallback UI and keep navigation functional.
- If registry is uninitialized, return user-safe failure and log a warning.
- Use stable event codes for runbooks and incident dashboards.
