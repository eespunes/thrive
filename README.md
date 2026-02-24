# Thrive

<p align="center">
  <img src="app/assets/logos/thrive-colored.svg" alt="Thrive Logo" width="180" />
</p>

<p align="center">
  Family finance app for Android and iOS, built to replace the current Excel workflow.
</p>

## Summary
Thrive centralizes household financial management in a collaborative mobile app: transactions, budgets, debt tracking, fixed costs, savings goals, and phased family workflows.

## Vision
Build a **Family OS**: start with shared finance and evolve into a full household management platform.

## Problem
- Financial data is scattered across spreadsheets.
- It is difficult to know who paid what and what is still pending.
- Debt, recurring costs, and month-close tracking are still manual.

## Solution
- Fast income/expense capture with categories.
- Shared family workspace with role-based access.
- Debt, fixed-cost, and savings-goal tracking.
- Expected vs actual monthly balance with outstanding payments.
- Technical foundation for real-time sync and offline support.

## Technology Stack
- **Frontend:** Flutter (Dart) for Android + iOS
- **State:** Riverpod + repository pattern
- **Backend:** Firebase (Auth, Firestore, Cloud Functions)
- **UI:** Material 3 with Thrive branding
- **CI/CD:** GitHub Actions (Android) and release pipelines

## Roadmap
### Phase 1: Finance MVP (Core)
Goal: replace the family Excel workflow with a stable, collaborative mobile flow.
- Authentication and family onboarding
- Monthly dashboard and transactions
- Debt, fixed costs, reports, and goals
- Settings, members, and local profiles

### Phase 2: Engagement and Home Management
Goal: increase daily usage beyond financial tracking.
- Shopping list connected to budget
- Grocery basket comparison across supermarkets
- Shared household tasks

### Phase 3: Family Organization
Goal: centralize planning and shared calendars.
- Shared calendar
- Financial event synchronization
- External calendar import

### Phase 4: Intelligence
Goal: turn data into useful actions and recommendations.
- Contextual finance assistant
- Receipt/invoice OCR
- Proactive daily briefing
- Scenario simulations

## Current Status
- Functional and technical definition is managed in OpenSpec.
- Backlog is structured by phases using GitHub epics and issues.
- Flutter base app and branding are integrated.

## Documentation
- OpenSpec specs: `openspec/specs/`
- Specs index: `openspec/specs/README.md`
- Android release setup: `.github/ANDROID_RELEASE_SETUP.md`

## Repository Structure
```text
thrive/
├── app/                  # Flutter app
├── openspec/specs/       # Functional and technical specs
├── mockups/              # Visual references and flow diagrams
└── .github/              # Workflows and GitHub templates
```

## Run Locally
```bash
cd app
flutter pub get
flutter run
```

## License
Private repository / internal project use.
