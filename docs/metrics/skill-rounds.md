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

Skills installed: round 4 (orchestrator 2.16.0, plugin orchestrator 1.13.0) at 10:12, then up to
2.18.1 / 1.15.1 by 12:35 (temp-file rule, task bar on resume, design system fixed, ports registry).
Sessions picked these up at their own reloads, so items in the period ran on mixed versions.
Collected from 10 sessions; 5 ran orchestrated items (Hub merged and ruled only).

| Measure | Snapshot 1 (to 10:00) | Snapshot 2 (10:00 to 13:00) |
|---|---|---|
| Items finished | 9 reviewed, plus 1 spike | 10 reviewed (6 done, 4 passed review and waiting on Integration or close-out), 1 bug withdrawn at Phase 0 |
| First-review pass rate | 6 of 9 (67%) | 8 of 10 (80%) |
| Escalations | 0 | 1 (log viewer F-025, model escalation at loop 3) |
| Integration first-pass rate | 5 of 6 | 2 of 2 (advisor run 1, ps run 0926); compliance running at snapshot |
| Time per item | 20–77 min | 33–41 min clean (F-093, F-094, F-103); about 95–105 min (est.) with rulings or usage-limit stops (F-010, F-102). Whole runs: ps 3 features 2 h 05 m, advisor 2 features 2 h 29 m |
| Restart survival | 8 of 8 parked; 5 of 5 resumed | 3 of 3 resumed (Hub, compliance cleanly; advisor lost its run work folders and rebuilt F-093's packet from the PMBook) |
| Board Parity | B-021: PASS first run | 11 runs, 4 FAILs; first run passed on 4 of 8 items (F-025 icon size, F-094 field order, F-082 3 differences, F-086 10 differences) |
| Usage-limit stops | — | 3 (F-010 parity, F-102 parity, F-086 Developer), all resumed by message; about 1.5 h idle (est.) |
| Hub rulings | about 20 | about 22 (est.), most on parity differences and scope |
| Skill surprises | about 30 raised; all fixed in the repo | about 30 raised; 8 fixed in the repo, about 18 distinct open (below) |

Items this period, by worker:

| Worker | Item | Type | loop_count | Reviewer FAILs | Integration passes | Notes |
|---|---|---|---|---|---|---|
| ps | OFA-F-082 | Feature | 1 | 0 | 1 | Parity 2 runs: FAIL (3 differences; 2 fixed, 1 ruled a deviation), then PASS. Run 0926: 09:26 to 11:31 |
| ps | OFA-F-089 | Feature | 1 | 0 | 1 | no screen |
| ps | OFA-F-090 | Feature | 1 | 0 | 1 | no screen |
| ps | OFA-F-086 | Feature | 1 | 0 | — | in progress; Parity run 1 FAIL, 10 differences (3 to hub rulings); Developer stopped on usage limit, about 50 min idle (est.) |
| compliance | SHELL-F-103 | Feature | 0 | 0 | running | Parity PASS; 1 mid-attempt ruling; 10:25 to 11:07 |
| compliance | SHELL-F-102 | Feature | 0 | 0 | running | Parity PASS (one usage-limit stop); 11:07 to about 12:50 (est.) |
| compliance | SHELL-F-108 | Feature | 0 | 0 | running | reviewed before 10:00; close-out pending |
| advisor | ADVISOR-DASHBOARD-F-093 | Feature | 0 | 0 | 1 | Part 1 only (hub ruling); Parity PASS; 10:07 to 10:40 |
| advisor | ADVISOR-DASHBOARD-F-094 | Feature | 1 | 0 | 1 | Parity FAIL (filter field order), then PASS; 10:42 to 11:15. Run 1 close-out 12:33 |
| advisor | ADVISOR-DASHBOARD-B-008 | Bug | — | — | — | withdrawn at Phase 0: every part was planned work or by design |
| advisor | ADVISOR-DASHBOARD-B-010 | Bug | 0 | 0 | — | in progress (Reviewer running) |
| log viewer | F-025 | Feature | 3 | 1 | — | lost `main` landmark; Parity FAIL (icon 24 vs 20 px) then PASS; escalated at loop 3. Times est. |
| log viewer | F-010 | Feature | 2 | 1 | — | spec compared against the function under test; Parity PASS after a usage-limit stop; about 25 min waiting on rulings. Times est. |
| log viewer | F-011 | Feature | — | — | — | in progress; 2 rulings pending (calendar vs board, 911 kB bundle) |

Open skill surprises, merged across sessions (who raised them):

1. Parity offers outside differences as bugs without checking the PMBook's planned items and rulings
   first (Hub, advisor: B-008 withdrawn whole).
2. Parity compares the loaded state only; the board's other named states are missed (Hub).
3. Parity calls a board wrong without checking the shared design kit or sibling builds (Hub).
4. A needed mid-run pull meets reviewed but uncommitted work: commit by item, then pull, then
   Integration, is not written down (Hub, compliance).
5. The Reviewer runs only the packet's named tests, so a contract spec on a touched file slips to
   Integration (Hub, compliance: SHELL-F-103).
6. Who approves a drift-fix version bump to a governed doc (Hub).
7. `-- --testPathPattern` does not narrow under Nx 23 + Jest 29; `--testFile` does. Step 0.2 still
   says otherwise (compliance, advisor).
8. A sub-agent stopped by the usage limit: resume it by message, don't respawn (compliance; ps, log
   viewer did this).
