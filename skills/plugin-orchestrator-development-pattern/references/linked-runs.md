# Linked Runs and the Cross-Component FAIL

Read by `plugin-orchestrator-development-pattern` when work items in different components are linked by
`Depends on:` and must land together, or when a Reviewer FAIL lies in another component's files (see the
trigger lines in `SKILL.md` at Step 0.0a and Step 1.4). Step numbers are `SKILL.md`'s.

---

## Linked Runs

Two components' items are linked when one cannot pass Integration without the other — typically a
plugin change that breaks a test or contract the shell owns. They run in one orchestration:

- **Each item keeps its own component:** its own confirmation block, packet, `run-state-file` (one
  per component, all with the **same run id**, each naming the other components under `linkedRuns`),
  docs and graph. On resume, finding any incomplete run-state file resumes every file with that run id. The Diff Guard checks each file against the
  component of the item that changed it.
- **Phase 1** runs per item as normal; the dependency orders them (the depended-on item first, or in
  parallel when their files are disjoint).
- **Step 1.5** is one batched message covering every linked run's Bugs.
- **Phase 2 runs once, combined**, at `Test scope: full`, over the whole tree. Its Integration metrics
  row goes into each component's `metrics-log-file`, the Verdict noting `linked with <other component>`.
- **Phase 3** spawns each component's Finalizers (Step 3.1–3.4, as apply), all in one message — their
  files are disjoint.
- **Commits:** one per component; the depended-on component's is made first.
- **Close-out (Step 3.6):** the RUN row goes into each linked component's `metrics-log-file`, and every
  run-state file with this run id is marked complete.

**Not every `Depends on:` is a Linked Run.** When one side degrades gracefully without the other — it
passes its own Integration and works, only less, until the other lands — run them as **separate runs
linked by `Depends on:`**, not as Linked Runs: either side can land first. A request raised into this
component by another component's run (its `Depends on:`) is a mid-run intake like any other: queued, or,
once Phase 2 has started, held in `decisions.heldForNextRun` — the PMBook Finalizer may raise its row now
so the other run can cite the ID.

**An end-to-end check that waits on another item** is carried in the depended-on item's Acceptance
Criteria — the item that lands last proves the whole path. It is never parked as Deferred Integration,
which stays a P0 fast-lane mechanism only.

---

## FAIL — cross-component dependency (Step 1.4)

When every FAIL issue lies in a file the Developer may not touch — another component's roots (for
example a test the shell owns that the plugin change breaks; the Reviewer tags these
`[cross-component: <owner>]`) — a Developer retry cannot fix it and would only burn strikes. Then: do
**not** retry and do **not** increment `loop_count`. Pause the item, tell the user, and with their OK
raise a linked item in the owning component's PMBook (`Depends on:` both ways). Run the two as **Linked
Runs** (above). Once the linked item has passed Review, respawn this item's Reviewer against the current
tree — that respawn does not increment `loop_count` either. If only some issues lie elsewhere, retry the
rest as normal and ask the same question alongside; raising the linked item always needs the user's OK.

**The user declines to raise it.** The item escalates (template 1 in `references/escalation.md`, at its
current `loop_count`), its report naming the cross-component dependency: each issue, the owning
component and the files. With only some issues elsewhere, the escalation waits for the retry already in
flight to return.

A **Diff Guard FAIL** at Step 2.1 takes this same route: the files in another component's roots go to a
linked item there, and Step 2.1 re-runs once it passes Review.

**A Linked Run added mid-run.** Before the new item's first spawn, run for its component Step 0.0
(hard dependencies, plus its **Resume check** and **Held intakes** rule — an incomplete run-state file
there is resumed or set aside, and its held items announced, before this run writes that component's
file), Step 0.0a's confirmation block, Step 0.2 (its Platform Profile and test command),
Step 0.3 (conventions) and Step 0.3b (its specialist skill). It keeps this run's run id: write
its own run-state file with that run id, and name it under `linkedRuns` in every linked file. The path
of the PMBook the Orchestrator raised the linked item in is appended to `orchestratorFiles`.

**A FAIL in a sibling already linked in this run** is not a new item. It counts as a FAIL for that
sibling: its `loop_count` + 1, and its Developer respawns with the issues as Previous Issues. Once the
sibling passes Review again, respawn the originating item's Reviewer, with no `loop_count` change.
