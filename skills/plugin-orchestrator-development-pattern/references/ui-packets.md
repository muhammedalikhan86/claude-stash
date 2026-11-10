# UI Packets — Bindings, Design Gate, Board Parity Check

Read by `plugin-orchestrator-development-pattern` when a planned packet touches a user interface (see the
trigger lines in `SKILL.md` at Step 0.4, Step 1.1b and Step 1.3b). Step numbers are `SKILL.md`'s.

---

## UI bindings (checked before Phase 1)

`app-url` — the app's address as a pattern with the port offset in it, e.g.
`http://localhost:{4200+offset}`, filled with **this checkout's** offset (from its stack config; never
assume 0); `artboard-server` — how the board is served; `parity-viewports` — layout widths to compare at
(default `1440`). If `app-url` or `artboard-server` is missing when a UI packet is planned, ask the user
once before Phase 1 — the Parity Check is never skipped for want of a URL. Keep the answers in
`run-state-file`; a resume that finds them missing asks again before Step 1.3b.

---

## Design Gate (Step 1.1b)

**Before the Developer is spawned, never after** — except a UI Iteration, where it runs once at "done"
(`references/ui-iteration.md`). Skip for packets that touch no user interface.

1. **Resolve the artboard** in `artboards-directory` (per component). If the binding is absent, say so and
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
   control), print `Design Gate: <surface> not drawn — designer-owned; Acceptance Criteria are the spec`,
   tell the user a designer ask is owed, and go on. Step 1.3b then compares that surface against the
   Acceptance Criteria instead of a board, and its Parity Table header says
   `Compared against: Acceptance Criteria — <surface> not drawn`. A **new or changed layout** with no
   drawing halts the item until the designer has drawn it.
5. **Name the component behind every surface** — each interactive or structural region as the Angular
   Material or CDK component that renders it (`mat-card`, `mat-table`, `matButton`, `cdkDropList`) — in
   the packet's `## Design Reference`.
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
   `parity-viewports`, and the folder `<gate log directory>/parity/<ID>[-legN][-retryN]/` (`-legN` from the second leg on) — the gate log
   directory is `<scratchpad>/gate-logs/<run id>/`, fixed at Step 0.4. A separate spawn: the code
   Reviewer stays narrow.
3. **It measures** every state in the packet's `States to compare` at every width in
   `parity-viewports`, per the Parity Prompt.
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
