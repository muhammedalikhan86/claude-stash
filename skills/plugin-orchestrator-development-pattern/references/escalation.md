# Escalation and Divide-and-Conquer

Read by `plugin-orchestrator-development-pattern` only when a work item or Integration is about to
escalate to a human. All human pauses end with the same footer and the same rule: do not resume until
the user types "resume" or gives an explicit instruction.

Spike work items never reach any of this.

---

## Divide-and-Conquer — Last Attempt Before Escalation

Triggered only by the Reviewer-Integration `FAIL` that takes Integration's loop_count past 3 (the
escalated loop_count 3 attempt **still** fails). Set run-state's `integration.divideAndConquer` to
`running` only once step 1's split succeeds, `confirmation pass` at step 4, and `done` when step 5
decides or it escalates. A "not splittable" escalation at step 1 leaves it `not run`. Its stages are
steps: a crash (not an escalation) during `running` re-runs the aggregate pass (step 4); during
`confirmation pass`, respawn that pass's Reviewer-Integration. Only an escalation ends it for the run:
once it is `done`, a FAIL that takes loop_count past 3 escalates at once with template 1 (`Step: Integration`).

1. Split the remaining Issues into independent sub-problems along file/module boundaries. Errors that
   depend on each other stay together. If one root cause spans everything, do not force a split:
   escalate at once with template 1 below (`Step: Integration`, the loop_count 3 Reviewer-Integration
   issues), adding the line `Divide-and-Conquer: not applicable — one root cause spans every issue`.
   The Integration metrics row's `Divide-and-Conquer triggered?` is then `No (one root cause)`.
2. Spawn one `orchestrated-integration` per sub-problem, in parallel (one message, several `Agent` calls),
   each at the Escalated Model (`opus`), with the Integration Agent Prompt plus its `## Sub-problem`
   section (`references/templates.md`): the failing tests in scope and the files it may touch, and the
   run's `## Accepted Known-Reds`. Each fixes
   only its sub-problem, self-verifies only that, and never commits. Save each Output verbatim as
   `integration-output-pass<N>-sub<K>.md` (`SKILL.md` Step 2.1; N is the aggregate pass's number).
3. Sort the results: clean self-verification → "Resolved (Divide-and-Conquer)"; the rest → "Still
   Failing". If any is Still Failing, skip to escalation (template 3 below).
4. **Aggregate pass.** Spawn **one** `orchestrated-integration` (`opus`) with the normal Integration Agent
   Prompt plus `## Aggregate pass` and the run's `## Accepted Known-Reds`: it re-runs the full gate at the
   run's Test scope and writes a complete Integration Output, saved as its own
   `integration-output-pass<N>.md`. Then (after Step 2.2's untracked known-red
   pause, if needed) spawn Reviewer-Integration **once** against that Output, `model: "opus"`, Retry
   kind `Normal retry` at loop_count 3 with the loop_count 3 issues as Previous Issues (run-state keeps
   them beside any later Unable to Verify report). Neither spawn
   increments loop_count.
5. PASS → Finalization as normal. Otherwise escalate (template 3 below), scoped to what is still failing.

Resolved sub-problems are recorded in the Integration Output, never committed.

---

## At the moment of escalation

Before printing any template below: first save `run-state-file` — the escalation's event time, status
`escalated` (for Integration, the `integration` block's `escalated: true`), both the last Issues list and the last
Unable to Verify report, `loop_count`, the row's Final loop_count (`SKILL.md` **Pipeline Telemetry**, using
`loopCountAtEscalation` from before this escalation), then `loopCountAtEscalation` = that `loop_count`, the latest Developer or Integration Output, and for template 2 `blockedGate:
reviewer | parity | reviewer-integration | developer | integration | finalizer`; then append the item's (or Integration's) `metrics-log-file` row with
terminal state `escalated`, Escalated? `Yes`, that saved event time as Timestamp and the saved Final
loop_count (write-once, **Pipeline Telemetry**). Step 3.6 lines 1 and 2 then run for the pause: the rows so
far plus a RUN row `Paused (escalation)`, and the saved state, **not** marked complete (so Step 0.0's
resume check still finds it). On "resume" (a Verification Blocked pause included), follow **Resuming
after an escalation** in `references/resume.md`. When the resumed run finishes, it appends a second RUN
row `Complete`.

