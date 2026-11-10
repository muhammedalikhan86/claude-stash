# Resuming a run

Read this only on a confirmed resume (Step 0.0's Resume check in SKILL.md, answered "resume"), or when
the user types "resume" at an escalation pause. A normal run never needs it. What run-state holds and
when it is saved stay in SKILL.md's **Run-State Checkpointing**; this file is the read-back half.
Phase 2's entry rule, the item statuses and the metrics rows referred to below are defined in SKILL.md.

## Where a resumed run rejoins

On explicit user confirmation, take the latest phase first and stop at the first match (a `dropped` item is skipped by every rule): run complete → nothing; an item with status `escalated` (or the
`integration` block with `escalated: true`) → **Resuming after an escalation** (below);
Phase 3 `done`, or nothing left unfinished and Phase 2's entry rule says Phase 2 is not owed → close-out; Phase 3 started → rejoin it at its recorded step;
Reviewer-Integration PASS recorded → Phase 3; Phase 2 started → its recorded step. Otherwise, Phase 1:
a verified P0 lane not `done` → its recorded step, and then resume **continues** with the rest of this
rule (it does not stop); a Spike with a Developer Output and no Spike Log → its Spike Log Finalizer (never
a Reviewer); a Bug `awaiting verification` → Step 1.5's gate posted again; items at their first gate with no recorded result; and once every Phase 1 item is terminal
(a Feature `passed review`, a Bug `verified`, a Spike `findings recorded`, or any item `dropped`; and no P0 lane unfinished) and Phase 2
has not started → Phase 2's entry rule (Phase 2, or close-out if Phase 2
is not owed).
A step found `started` (not `done`) re-runs from its start, all its Finalizers included; a re-run commit
step re-checks `git status` and obeys `decisions.commit` (`ask` → ask again). PMBook-sourced items re-derive
their Task Packet from the current PMBook, with the saved coding-conventions summary; persisted packets
are used as stored. `blockedGate` is read by the escalation resume, the gate it names respawned, and
only then cleared. Announce any `heldForNextRun` items. In a fresh
session, every scratchpad path in the file (saved packets, parity folders) is treated as gone: re-write
each packet to `<scratchpad>/runs/<run id>/packet-<ID>.md` before the next spawn, and re-run a Parity
Check rather than citing an old folder. Before any respawn, also re-write the saved Developer Output,
Issues list, Unable to Verify report and Integration Output to the scratchpad, so Previous Issues, a Report 2
Reviewer respawn, Integration's Retry Context and the Phase 2/3 inputs all have their source. Never
respawn the Developer just to regenerate an output that run-state holds.

## Resuming after an escalation

**Resuming after an escalation:** first set the item's status back to `in progress` (or clear the
`integration` block's `escalated` flag) and save run-state at once. A **Verification Blocked** escalation
(Report 2, the UNVERIFIED limit) reads run-state's `blockedGate` and respawns the gate it names — the
Reviewer, the Parity Check, or the Reviewer-Integration (during Divide-and-Conquer's confirmation pass,
that pass again) — then clears `blockedGate`; only `unverified_count` is reset to 0; `loop_count`, `priorLoops` and Previous
Issues stay as they were, and the Developer (or Integration agent) is NOT respawned. Every other escalation restarts the
item at `loop_count` 0 with the escalation's issues as Previous Issues (keeping any `verified by Step
1.3b, not by you` marks), and `priorLoops += 3`; respawn the Developer (for an
Integration escalation, the Integration agent). An Integration resume reads the `integration` block:
`divideAndConquer` other than `not run` means it never runs again in this batch. Either way, the item's next terminal state gets a
second metrics row, whose Final loop_count is this leg's count (see **Pipeline Telemetry**'s cell in SKILL.md; a
restart at `loop_count` 0 also sets `loopCountAtEscalation` to 0, so no loop is counted twice). If run-state lacks `app-url` or
`artboard-server` and a UI packet remains, ask again before Step 1.3b.
