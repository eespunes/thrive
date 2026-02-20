# Agent Workflow (Thrive)

This file defines mandatory behavior for Codex agents working in this repository.

## PR + Copilot Review Loop (Mandatory)

When a change is ready, always follow this loop:

1. Create the PR.
2. Explicitly request Copilot as reviewer.
3. Start active monitoring immediately:
   - PR checks
   - Copilot review publication
   - Open Copilot review threads
4. Wait until Copilot publishes review content for the current PR head SHA.
5. If Copilot adds comments:
   - Fix the comments in code/docs.
   - Run local validation (`flutter analyze`, `flutter test`).
   - Commit and push.
   - Resolve addressed review threads.
   - Request Copilot review again.
   - Return to step 3.
6. Repeat until Copilot publishes no new comments (open Copilot threads = 0).

## Monitoring Rule

- Do not wait for unrelated checks before addressing new Copilot comments.
- If new Copilot comments appear, prioritize them immediately.

## Completion Rule

A PR is considered ready only when all of the following are true:

- No open Copilot review threads.
- Copilot has reviewed the latest head SHA.
- Required CI checks are green.