9. Close-out's `rm -rf` of run folders is denied; no named safe command (advisor, ps).
10. A held packet's path points inside `runs/<run id>/`, which close-out deletes (ps).
11. A baseline that fails for environmental reasons: re-run once, keep both logs; carry env pins
    into the baseline command (ps, advisor).
12. A restart lost the run's work folders (advisor).
13. Background agents' output files read empty; outputs copied from notifications (log viewer).
14. Stopping a dev server leaves its child process on the port (log viewer).
15. Config changes need a server restart before parity; not said when (log viewer).
16. Context7 is not callable inside a Developer sub-agent (log viewer).
17. One-path bindings in a repo with two projects (revision and changelog files) (AI Form Filler).
18. Moving a tool's port can need a new tracked config file (Karma) (AI Form Filler).

Read of the snapshot:

1. **Review is better.** First-review pass rate rose from 67% to 80%, and both finished Integration
   blocks passed first time.
2. **Parity is now the main cost.** 4 of 8 items failed their first parity run, and most of the
   Hub's about 22 rulings were parity differences. Four sessions name it as the biggest pain: some
   differences surface only after the build, and some reach the Hub as bugs or "board wrong" claims
   that the backlog, the rulings or the design kit would have settled (open items 1–3).
3. **The usage limit is a new cost.** Three stops, about 1.5 hours idle (est.). Resuming by message
   worked every time; the skill doesn't say so yet.
4. **Speed held.** Clean items still take 33–41 minutes; the slow ones are slow from waiting on
   rulings or the limit, not from rework.