**Park the item** in the same save, before printing: copy its packet, its latest Developer Output (for Integration, the latest Integration Output) and its last Issues list and Unable to Verify report from the scratchpad to `<folder of run-state-file>/.orchestrator-work/<ID>/` (Integration: `.../integration/`), and record that folder as the item's `parkedAt`. The scratchpad does not outlive the session; this folder does, and it is gitignored with run-state. A resumed item that reaches a terminal state has its folder deleted at close-out.

**"Drop" or "defer" instead of "resume":** set the item's status to `dropped` and save run-state at
once, with the drop's event time; then append the item's one `metrics-log-file` row, Verdict `Dropped`,
Timestamp that saved event time (`SKILL.md` **Pipeline Telemetry**; Step 3.6 line 1 counts it and does
not write it again). `dropped` is terminal: the item never resumes, Phase 2's entry rule leaves it out, the run carries
on with the rest, and the 🏁 summary lists it under `Dropped`.

---

## Escalation Templates

Say which of the three situations it is.

**1. The FAIL that takes loop_count past 3** (a real FAIL; `loop_count` stays 3) — also used, at the current `loop_count`, when the user
declines a cross-component linked item (`references/linked-runs.md`) and when Divide-and-Conquer does
not apply (above):

```
🚨 Human Intervention Required — Implementation

Step:        <COMPONENT-F-XXX — name>, <COMPONENT-B-XXX — title>, or "Integration"
Iterations:  <loop_count — 3 when the maximum was reached>
Last model:  <Escalated setting from Model Assignment — already tried and still failed>

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

**2. A Reviewer or Reviewer-Integration returns UNVERIFIED a third time in a row, or any spawn returns no
Output twice in a row** (`SKILL.md`, **A spawn that returns no Output**) — verification is blocked, the
implementation is not known to be wrong. For missing Outputs, replace the `Consecutive UNVERIFIED` and
`Unable to Verify` lines with `Missing Outputs: 2 (<role>)` and what the spawn last said, and save
`blockedGate` as that role (`developer`, `integration` or `finalizer` besides the three gate values):

```
🚨 Human Intervention Required — Verification Blocked

Step:        <COMPONENT-F-XXX / COMPONENT-B-XXX / "Integration">
Consecutive UNVERIFIED results: 3

Last "Unable to Verify" report:
<copy verbatim>

This is NOT a claim that the implementation is broken — the Reviewer could not complete verification at
all. Recommended actions:
- Resolve whatever the Unable to Verify report points at, then type "resume", OR
- Verify this item manually yourself

⏸ Orchestrator is PAUSED. Waiting for instruction.
```

**3. Divide-and-Conquer leaves a sub-problem failing, or its aggregate pass still fails:**

```
🚨 Human Intervention Required — Integration (after Divide-and-Conquer)

Resolved sub-problems (context, already fixed, uncommitted): <list>
Still-failing sub-problems: <list>

Unresolved issues (from the sub-problem reports, or the aggregate pass's Reviewer-Integration):
<copy verbatim, scoped to the still-failing sub-problems>

Recommended actions:
- Review the still-failing sub-problems above and make the required changes manually, OR
- Clarify or relax the acceptance criterion that cannot be met, then type "resume"

⏸ Orchestrator is PAUSED. Waiting for instruction.
```

**Inside a wave** (Step 1.0): when one item escalates, let the other items in the wave finish the spawn
they are on and record their results, then pause. Never abandon a sibling mid-spawn.
