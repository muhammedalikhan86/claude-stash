# Resuming a Run

Read by `plugin-orchestrator-development-pattern` only on a confirmed resume (Step 0.0's Resume check), or
when the user types "resume" at an escalation pause. A run that never pauses or crashes never reads it. What run-state holds, and when it is written, stays in `SKILL.md`'s
**Run-State Checkpointing**; this file is the read-back half. Step numbers are `SKILL.md`'s.

---

**Task bar first.** Before anything below, send the task list as `SKILL.md`'s **Task bar** says for a resume, so the user sees where the run stands.

**Resuming:** on explicit confirmation, read `references/templates.md` first — a resumed run never
reaches Phase 1's "read once, now" line. If a UI packet is unfinished and run-state lacks `app-url` or
`artboard-server`, look in the repo again, then ask, before Step 1.3b. Then rebuild the position from the file — PMBook items persisted by ID
re-derive their packets from the current PMBook and run-state's conventions summary; the rest use the
persisted packet. In a fresh session,
check every saved path in the file: work-dir paths survive a restart and are used as they are; a
scratchpad path (a run-state written before the work dir existed) is treated as gone. Re-write each
missing packet to `<work dir>/runs/<run id>/packet-<ID>.md` from run-state before any spawn, and each item's missing
latest Developer Output (`devout-<ID>[-legN][-retryN].md`), its last Issues list and its last Unable to
Verify report, and the latest
Integration Output there too (at its saved name, `integration-output-pass<N>.md`, the last of
`integration.outputPaths`) — Previous Issues, a Verification Blocked Reviewer respawn, Integration's
Retry Context and the Phase 2/3 inputs all read from them. A packet or output missing from both the work dir and run-state is read from the item's `parkedAt` folder; with no `parkedAt` either, re-derive the packet from the item's PMBook row and say so in the resume announcement.

**Where a resumed run rejoins.** Phase 0 is not re-run: print Step 0.0a's block, announce any
`heldForNextRun` items, then take the Platform Profile, waves and queue from the file. Take the first
match, latest phase first (run-state's `phase`: `closeout`, `phase3`, `phase2`, `phase1`, `ui-iteration`); a step found `started` (not `done`) re-runs from its start:
1. run complete → nothing to resume;
2. an item with status `escalated`, or the `integration` block with `escalated: true` → **Resuming
   after an escalation** (below);
3. `mode: ui-iteration` → `references/ui-iteration.md` §A long pause (before `doneAt`: ask; after it:
   rejoin the gates);
4. Phase 3 `done`, or nothing left unfinished and Phase 2's entry rule says Phase 2 is not owed →
   Step 3.6's close-out (this covers Spike-only and P0-only runs);
5. Phase 3 started → Phase 3 at its recorded step;
6. Reviewer-Integration PASS, or a recorded skip → Phase 3;
7. Phase 2 started → its recorded step, with the `integration` block's counters (Step 2.2's untracked
   known-red pause applies; the known-reds in `decisions.acceptedKnownReds`, documented-baseline ones
   included, are already ruled and never asked again). A re-run Integration step reuses Step 2.1's saved snapshot (a re-run doc-only retry
   reuses its own saved "before" snapshot) and is never a Reviewer-Integration skip candidate. A Divide-and-Conquer `running` re-runs the aggregate pass; `confirmation
   pass` respawns its Reviewer-Integration. Only a Divide-and-Conquer escalation means none runs again:
   a FAIL that takes loop_count past 3 then escalates at once (template 1);
8. a verified P0 whose lane is not `done` → the lane's recorded step (not started: the full lane);
   this one is not a first-match stop — once the lane is done, resume continues with 9–10 for the rest;
9. every Phase 1 item is terminal — a Feature `passed review`, a Bug `verified`, a Spike `findings
   recorded`, or `dropped`; a legacy item status `done` from an older run-state file counts as terminal — no P0 lane is unfinished, and Phase 2 not started → Phase 2's entry rule
   (Phase 2, or Step 3.6's close-out when Phase 2 is not owed);
10. otherwise each unfinished Phase 1 item (`in progress` or `awaiting verification`) rejoins at the
   first gate with no recorded result, with its saved `loop_count`, taking the first sub-rule that matches:
- `awaiting verification` → queue it for the batched Step 1.5 (post at once only if no item is still `in progress`);
- a UI packet with no Design Gate result → Step 1.1b;
- a Spike with a Developer Output and no Spike Log row → its Spike Log Finalizer (never a Reviewer);
- no recorded verdict for its current attempt → its Reviewer if that attempt's Developer Output is in
  run-state (re-written as above) or its file still exists; only when neither holds it, respawn its
  Developer (no `loop_count` change; the files already in the tree are its Previous Attempt);
- a code PASS on a UI packet with no Parity verdict → Step 1.3b.
A review-only item whose latest Developer Output is still its Build Record rejoins at its review (never
respawn a Developer for it); its first FAIL still costs no iteration. The saved `baseline.reds` (Step
0.4b) is reused, never re-run.
A re-run commit step obeys `decisions.commit` (`ask` or unset → ask again) and commits as Step 3.5
says: whatever of its saved file list `git status` still shows uncommitted. Other items already terminal stay as they are;
a `dropped` item is never rejoined (rules 2 and 10 skip it).

**Resuming after an escalation:** on "resume", set the item's status back to `in progress` (or
clear the `integration` block's `escalated` flag) and save run-state at once. The item restarts at `loop_count` 0 and `loopCountAtEscalation` 0
with the escalation's issues as Previous Issues (keeping any `verified by Step 1.3b, not by you` marks),
and `priorLoops` += its old `loop_count`; respawn its Developer (for an Integration escalation, the Integration Agent at Step 2.1).
**Verification Blocked** (template 2: the UNVERIFIED limit, or two missing Outputs) is different: respawn
the role run-state's `blockedGate` names, with its saved inputs, `unverified_count` reset to 0, and
`loop_count` and `priorLoops` unchanged. For `reviewer`, `parity` or `reviewer-integration`, that gate
runs on the Developer (or Integration) Output from run-state — no Developer respawn. For `developer`,
`integration` or `finalizer` (missing Outputs), that same spawn runs again with the same inputs — not a
retry, no `loop_count` change. Blocked during the `confirmation pass`, it resumes that pass's
Reviewer-Integration. Final loop_count follows `SKILL.md`'s **Pipeline Telemetry**, so no loop is
counted twice. A UI
Iteration resumes at its step 9 (the Orchestrator fixes, then the Reviewer; never a Developer) only
after a code-Reviewer FAIL escalation or a rejected Parity mismatch; its Integration and Verification
Blocked escalations resume as above. `blockedGate` is cleared only after this branch has read it and
respawned the gate (read, respawn, then clear). A "drop" or "defer" instead of "resume": see
`references/escalation.md`. Everything else rejoins as above.
