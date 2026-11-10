# Escalation and Divide-and-Conquer

Read by `orchestrator-development-pattern` only when a work item or Integration is about to escalate to
a human: a FAIL takes `loop_count` past 3, a Reviewer or Reviewer-Integration returns `UNVERIFIED` a third time
in a row, or the Reviewer-Integration `FAIL` that takes Integration's loop_count past 3 (which runs
Divide-and-Conquer first). Step numbers, **Model Assignment** and **Git Restrictions** below refer to
`SKILL.md`.

---

## Divide-and-Conquer — Last Attempt Before Escalation

Triggered only by the Reviewer-Integration `FAIL` that takes loop_count past 3 (the loop_count 3,
Escalated-Model attempt still failed) — the one point where the normal loop would otherwise go straight to human escalation.
A resolved sub-problem is recorded in the Integration Output, never committed: it stays uncommitted like
every other change until the user says "commit" (see **Git Restrictions**).

```
IF the Reviewer-Integration FAIL takes loop_count past 3 (loop_count == 3, stays 3):
  0. IF run-state's `integration.divideAndConquer` is not `not run` → ordinary escalation (Report 1); do not
     run it again.
  1. Classify the remaining Issues into independent sub-problems, split along file/module boundaries.
     Errors that depend on each other belong in the same sub-problem, not split apart.
     IF the failures are not genuinely separable (one root cause spans everything) →
       ordinary escalation with Report 1 (see **Escalation** below), leaving `divideAndConquer` at
       `not run` — do not force a split.
     Only once the split succeeds: set `divideAndConquer: running` and save run-state.

  2. Spawn one Integration sub-agent per sub-problem, in parallel — multiple `Agent` tool calls in a
     single message, each `subagent_type: "orchestrated-integration"`, `model:` the Escalated Model,
     with the Integration Agent Prompt (its `## Accepted Known-Reds` included) plus its `## Sub-problem`
     section filled: the failing tests in scope, the files it may touch, and "self-verify only this
     sub-problem; do not run the full suite".
     Each reports Resolved / Still Failing for its sub-problem. Save each Output verbatim as
     `integration-output-pass<N>-sub<K>.md` (`SKILL.md` Step 2.1; N is the aggregate pass's number).

  3. Aggregate: when every sub-problem spawn has returned, spawn ONE `orchestrated-integration`
     (`model: "opus"`) with the normal Integration Agent Prompt (its `## Accepted Known-Reds` included)
     plus its `## Aggregate pass` section — it
     re-runs the full gate at the run's Test scope and writes a complete Integration Output, saved as
     its own `integration-output-pass<N>.md`. Sub-problems
     still failing there stay "Still Failing," carried into the escalation report if step 5 is reached;
     the rest are "Resolved (Divide-and-Conquer)". Settle any `— untracked` known-red first (see
     **Known-reds** in SKILL.md).

  4. Set `divideAndConquer: confirmation pass`, save run-state, and spawn Reviewer-Integration ONCE more
     against that aggregate Integration Output, at loop_count 3's Escalated Model (`sonnet`). This single confirmation pass does not increment loop_count and is not
     itself a new retry cycle — it either resolves the run or feeds directly into step 5. An UNVERIFIED
     here follows **Handling an UNVERIFIED Verdict**, counted on Integration's own `unverified_count` and
     `unverifiedTotal` (the Integration metrics row's UNVERIFIED count); the spawn repeated is this
     confirmation pass.

  5. Set `divideAndConquer: done`. IF that confirmation PASSes → proceed to Finalization as a normal PASS.
     IF issues remain → ESCALATE (see **Escalation** below), but scope the report to only the still-
     failing sub-problems — the resolved ones are reported as already-fixed context, not re-opened.

  Divide-and-conquer runs at most once per work-item batch. If it doesn't fully resolve things, that is
  the final answer before human escalation — not another retry loop. Its stages are steps: on a resume
  after a crash (not an escalation), `running` re-runs the aggregate pass (step 3) and `confirmation
  pass` respawns the confirmation (step 4). Only an escalation means it never runs again.
```

---

## Escalation

Three distinct situations reach a human pause. All three use the same `⏸ Orchestrator is PAUSED. Waiting
for instruction.` footer and the same rule: the Orchestrator does not resume until the user types "resume"
or gives an explicit instruction. They differ in what's actually broken, so say which one it is.

**Before posting any of them:** first save `run-state-file` without marking it complete — the event time,
the item's status `escalated` (for Integration, `escalated: true` in the `integration` block),
`escalationFinalLoopCount` (the row's Final loop_count: `loop_count` minus the old
`loopCountAtEscalation`, computed before this save overwrites it, 0 when never escalated, so a re-run
writes the same value), `loopCountAtEscalation` (the item's, or the `integration` block's), and both the
last Issues list and the last Unable to Verify report. Then append the item's `metrics-log-file` row
(terminal state `Escalated`; for Integration, the Integration row; Final loop_count from the saved
`escalationFinalLoopCount`) plus a `RUN` row with Verdict `Paused (escalation)`. On "resume", set the status back to `in progress` (clear the block's flag),
save at once, and follow **Resuming after an escalation** in `references/resume.md`.
If the user instead explicitly says to "drop" or "defer" the item, set its status `dropped`, saved at
once with the event time: it is terminal, excluded from Phase 2's entry rule and from the resume rules,
and listed in the 🏁 summary. Write its one metrics row then, Verdict `Dropped`, Timestamp that saved
event time; close-out's "a row for each item" rule counts it.

**Spike work items never reach any of these three.** There is no retry loop, no Reviewer, and no Manual
Verification Gate in Spike Flow to fail or stall in the first place — see Spike Flow
(`references/spike-and-p0.md`) on this being a deliberate, accepted risk, not a gap.

**1. A FAIL takes `loop_count` past 3 for any feature or integration step** (a real FAIL, not a verification
failure; Integration: only after Divide-and-Conquer, or when its failures can't be split):

```
🚨 Human Intervention Required — Implementation

Step:        <F-XXX — feature name>, <B-XXX — bug title>, or "Integration"
Iterations:  3 (maximum reached)
Last model:  <Escalated Model from Model Assignment — already tried and still failed: the loop_count 3
             attempt always runs on it, whether reached by a Reviewer FAIL, a Parity FAIL or a
             Manual Verification rejection>

Unresolved issues (from last Reviewer or Reviewer-Integration):
<copy the last Issues list verbatim>

Last attempt summary:
<Developer / Integration Output summary from last loop; for Integration, also its saved file path
(`integration-output-pass<N>.md`)>

Recommended actions:
- Review the issues above and make the required changes manually, OR
- Clarify or relax the acceptance criterion that cannot be met, then type "resume"

⏸ Orchestrator is PAUSED. Waiting for instruction.
```

**2. A Reviewer or Reviewer-Integration spawn returns `UNVERIFIED` more than twice in a row, or any
spawn returns no Output twice in a row** (see **Handling an UNVERIFIED Verdict** and **A spawn that
returns no Output** in SKILL.md, under Step 1.3b) — this means verification itself is blocked, not that
the implementation is wrong. For missing Outputs, replace the `Consecutive UNVERIFIED` and `Unable to
Verify` lines with `Missing Outputs: 2 (<role>)` and what the spawn last said, and save `blockedGate` as
that role (`developer`, `integration` or `finalizer` besides the three below); resume respawns that role
with the same inputs:

```
🚨 Human Intervention Required — Verification Blocked

Step:        <F-XXX / B-XXX / "Integration">
Consecutive UNVERIFIED results: 3

Last "Unable to Verify" report:
<copy verbatim>

This is NOT a claim that the implementation is broken — the Reviewer could not complete verification at
all. Recommended actions:
- Resolve whatever the Unable to Verify report points at (missing file, unreadable Task Packet reference,
  broken execution environment), then type "resume", OR
- Verify this item manually yourself

⏸ Orchestrator is PAUSED. Waiting for instruction.
```

On "resume", this one respawns the role `blockedGate` names, with the same saved inputs and
`unverified_count` reset to 0: for UNVERIFIED, the blocked Reviewer, Parity Check or Reviewer-Integration
— never the Developer or Integration agent; for missing Outputs, that role itself (Developer, Integration
agent or Finalizer). `blockedGate` is cleared only after that respawn. Before posting it, save
`blockedGate: reviewer | parity | reviewer-integration | developer | integration | finalizer` in
run-state (see **Resuming after an escalation** in `references/resume.md`).

**3. Divide-and-Conquer's confirmation pass still fails** (see **Divide-and-Conquer** above) — scope the
report to only what's still broken; resolved sub-problems are context, not part of the ask:

```
🚨 Human Intervention Required — Integration (after Divide-and-Conquer)

Resolved sub-problems (context, already fixed, uncommitted): <list>
Still-failing sub-problems: <list>

Unresolved issues (from the final Reviewer-Integration confirmation pass):
<copy verbatim, scoped to the still-failing sub-problems>

Recommended actions:
- Review the still-failing sub-problems above and make the required changes manually, OR
- Clarify or relax the acceptance criterion that cannot be met, then type "resume"

⏸ Orchestrator is PAUSED. Waiting for instruction.
```
