# UI Iteration Mode

Read by `plugin-orchestrator-development-pattern` only when a UI Iteration is opened (Step 0.1d) or
resumed. It is a named exception to specific steps, not a parallel pipeline: the gates are held back
while the user iterates, and run **once**, over the whole change, when the user says **"done"**.

**Who makes each tweak.** The Orchestrator edits the code itself, with no Developer and no Reviewer per
tweak. This is the one named exception to "NEVER write code as the Orchestrator". The gates are not
dropped; they move to "done".

---

## Step 0.1d — Open the iteration (alternate entry point)

**Triggers.** An explicit ask — "let me iterate on the UI", "UI iteration", "tweak mode", "I want to
tweak <screen>". Also, once this skill is sticky in the conversation, a plain look-and-feel ask ("make
that button smaller", "more space under the title") opens an iteration instead of a Bug Fix Intake. A
look-and-feel ask is never a bug.

1. **Resolve the component** (Step 0.0a) from the screen the user names. Print the confirmation block.
2. **Run Step 0.0 lightly**: the hard dependencies must exist, and its **Resume check** and **Held
   intakes** rule run (an incomplete run is resumed or set aside before this one writes run-state).
   Held intakes are announced but never queued or mixed into the iteration. Skip the Test Cases Doc check until "done".
3. **Detect Format and Lint** (Step 0.2) for this component. Skip the rest of Phase 0 until "done".
4. **Check the stack.** Run the Platform Profile's `Stack` check. If it is down, offer to bring it up, so
   the user sees each tweak live. Never run a production build while the stack is up.
5. **Write `run-state-file`** (after step 2's Resume check and Held intakes) with a run id (SKILL.md's
   format and uniqueness rule, `ui` in place of the first item id), `"complete": false`, `"mode": "ui-iteration"`, the component, `openedAt` (ISO date-time with
   the zone), an empty `tweaks` list and any held intakes copied unchanged into
   `decisions.heldForNextRun`.
6. **Announce in one line:**
   `UI Iteration — <component> — tell me each change; say "done" when you're happy.`

No work-item ID is taken yet. It is taken at "done", so a long iteration cannot collide with an ID
another session takes meanwhile.

## The tweak loop

For each ask:

1. **Is it a tweak?** A tweak changes only how something existing looks or reads:
   - size, spacing, alignment, order;
   - colour, typography, elevation;
   - an icon, a label or other on-screen text;
   - showing or hiding an existing element;
   - a Material variant (e.g. a stroked button instead of a flat one).

   Anything else is **not a tweak**: new behaviour, new data, an API change, a new control, a new screen
   or a new layout. Say so in one line, and offer to end the iteration and take it as a Feature or Bug.
   Never slip it in.
2. **Stay inside the component.** Edit only this component's `code` roots. If a tweak needs another
   component's files, say so and stop that tweak: it becomes a linked work item (see
   `references/linked-runs.md`), not part of this iteration. If it needs a file outside every
   component's roots (e.g. a shared library), say so: that ends the iteration, and the ask becomes a
   Feature or Bug item, not a linked item.
3. **Follow the UI contract.** Use Angular Material or CDK components. Never hand-build a control that
   Material has. Style in this order: the shared theme, then the existing class vocabulary, then a new
   shared class, then local CSS. If a tweak would need plain HTML beyond text, layout and landmarks,
   stop: that needs the written sign-off the project's UI contract names.
4. **Make the edit**, then run the scoped Format and Lint on the touched files. Run no tests and spawn no
   agent.
5. **Log it** in `run-state-file` under `tweaks`, with:
   - the number;
   - the user's ask, in their words;
   - the files touched;
   - the time.
6. **Reply in one or two lines**: what changed, in which file, and where to look on screen.

**Undo.** "Undo that" reverses the Orchestrator's own last tweak, by editing it back. Never use
`git checkout`, `git restore`, `git stash` or `git reset`: other sessions may share the tree.

**Abandon.** "Stop iterating" or "cancel" ends the iteration with nothing committed. The edits stay in
the working tree, and the Orchestrator lists their files. The user decides what happens to them.
Mark `run-state-file` complete, so no later Resume check finds it.

**A long pause.** If the conversation ends mid-iteration, the run-state file carries the tweak log. On
resume:
- **No `doneAt`** → ask: "Found an open UI iteration on `<component>` with `<N>` tweaks — keep
  iterating, or call done?"
- **`doneAt` set** → rejoin the "done" steps below at the recorded step (one found `started` re-runs), as
  `references/resume.md`'s **Where a resumed run rejoins** says.
- **Paused on a code-Reviewer FAIL escalation, or a rejected Parity mismatch** → back to step 9: the
  Orchestrator fixes the issues, then the Reviewer. Never a Developer. An Integration or Verification
  Blocked escalation resumes as `references/resume.md`'s **Resuming after an escalation** says.

## "done" — run the gates once

On "done", "I'm happy" or "that's it", record `doneAt` (ISO date-time with the zone) in
`run-state-file`, then:

