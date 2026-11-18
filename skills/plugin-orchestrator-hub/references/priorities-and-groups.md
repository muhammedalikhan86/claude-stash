# Priorities, issue triage and groups

## Order of work, per worker

Set by the user. The hub applies it itself and never asks the user to order or approve groups.

**First, related items and dependencies.** Work another item or worker waits on goes first, ahead of
everything, and ships alone if needed. Items that depend on each other or touch the same feature or
files share a group.

**Within that, a fixed order:**

1. New functionality (features).
2. Functional bugs.
3. The disparity check: strict, after **every** group merges (§After-group disparity check), plus one
   final parity sweep per component before "ready to test" (§Parity sweep).
4. UI bug fixes: the look findings, UI-only items and parity-backlog lines the disparity checks leave.
5. Anything else: housekeeping (doc sweeps, refactors, tooling, clean-up).

## Issue triage (any issue a worker finds mid-build)

A worker brings every issue it finds to the hub **before** raising or taking it on. The hub rules:

| The issue is | Ruling |
|---|---|
| **Functional**: broken behaviour, wrong words, a missing part (field, control, tool), cut or unreadable content, accessibility | Raise an item in the owning component; it **jumps ahead of queued features** |
| **UI-only**: px offsets, greys, sizes, spacing | One line in `paths.parityBacklog` for that component. **No item** |
| A gap of `triage.tolerancePx` (2px) or less, or a near-identical colour | **Not recorded at all** |
| In another component | Route it to that component's worker (below) |
| A design question (the board is silent or wrong) | A design row (`references/designer-loop.md`) |

Record the ruling in the rulings log only when it sets a new rule, not for each issue.

## Cross-worker dependencies

1. Send the item to the component that owns the files, with what is needed and who waits.
2. The owner raises it and replies with the ID; pass the ID back to the waiting worker, which tags its
   blocked work with it.
3. The owner ships it first and alone. When it lands on main, tell the waiting worker to pull main and
   carry on.

## Group planning

A group is one orchestrator run: one Integration, one Finalise, one merge. **Why groups:** the
Integration gate, the Finalizers (PMBook, handoff, changelog, runbook, graph) and the merge cost about
the same for one item as for five, so finalizing item by item spends that cost again for every item.
Group as much related work as the files allow; a single item runs alone only when it is urgent (another
worker waits on it, a P0, a red after merge).

1. Before each new group, the worker sends the hub its proposed group plus its open queue, and waits.
2. The hub regroups: waited-on items first, related items together (§Order of work); fold in newly raised items (design-sync follow-ups, functional
   bugs) so groups are fewer and fuller; batch 1-2 point items into the current group as a parallel wave
   when their files don't overlap, even if their theme differs. No unrelated large feature rides along.
3. Size-8 items are split by their own worker, never by the hub.
3a. **A one-item proposal** is regrouped with the rest of that worker's queue. Send it alone only when
   it is urgent (above) or the queue holds nothing else that fits; say which in the go.
4. **The hub gives the go itself.** Grouping is the hub's call, not the user's: regroup by §Order of work
   and the rules above, reply to the worker with the group and "go". Tell the user nothing, or one ⚪ FYI
   line when a group starts. The user sees groups in the worker picture on request, and can reorder there.

## Worker picture

See `SKILL.md` §Talking to the user. Sizes come from each PMBook; unknown sizes show `??`.

## After-group disparity check (every group)

The workers' per-item Board Parity check is lenient (`triage.workerParityTolerancePx`, 20px); this check
is the **strict** one (`triage.tolerancePx`, 2px) and its safety net. It runs after **every** group
merges, not only at the end.

1. **When:** right after a group's merge (`references/merging.md` step 9), for that group's component.
2. **Who:** a background helper (Guardrail 6), briefed with this section, the guardrails and exact paths.
   It brings up the hub checkout's stack on the hub checkout's port offset, runs the `disparity-checker`
   skill for that component at 2px (the screens the group touched first, then the component's other
   screens), and stops what it started. The worker keeps going on its next group meanwhile.
3. **The findings file** lands in the component's findings directory in the hub checkout. The hub commits
   it by path and moves main up. Nothing found → no file; one ⚪ FYI line at most.
4. **Back to the worker:** "pull main, then run Findings Intake on `<path>` at your next group boundary".
   Its Findings Intake turns each finding into a PMBook row: **functional** gaps become functional bugs
   and go ahead of queued features (order step 2); **look** gaps join the UI bug fixes (order step 4). A
   parity-backlog line the intake now covers is struck, so nothing is fixed twice.
5. The hub regroups that worker's queue with the new rows (§Group planning) and gives the go as usual.

## Parity sweep (final pass)

When a component's feature and functional queue is empty, one final full pass before "ready to test":

1. **Disparity check** (order step 3): every screen against its board, at the repo's parity viewports,
   strict at `triage.tolerancePx` (2px), with the `disparity-checker` skill if the repo has it. The
   after-group checks have caught most gaps already; this one confirms the whole component. A
   functional gap it finds is a functional bug and goes ahead of the UI fixes.
2. **UI bug fixes** (order step 4): the check's UI gaps above the tolerance, plus the component's
   `paths.parityBacklog` lines and UI-only items, in as few groups as the files allow.
3. When those are merged and green, tell the user the component is ready to test. Housekeeping
   (order step 5) follows and does not hold up the ready-to-test call.
