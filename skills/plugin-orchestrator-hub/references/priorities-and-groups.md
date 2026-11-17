# Priorities, issue triage and groups

## Order of work, per worker

1. New functionality (features).
2. Functional bugs.
3. The parity sweep (one per component, at the end).
4. UI-only bugs already raised as items (they ride the parity sweep).

Items another worker waits on go first, ahead of everything, and ship alone if needed.

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

A group is one orchestrator run: one Integration, one Finalise, one merge.

1. Before each new group, the worker sends the hub its proposed group plus its open queue, and waits.
2. The hub regroups: waited-on items first; fold in newly raised items (design-sync follow-ups, functional
   bugs) so groups are fewer and fuller; batch 1-2 point items into the current group as a parallel wave
   when their files don't overlap, even if their theme differs. No unrelated large feature rides along.
3. Size-8 items are split by their own worker, never by the hub.
4. **Check in with the user** before the group starts: one line per worker with the group, IDs and points,
   and a go button. Within `delegation`, a group that only reorders an already-approved queue needs no
   check-in.

## Worker picture

See `SKILL.md` §Talking to the user. Sizes come from each PMBook; unknown sizes show `??`.

## Parity sweep (end game)

When a component's feature and functional queue is empty:

1. Collect its `paths.parityBacklog` lines and its UI-only items.
2. Plan one group: every screen against its board, at the repo's parity viewports, fixing every gap
   above the tolerance. Use the `disparity-checker` skill if the repo has it.
3. When it is merged and green, tell the user the component is ready to test.