5. **First escalation** (F-025, loop 3). One in 10 is within reason; watch it at 17:00.
6. **Data quality:** the metrics log is written only at close-out, so open runs report estimated
   times (log viewer's are all estimated). A row per gate would fix that.

## Snapshot 3 — 2026-11-11, 17:30 +11:00

Skills installed: 2.19.0 / 1.16.0 (Makefile targets) at 13:30, 2.20.1 / 1.17.1 (sizing, build-output
rule, free ports taken without asking) by 14:47. **Collected from files, not sessions:** every worker
session was offline at 17:30 (the user paused them about 15:55 for session limits, resuming 17:40), so
the numbers come from each checkout's `metrics-log-file` and run-state. Skill surprises come from the
messages the workers sent this hub. No item ran on 2.20.x, so no item has a size yet.

| Measure | Snapshot 2 (10:00 to 13:00) | Snapshot 3 (13:00 to 17:30) |
|---|---|---|
| Items finished | 10 reviewed, 1 bug withdrawn | 9 reviewed (1 done, 8 passed review and waiting on verification, Integration or close-out); 2 bugs dropped at review (OFA-B-034 as designed, OFA-B-036 duplicate) |
| First-review pass rate | 8 of 10 (80%) | 7 of 9 (78%) |
| Escalations | 1 | 0 |
| Integration first-pass rate | 2 of 2 | 1 of 2 (ps F-086 PASS; compliance shell block passed on a doc-only retry) |
| Time per item | 33–41 min clean | B-009 43 min to verification; F-086 about 2 h (est., 2 parity retries). Whole run: compliance shell, 3 features, 09:45 to 14:06 |
| Restart survival | 3 of 3 resumed | not tested this period; 4 runs parked at a named step for the 17:40 resume |
| Board Parity | 11 runs, 4 FAILs | about 9 runs, at least 4 FAILs (F-086 ×2, B-010, F-011); first run passed on 3 of 6 finished items; 2 stopped by the pause |
| Usage-limit stops | 3 | all 4 active sessions paused at once, about 15:55, for session limits |
| Hub rulings | about 22 | not collected (sessions offline); at least 6 in run-state (F-086 G1–G3, B-034, B-036, B-010 dialog title) |
| Skill surprises | about 30 raised; about 18 open | about 16 raised (Makefile adoption, ports, WSL bash, build output, sizing), all fixed and installed; Snapshot 2's 18 still open |

Items this period, by worker:

| Worker | Item | Type | Size | loop_count | Reviewer FAILs | Integration passes | Notes |
|---|---|---|---|---|---|---|---|
| compliance | Shell run (F-108, F-103, F-102) | Integration | — | 1 | — | 2 | doc-only retry; npm audit 86 and dotnet 2 as known-reds; e2e not run (hub-accepted); closed 14:06 |
| compliance | COMPLIANCE-DASHBOARD-F-004 | Feature | — | 1 | 1 | — | Reviewer PASS at loop 1; parity stopped by the pause |
| ps | OFA-F-086 | Feature | — | 2 | 0 | 1 | Parity FAIL (10), FAIL (4), PASS; Reviewer-Integration PASS; done 14:29; raised B-032 to B-037 |
| ps | OFA-B-030 | Bug | — | 0 | 0 | — | review and parity done; waiting on manual verification |
| ps | OFA-B-037 | Bug | — | 0 | 0 | — | as B-030 |
| ps | OFA-B-035 | Bug | — | 0 | 0 | — | review PASS; parity stopped by the pause |
| ps | OFA-B-034, OFA-B-036 | Bug | — | — | — | — | dropped: as designed, and a duplicate (hub ruling) |
| advisor | ADVISOR-DASHBOARD-B-010 | Bug | — | 2 | 0 | — | Reviewer PASS each loop; retries from parity (FAIL 13:32); waiting on verification |
| advisor | ADVISOR-DASHBOARD-B-009 | Bug | — | 0 | 0 | — | 14:08 start, review PASS 14:28, parity PASS 14:51; waiting on verification |
| log viewer | F-011 | Feature | — | 3 | 1 | — | Parity PASS on retry 1; 4 outside items found |
| log viewer | F-009 | Feature | — | 2 | 0 | — | design hold lifted (round 003); passed review; run paused before its 5 Finalizers |

Read of the snapshot:

1. **Review held.** First-review pass rate 78%, against 80% and 67%; no new escalation.
2. **Parity is still the main cost.** Every retry this period came from parity except F-004 and
   F-011, and half the finished UI items failed their first parity run. Snapshot 2's parity items
   (1–3) are still open; fixing them is the biggest lever left.
3. **Most items are waiting on people, not agents:** 6 of 9 sit at manual verification, Integration or
   close-out.
4. **Session limits hit all workers at once.** The pause was clean: every run state names the step to
   resume at.
5. **Sizing starts with the next runs** (2.20.x), so size against actual time is first measurable at
   the next snapshot.
6. **Data quality:** this snapshot was read from files because no session was online; times marked
   "est." come from run-state without a finish time.
