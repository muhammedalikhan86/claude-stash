# UI Packets — Bindings, Design Rows Hold, Design Gate, Board Parity Check

Read by `plugin-orchestrator-development-pattern` when a planned packet touches a user interface (see the
trigger lines in `SKILL.md` at Step 0.4, Step 1.1b and Step 1.3b). Step numbers are `SKILL.md`'s.

---

## UI bindings (checked before Phase 1)

`app-url` — the app's address as a pattern with the port offset in it, e.g.
`http://localhost:{4200+offset}`, filled with **this checkout's** offset (from its stack config; never
assume 0); `artboard-server` — how the board is served; `parity-viewports` — layout widths to compare at
(default `1440`); `parity-command` — optional, the repo's checked-in parity harness, e.g.
`npx playwright test business-tests/layout/parity.spec.ts`; set, the Parity Check runs or extends it
instead of writing a script; unset, it looks for an existing parity or layout spec first. If `app-url` or `artboard-server` is missing when a UI packet is planned, **look in
the repo before asking**: the root `CLAUDE.md`, the project's run skill (`.claude/skills/run/`), the
stack config, and the README of whatever serves or tests against the boards (e.g.
`business-tests/README.md`). Read the same sources for a parity harness when `parity-command` is unset (a
parity or layout spec they name), and use one found the same way. If both are found there, use them, say where each came from in the Step 0.4
announcement, and offer once (in the end-of-run summary, not mid-run) to write them into
`.claude/SKILLS.md` so later runs read them directly. Only what the repo does not say is asked of the
user — once, before Phase 1. The Parity Check is never skipped for want of a URL. Keep the values in
`run-state-file`; a resume that finds them missing looks again, then asks, before Step 1.3b.

---

## Design rows hold (Step 0.4)

Runs before the plan is announced, when `artboards-directory` is set and a planned item changes what
a user sees. The design folder, its rows and rounds, and their rules are in `~/.claude/skills/sync-artboards/references/design-files.md` — read it first.
Only for boards an outside designer owns (the design README says so, or `design-source` is
bound); when the repo draws its own boards, skip this — the Design Gate settles them.

1. **Old layout.** If the artboards folder holds `review-<page>.md` ledgers and `design-rows-directory`
   is unset or empty, say so once, point to `~/.claude/skills/sync-artboards/references/migrate-design-layout.md`, and suggest the move — never make it. For this run,
   read the rows from those ledgers (same IDs; `Done, checked <date>` counts as Done) and write any new
   row into them, with the prompt at the end, as that repo already does.
2. **Find each UI item's rows:** the IDs its Acceptance Criteria name (`Design rows: …`), plus any row
   whose Source names the item.
3. **Any of them not `Done` → hold the item.** It leaves this run's queue, with every item that depends
   on it; the other items go on. Save it in run-state's `decisions.designHolds` (item, its open rows,
   their round and that round's status), and list it in the announcement under `Held for design:`. A held
   item is not escalated or dropped, and its PMBook row is not touched. The next run (or a resume after
   the user says the round is synced) checks it again.
4. **No rows, and the item needs a new or changed layout no board draws → write them.** Add the rows to
   the open round per `~/.claude/skills/sync-artboards/references/design-files.md` (next IDs for the screen's letter, Source the item and its criterion, Round
   `open`; a new round file if the last one was sent), rewrite the round's Summary and Detailed prompt,
   and hold the item as in 3. Show both texts, Summary first, and tell the user: send the round to the
   designer, then run `sync-artboards` when the designer is done. Do not mark the round sent.
5. **A change the Acceptance Criteria fully describe** (a label, a tooltip, a state of an existing
   control) does not hold: it goes on with the criteria as its spec (the Design Gate), and the drawing is owed —
   add it to `decisions.designRowsOwed` (Phase 3 **Design rows owed**).

Rows are read from this component's `design-rows-directory`; the round is the repo's shared open round.

---

## Data sources check (Step 0.4)

Runs before the plan is announced, for every planned item that changes what a user sees, whoever
draws the boards. A `Depends on:` item being done is not proof the data exists: check the read it delivered.

1. **List what the board shows.** For each UI item still in the queue, list every data field its board
   (or, with no board, its Acceptance Criteria) displays on the surfaces it touches: each column, value,
   count, badge, filter option and default.
2. **Name where each comes from:** the API endpoint and response field the screen reads, and behind it
   the database read (view, procedure or column). Read the code, and for a database query the server
   itself — never a schema copy; record the query in the packet (Shaw work:
   `~/.claude/skills/shaw-estate/references/databases-and-querying.md`).
3. **Every field has a source, or this item's own scope adds it** → write the list into the packet's
   `## Design Reference` as `Data sources:` (field → source, or `added by this item`). The Developer
   builds to it and the Reviewer checks it.
4. **A field with no source, outside this item's scope → ask before the plan is announced:**
   (a) widen this item to add the read (this component only); (b) add a `Depends on:` item that adds it in the component that owns the data (Linked Runs when they must land together); or
   (c) hold the item. Save the answer in run-state's `decisions.dataSourceGaps` (item, fields, ruling).
   A held item works like a design hold (§Design rows hold, item 3): it leaves this run's queue with every item that depends
   on it, its PMBook row is not touched, and the next run checks it again. Never let a Developer find
   the gap mid-build.

---

## Design Gate (Step 1.1b)

**Before the Developer is spawned, never after** — except a UI Iteration, where it runs once at "done"
(`references/ui-iteration.md`). Skip for packets that touch no user interface.

