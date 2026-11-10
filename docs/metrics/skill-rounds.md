# Skill round metrics

How the orchestrator skills and agents perform across test rounds. Each snapshot uses the same metric
set, collected from every open worker session (its `metrics-log-file` and run-state) and checked
against the Hub's cross-worker view. The numbers are self-reported by the sessions; flagged values are
marked.

## Metric set

Collected per session, per snapshot:

1. Items run since the last snapshot: ID, type, final status.
2. Per item: `loop_count`, Reviewer FAILs and why, escalations, Integration passes, Parity runs and
   FAILs, wall-clock time.
3. The same numbers for earlier runs, for comparison.
4. Skill surprises raised: count, fixed, open.
5. One line: better, same or worse, and the biggest remaining pain point.

Derived, per snapshot:

| Measure | How |
|---|---|
| First-review pass rate | items whose first Reviewer verdict was PASS ÷ reviewed items (spikes excluded) |
| Escalations | `Escalated? = Yes` rows (model or loop escalation only, not hub rulings) |
| Integration first-pass rate | Integration blocks that passed on pass 1 ÷ Integration blocks |
| Time per item | wall clock, start of Phase 0 to close-out |
| Restart survival | sessions that parked and resumed cleanly ÷ sessions restarted |
| Hub rulings | count of rulings the Hub made in the period |
| Skill surprises | raised / fixed / open |

## Snapshot 1 — 2026-11-11, about 10:00 +11:00

Skills installed: orchestrator 2.14.0 → 2.14.1, plugin orchestrator 1.11.0 → 1.11.1 during the
period. Commit `788f195` (2.15.0 / 1.12.0) installed but not yet loaded by any session.

| Measure | Before (2026-11-03 to 11-10) | This round (11-10 to 11-11 10:00) |
|---|---|---|
| Items finished | about 38 | 9 reviewed, plus 1 spike |
| First-review pass rate | about 78% | 6 of 9 (67%) |
| Escalations | 0 | 0 |
| Integration first-pass rate | most; 3 retries (F-044, F-015, B-005) | 5 of 6 (B-005 doc-only retry) |
| Time per item | 1–1.5 h typical; F-077 Developer 3.6 h; B-025 about 1 day | 20–77 min (F-109 23m, F-110 20m, B-005 25m, B-021 77m) |
| Restart survival | not tested | 8 of 8 parked; 5 of 5 resumed |
| Board Parity | B-025: 2 retries (8, then 3 differences) | B-021: PASS first run, 0 differences |
| Hub rulings | not counted | about 20 |
| Skill surprises | — | about 30 raised; all fixed in the repo once round 4 lands (round 4 uncommitted at snapshot) |

Items this round, by worker:

| Worker | Item | Type | loop_count | Reviewer FAILs | Integration passes | Notes |
|---|---|---|---|---|---|---|
| Hub (shell) | SHELL-F-109 | Feature | 0 | 0 | 1 | 23 min |
| Hub (shell) | SHELL-F-110 | Feature | 1 | 1 | 1 | 20 min |
| Hub (ofa) | OFA-B-021 | Bug | 0 | 0 | 1 | Parity PASS; 77 min |
| compliance | COMPLIANCE-DASHBOARD-B-005 | Bug | 0 | 0 | 2 | retry doc-only; 25 min |
| compliance | COMPLIANCE-DASHBOARD-B-006 | Bug | 0 | 0 | 1 | |
| advisor | ADVISOR-DASHBOARD-B-007 | Bug | 0 | 0 | 1 | measured 10.80 s → 2.14 s; resumed after restart. Phase times flagged unreliable (estimated timestamps) |
| advisor | ADVISOR-DASHBOARD-F-079 | Spike | — | — | — | Developer 19.9 min |
| ps | OFA-F-082 | Feature | 0 | 0 | — | in progress at snapshot |
| log viewer | F-007 | Feature | 2 | 1 | — | collation not total |
| log viewer | F-008 | Feature | 2 | 1 | — | catch too broad; about 11 min agent time |

Read of the snapshot:

1. Speed improved clearly: items take 20–77 minutes against 1–1.5 hours before.
2. The first-review pass rate is flat or slightly down, on a small sample; the three FAILs were real
   defects caught.
3. No escalations in either period.
4. Biggest remaining pain: missing data or cross-component work found at Phase 0 instead of when the
   PMBook row is written; then board parity on UI items, and port contention for the artboard server.
5. The sample is too small to call. Next collections: 2026-11-11 13:00 and 17:00 +11:00.

## Snapshot 2 — 2026-11-11, 13:00 +11:00

To be collected. First snapshot on round 4 (orchestrator 2.16.0, plugin orchestrator 1.13.0).

## Snapshot 3 — 2026-11-11, 17:00 +11:00

To be collected.
