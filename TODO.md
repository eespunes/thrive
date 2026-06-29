# Thrive — Family Management Roadmap (Phase 3)

Prioritized backlog for evolving Thrive from a finance manager into a full family
management app. **Design source of truth:** Claude Design → `Thrive.dc.html`
→ https://claude.ai/design/p/858900da-9b9d-4796-b33e-462c7c15922b?file=Thrive.dc.html

Implement the design **100% accurately**. To find a screen's code, open `Thrive.dc.html`
and search for its `render*()` method (noted per issue).

Epic: **#148**.

---

## Priority order

### P0 — Foundations (block everything else)

| # | Issue | Blocks |
| --- | --- | --- |
| #149 | App-shell / nav refactor (Home · Calendar · Lists · Finance · More + Quick-Add FAB) | all modules |
| #150 | Shared-family data model + Firestore collections & rules | all modules |
| #151 | Design spec (✅ delivered — `Thrive.dc.html`) | all modules (provides UI) |

### P1 — Core modules

| # | Issue | Blocked by |
| --- | --- | --- |
| #159 | Lists module hub — unified to-do & shopping | #149, #150 |
| #152 | Calendar — month / week / agenda views | #149, #150 |
| #153 | Calendar — create/edit events (recurrence, attendees, category, reminders) | #150, #152, #160 |
| #155 | Lists · to-do tasks (assignee, due date, check-off) | #159, #150 |
| #156 | Lists · shopping items (quick add, qty, check-off) | #159, #150 |
| #158 | Home dashboard (today & upcoming, tasks, shopping, meal) | #149, #152, #155, #156, #157, #162 |

### P2 — Depends on core modules

| # | Issue | Blocked by |
| --- | --- | --- |
| #160 | Calendar event categories (icons, colours & management) | #150, #163 |
| #162 | Global Quick-Add (event / task / shopping item) | #149, #153, #155, #156 |
| #157 | Weekly plan — meals (breakfast/lunch/dinner) & notes | #149, #150 |
| #154 | Event & task reminders / notifications | #150, #153, #155 |
| #163 | "More" hub + Profile screen | #149 |
| #161 | Import external calendars (Google / Apple / ICS) — read-only | #150, #152, #163 |

---

## Blocking graph

```
#149 app-shell ─┐
                ├─> #159 lists hub ─┬─> #155 tasks ─┐
#150 data ──────┤                  └─> #156 shopping┤
                │                                    ├─> #158 home dashboard
                ├─> #152 cal views ─> #153 events ───┤
                │        ▲              │            │
                │        │              ├─> #154 notifications
#163 more hub <─┤   #160 categories ────┘
                │        ▲
                ├─> #161 calendar import
                ├─> #157 weekly plan ───────────────> #158
                └─> #162 quick-add (needs #153/#155/#156) > #158
#151 design (delivered) ─> provides UI for every issue above
```

## Suggested build sequence

1. **#149 + #150** in parallel (shell scaffolding + data layer). Nothing ships without these.
2. **#159 lists hub**, then **#155 tasks** + **#156 shopping** (simplest module, validates the data layer & sync).
3. **#152 calendar views** → **#160 categories** → **#153 event editor** (events need categories for the picker).
4. **#157 weekly plan** (self-contained).
5. **#162 quick-add** + **#158 home dashboard** (aggregate the modules above).
6. **#154 notifications** and **#161 calendar import** (build on events/tasks; import is the heaviest, do last).
7. **#163 more hub + profile** alongside #149 (re-homes existing family/finance settings).

## New surfaces the design added (not in the original backlog)

- **#159** — Lists is **one** tab for to-do **and** shopping (was two separate stories/tabs).
- **#160** — event **categories** (icon + colour).
- **#161** — **import** external calendars (read-only) — previously out-of-scope, now in scope.
- **#162** — global **Quick-Add** FAB.
- **#163** — **More** hub + dedicated **profile** screen.
