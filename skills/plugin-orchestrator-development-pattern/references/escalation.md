# Escalation and Divide-and-Conquer

Read by `plugin-orchestrator-development-pattern` only when a work item or Integration is about to
escalate to a human. All human pauses end with the same footer and the same rule: do not resume until
the user types "resume" or gives an explicit instruction.

Spike work items never reach any of this.

---

## Divide-and-Conquer — Last Attempt Before Escalation

Triggered only when Integration's loop_count is 3 and that escalated attempt **still** gets a
Reviewer-Integration `FAIL`. Runs at most once per run.

1. Split the remaining Issues into independent sub-problems along file/module boundaries. Errors that
   depend on each other stay together. If one root cause spans everything, skip straight to escalation —
   do not force a split.
2. Spawn one `orchestrated-integration` per sub-problem, in parallel (one message, several `Agent` calls),
   each at the Escalated Model and scoped to only its files and Issues. Each fixes only its sub-problem,
   self-verifies against the relevant subset of the gate, and never commits.
3. Aggregate: clean self-verification → "Resolved (Divide-and-Conquer)"; the rest → "Still Failing".
4. Re-run the gate once at the run's Test scope, then spawn Reviewer-Integration **once** against the
   aggregated result. This does not increment loop_count.
5. PASS → Finalization as normal. Otherwise escalate (template 3 below), scoped to what is still failing.

Resolved sub-problems are recorded in the Integration Output, never committed.

---

## Escalation Templates

Say which of the three situations it is.

**1. loop_count exceeds 3** (a real FAIL):

```
🚨 Human Intervention Required — Implementation

Step:        <COMPONENT-F-XXX — name>, <COMPONENT-B-XXX — title>, or "Integration"
Iterations:  3 (maximum reached)
Last model:  <Escalated setting from Model Assignment — already tried and still failed>

Unresolved issues (from last Reviewer or Reviewer-Integration):
<copy the last Issues list verbatim>

Last attempt summary:
<Developer / Integration Output summary from last loop>

Recommended actions:
- Review the issues above and make the required changes manually, OR
- Clarify or relax the acceptance criterion that cannot be met, then type "resume"

⏸ Orchestrator is PAUSED. Waiting for instruction.
```

**2. A Reviewer or Reviewer-Integration returns UNVERIFIED a third time in a row** — verification is
blocked, the implementation is not known to be wrong:

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

**3. Divide-and-Conquer's confirmation pass still fails:**

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

**Inside a wave** (Step 1.0): when one item escalates, let the other items in the wave finish the spawn
they are on and record their results, then pause. Never abandon a sibling mid-spawn.
