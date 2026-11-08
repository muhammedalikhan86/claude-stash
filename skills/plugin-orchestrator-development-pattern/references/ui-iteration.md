# UI Iteration Mode

Read by `plugin-orchestrator-development-pattern` only when a UI Iteration is opened (Step 0.1d) or
resumed. It is a named exception to specific steps, not a parallel pipeline. Added 2026-11-03.

**Why it exists.** Small look-and-feel changes — a button's size, a gap, a colour, a label — come in a
run of prompts: change, look, change again. Running Phases 0 to 3 after every prompt is slow and costly.
So the gates are held back while the user iterates, and run **once**, over the whole change, when the
user says **"done"**.

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
2. **Run Step 0.0 lightly**: the hard dependencies must exist. Skip the Test Cases Doc check until "done".
3. **Detect Format and Lint** (Step 0.2) for this component. Skip the rest of Phase 0 until "done".
4. **Check the stack.** Run the Platform Profile's `Stack` check. If it is down, offer to bring it up, so
   the user sees each tweak live. Never run a production build while the stack is up.
5. **Write `run-state-file`** with `"mode": "ui-iteration"`, the component, `openedAt` (ISO date-time with
   the zone) and an empty `tweaks` list.
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
   component's files, or a shared library outside every root, say so and stop that tweak. It becomes a
   linked work item (see **Linked Runs** in `SKILL.md`), not part of this iteration.
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

**A long pause.** If the conversation ends mid-iteration, the run-state file carries the tweak log. On
resume, ask: "Found an open UI iteration on `<component>` with `<N>` tweaks — keep iterating, or call
done?"

## "done" — run the gates once

On "done", "I'm happy" or "that's it":

1. **Read back the tweak list** in one numbered block.
2. **Fix the file set.** Run `git status --porcelain`. The iteration's files are exactly those in the
   tweak log. Any other changed file belongs to another session and stays out of this item.
3. **Take the work-item ID.** If the user named an existing item, use it. Otherwise take the next
   `<COMPONENT>-F-NNN` from the PMBook: its "next ID" line wins, else the highest plus one. Type
   `Feature`, with the mode recorded as `UI Iteration`.
4. **Settle the design (the Design Gate, run once, after).** The user approved each tweak on the live
   screen, so here the artboard catches up with the code. This is the one case where the gate runs after
   the code.
   - Designer-owned artboards: never edit them. Write one designer ask listing every tweak, ready to
     paste, and tell the user it is owed.
   - Repo-owned artboards: spawn one agent to update the artboard to match the tweaks, and nothing else.
   - Either way, name the Material or CDK component behind each touched surface in the packet's
     `## Design Reference`.
5. **Bring stale assertions up to date.** Search the component's specs, E2E tests and business tests
   for each changed label, class or text. Update an assertion the tweaks made stale to the approved look,
   and list each one. A tweak needs no new test, because it adds no behaviour.
6. **Build one Task Packet** in the Feature shape (`references/templates.md`). Fill it like this:
   - `## Description`: "UI Iteration — <N> tweaks to <screen>".
   - `## Acceptance Criteria`: one checkable statement per tweak, in the order made.
   - `## Files to Create or Modify`: exactly the tweak log's files, plus any assertion files from 5.
7. **One Reviewer** (`orchestrated-reviewer`, `sonnet`) over the whole change. Add these to the Reviewer
   prompt:
   - "This change was made in UI Iteration mode: the Orchestrator edited the code directly, and the
     user approved each tweak on screen. Check every Acceptance Criterion in the diff."
   - "Check that nothing outside the tweak log changed."
   - "Check the UI contract: Material components and the styling order."
   - "Check that every updated assertion matches a tweak."
   - "Do not re-litigate the look itself."
8. **On a FAIL, the Orchestrator fixes the issues itself**, then respawns the Reviewer. `loop_count`
   counts as in Step 1.4, and at loop_count 3 the Reviewer is `opus`. Past 3, escalate. If a fix would
   change the look the user approved, ask the user first.
9. **Then the normal pipeline, once**: Phase 2 Integration (Step 2.0 decides the scope), Phase 3's four
   Finalizers, Step 3.5's commit and Step 3.6's close-out. Skip the Manual Verification Gate: the user
   already saw it live. The PMBook Finalizer adds the item's row already `Done`, with the tweak list as
   its criteria.

## Telemetry

One metrics row for the item: `Type: Feature (UI Iteration)`, Started = `openedAt`, Finished = the
Reviewer's PASS. Put the number of tweaks in the Verdict. The RUN row also gives the iteration's
wall-clock time, from `openedAt` to "done".