1. **Read back the tweak list** in one numbered block.
2. **Finish Phase 0.** Run what was held back at opening: the rest of Step 0.2 (the component test
   command and the `Stack` line), Step 0.3b's specialist skill, and Step 0.0's Test Cases Doc check. All
   of it before Integration.
3. **Fix the file set.** Run `git status --porcelain`. The iteration's **file set** is the tweak log's
   files, plus the artboard files step 5 edits, the assertion files step 6 updates and the files step 9's
   fixes touch, each added as it happens. A file from step 6 or 9 outside every component's roots
   carries a one-line justification into Step 2.1's `Out-of-root files`. Any other changed path belongs
   to another session: list it as `not this run's` and keep it out of this item. The Diff Guard (Step 2.1) and the Reviewer both use this file set.
   Save the file set, the `not this run's` list and (from step 8) the stand-in Developer Output to
   `run-state-file` at each step's start and end, like every other step.
4. **Take the work-item ID.** If the user named an existing item, use it. Otherwise take the next
   `<COMPONENT>-F-NNN` from the PMBook: its "next ID" line wins, else the highest plus one. Type
   `Feature`, with the mode recorded as `UI Iteration`. The run id stays the one written at opening;
   its scratchpad folders follow it, as Step 0.4 says.
5. **Settle the design (the Design Gate, run once, after).** The user approved each tweak on the live
   screen, so here the artboard catches up with the code. This is the one case where the gate runs after
   the code.
   - Designer-owned artboards: never edit them. Write one designer ask listing every tweak, ready to
     paste, and tell the user it is owed.
   - Repo-owned artboards: an **Artboard Edit Prompt** spawn (`references/templates.md`), its Target
     the numbered tweak list. The
     files it changes join the file set as this run's design edits.
   - Either way, name the Material or CDK component behind each touched surface in the packet's
     `## Design Reference`.
6. **Bring stale assertions up to date.** Search the component's specs, E2E tests and business tests
   for each changed label, class or text. Update an assertion the tweaks made stale to the approved look,
   and list each one (one outside every component's roots with its one-line justification, step 3). A
   tweak needs no new test, because it adds no behaviour.
7. **Build one Task Packet** in the Feature shape (`references/templates.md`). Fill it like this:
   - `## Description`: "UI Iteration — <N> tweaks to <screen>".
   - `## Acceptance Criteria`: one checkable statement per tweak, in the order made.
   - `## Files to Create or Modify`: the file set — the tweak log's files, plus any artboard edits
     from 5 and assertion files from 6 (step 9 adds its fix files here).

   Save it as Step 1.1 says.
8. **One Reviewer** (`orchestrated-reviewer`, `sonnet`) over the whole change. There is no Developer
   Output: write the tweak log (number, ask, files), the artboard edits from 5 and the assertion files
   from 6 to `<scratchpad>/runs/<run id>/devout-<ID>[-legN][-retryN].md` and pass that path in its
   place. Add these to the Reviewer prompt, with step 3's `not this run's` list:
   - "This change was made in UI Iteration mode: the Orchestrator edited the code directly, and the
     user approved each tweak on screen. Check every Acceptance Criterion in the diff."
   - "Check that nothing outside the packet's Files to Create or Modify changed. The paths listed as
     `not this run's` belong to other sessions: never FAIL on them. The artboard edits listed are this
     run's design edits."
   - "Check the UI contract: Material components and the styling order."
   - "Check that every updated assertion matches a tweak."
   - "Do not re-litigate the look itself."
9. **On a FAIL, the Orchestrator fixes the issues itself**, adds any new file it touched to the file
   set (the packet's Files to Create or Modify and the stand-in Developer Output; one outside every
   component's roots with its one-line justification, step 3), then respawns the Reviewer. `loop_count`
   counts as in Step 1.4, and at loop_count 3 the Reviewer is `opus`. The FAIL that takes loop_count
   past 3 escalates; its resume comes back to this step. If a fix would
   change the look the user approved, ask the user first.
10. **Board Parity Check, once** (Step 1.3b, `references/ui-packets.md`), after the Reviewer's PASS. The
    user already approved the look, so show them each unruled mismatch and let them rule: one they
    accept becomes a `Ruled deviations` line (`user ruling, <date>`) in the packet; one they reject is a
    FAIL handled as in 9.
11. **Then the normal pipeline, once**: Phase 2 Integration (Step 2.0 decides the scope), Phase 3's
    Finalizers, Step 3.5's commit and Step 3.6's close-out. Skip the Manual Verification Gate: the user
    already saw it live. The PMBook Finalizer adds the item's row already `Done`, with the tweak list as
    its criteria.

## Telemetry

One metrics row for the item: `Type: Feature (UI Iteration)`, Started = `openedAt`, Finished = the
Parity PASS (or the Reviewer's PASS when there is no `## Design Reference`). Its Timestamp is the event
time saved in run-state before the row is written (write-once, `SKILL.md` **Pipeline Telemetry**). Put the number of tweaks
in the Verdict. In the RUN row's `Phase times`, `P1` is the iteration's wall-clock time, from `openedAt`
to "done", and `MV` is `n/a`.