1. **Resolve the artboard** in `artboards-directory` (per component, as synced — never a copy elsewhere). If the binding is absent, say so and
   skip steps 1–4 only (there is no artboard to compare, update or author); steps 5–8 still run, and
   Step 1.3b compares against the Acceptance Criteria, its Parity Table header saying
   `Compared against: Acceptance Criteria — no artboards binding`.
2. **Compare it with the Acceptance Criteria.** If they agree, print
   `Design Gate: <artboard> already matches — no change` and go on.
3. **If they disagree, update the artboard first** — an **Artboard Edit Prompt** spawn
   (`references/templates.md`), its Target the packet's Acceptance Criteria. Record its Output's files in run-state: Step 3.5 stages them.
4. **Author one if none exists**, following the artboards folder's README — the same spawn as 3.

   **Designer-owned artboards are the exception to 3 and 4.** Read the artboards folder's README (and
   `.claude/SKILLS.md`) for who authors them. If an outside designer owns them — e.g. they are synced
   down from a design tool, so a repo edit is overwritten on the next sync — **never edit or author one**.
   Instead: if the surface is drawn and agrees, go on; if it is not drawn, or disagrees, and the change is
   small and fully described by the Acceptance Criteria (a label, a tooltip, a state of an existing
   control), print `Design Gate: <surface> not drawn — designer-owned; Acceptance Criteria are the spec`
   and go on. Step 1.3b then compares that surface against the
   Acceptance Criteria instead of a board, and its Parity Table header says
   `Compared against: Acceptance Criteria — <surface> not drawn`. The designer ask is owed: add it to
   run-state's `decisions.designRowsOwed` (`SKILL.md` Phase 3 **Design rows owed** writes it). A **new or
   changed layout** with no drawing halts the item until the designer has drawn it — the Design rows hold
   (Step 0.4) normally catches it first; one that slips through gets its rows written the same way.
5. **Name the component behind every surface** — each interactive or structural region as the Angular
   Material or CDK component that renders it (`mat-card`, `mat-table`, `matButton`, `cdkDropList`) — in
   the packet's `## Design Reference`. A control the board draws as plain HTML is named by the Material
   component that replaces it (Shaw work: `~/.claude/skills/shaw-estate/references/ui.md` §Design boards); the build
   never copies the drawn markup.
6. **A surface that cannot be a Material component halts the item.** Plain HTML beyond text, layout and
   landmarks needs the user's written sign-off in the project's UI contract first. Print
   `Design Gate: HALTED — <surface> has no Material component and no signed-off exception` and stop that
   item (other wave items continue). Only this point blocks.
7. **Say where each surface's styling comes from** — shared theme, existing class vocabulary, a new
   shared class (its own work item), or local CSS.
8. **Print the diff** before the Developer is spawned.

---

## Board Parity Check (Step 1.3b)

**Runs after the code Reviewer's PASS, before the Manual Verification Gate and Integration.** Skip only
for a packet with no `## Design Reference`.

1. **Bring up** this checkout's stack (the Platform Profile's `Stack` commands) and the board
   (`artboard-server`), and check both answer. Fill `app-url` with this checkout's port offset.
2. **Spawn** `subagent_type: "orchestrated-reviewer"`, `model: "sonnet"`, with the **Parity Prompt**
   (`references/templates.md`): the packet path (Step 1.1), the app URL, the board URL,
   `parity-viewports`, `parity-command` (or `None`), and the folder `<gate log directory>/parity/<ID>[-legN][-retryN]/` (`-legN` from the second leg on) — the gate log
   directory is `<work dir>/gate-logs/<run id>/`, fixed at Step 0.4. A separate spawn: the code
   Reviewer stays narrow.
3. **It measures** the elements this item changes, in every state in the packet's `States to compare`
   at every width in `parity-viewports`, running or extending the repo's parity harness when there is
   one, plus a quick pass that lists differences outside the item — per the Parity Prompt.
4. **It returns a Parity Table**, one row per element: `element | board | built | match | ruling`.
   Screenshots and measurements stay in the parity folder.
5. **Verdict.** Any mismatch not covered by a `Ruled deviations` line is a **FAIL**. The mismatches go
   back into Step 1.4's loop as the issues list, under the same 3-strike rule: a Developer retry, then
   the code Reviewer (to whom they are marked `verified by Step 1.3b, not by you`), then this check
   again. UNVERIFIED (the app or board would not load) follows
   **Handling an UNVERIFIED Verdict**. PASS → the item goes on as Step 1.4's "On `PASS`" says. A
   mismatch whose fix lies in another component's files (e.g. the shell's theme) takes Step 1.4's
   cross-component route, as a code FAIL would.
6. **Keep every run's Parity Table path** — PASS or FAIL, one per parity folder — in `run-state-file`,
   with that run's unruled-mismatch count beside it, and save it after the verdict. Step 1.5 attaches
   the latest, and the metrics row sums the counts (clearing: **Pipeline Telemetry**).
7. **Outside this item.** Differences the check returns under `Outside this item` are not mismatches:
   they do not touch the verdict, the issues list or the unruled-mismatch count, and no Developer
   retry fixes them. Check its sorting — a row whose element is rendered or styled by a file in the
   packet's `Files to Create or Modify` is this item's, and counts as an unruled mismatch. Save the rest
   in `run-state-file` under the item's `outsideItem` list, merged across retries (one entry per
   state + element). Phase 3 offers once, before its Finalizers run, to log them as new Bugs in this
   component's PMBook (`SKILL.md` **Outside items — asked before the Finalizers**); nothing is logged
   without the user's yes.
