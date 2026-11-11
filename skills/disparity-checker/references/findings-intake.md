# Findings Intake (the orchestrators' entry point for a findings file)

Read by `orchestrator-development-pattern` (Step 0.1d) and `plugin-orchestrator-development-pattern`
(Step 0.1e) when the user asks to fold in a findings file: "orchestrate the findings in <file>", "log
the disparity findings", "take the findings file". A findings file comes from `disparity-checker`, or
from a Board Parity Check's deferred minor gaps; both use `findings-format.md`. This file is the one
place the intake is described; the two skills differ only where it says **Plugin**.

Step numbers below are the orchestrator's own. Where the two differ: the commit step is plain Step 3.6,
plugin Step 3.5.

1. **Find the file.** The path the user gave; else the open files (`Status: open`) in
   `findings-directory` (plugin: this component's), listed for the user to pick. A `Status: consumed`
   file stops here: say by which run.
2. **Read it** per `findings-format.md`: the `## Findings` only. `Sifted` and `Unable to check` are
   shown in the plan, never logged.
3. **Re-sift against today's PMBook.** A finding an open Bug Log row or a `Planned`/`In Progress` item
   now covers is `planned: <ID>`. A finding whose screen has been rebuilt since the file's commit is
   still taken; say so on its line.
4. **Route each finding** by its `Suggested type`:
   - `Bug` → a Bug Log row: ID as Step 0.1b item 2 (the next free ID, skipping queue and
     `heldForNextRun`), sized per `~/.claude/skills/idea-triage/references/sizing.md`. Description:
     the title, then `<screen>, <state>, <width>: board <value>, built <value>`, the test case if any,
     `Severity: <s>` and `From: <findings file>`.
   - `Design-row question` → a `decisions.designRowsOwed` entry, written as Phase 3's **Design rows
     owed** says. No design folder → a Bug as above, its description ending `board may be wrong, needs
     a design ruling`.
   - `Test-case gap` → an `## Open Items` row (the next free `OI-NNN`): `add a test case for <screen>,
     <state>`.
   - **Plugin:** the row goes to the PMBook of the finding's `Component`, with that component's ID
     prefix (`<COMPONENT>-B-XXX`, `<COMPONENT>-OI-NNN`). Another component's findings are logged there
     and never fixed in this run, unless the user asks for **Linked Runs**
     (`~/.claude/skills/plugin-orchestrator-development-pattern/references/linked-runs.md`).
5. **Show the plan in one block and ask once.** One line per finding: title, severity, `→ <new ID>
   (<size> pts) in <PMBook>` or `→ design row` or `planned: <ID>`. The ask is the intake itself, so
   logging is settled: ask only **which of this component's Bugs to fix in this run** (none, all High,
   all, or a list).
6. **Run Steps 0.2 to 0.4** (Bug Fix Mode's one-line announcement; with none picked:
   `Findings Intake — <n> logged, none fixed`), so the run id and `run-state-file` exist. A mid-run
   intake already has both. Then save every route and the answer in run-state's
   `decisions.findingsIntake` (file, then per finding: route, ID, fix now yes/no) **before any write**; a
   resume reuses it and never asks again.
7. **Write the rows**, the Orchestrator itself, as it writes a raised known-red's Open Items row: each
   Bug Log row (Status `Open`, `Fixed In` blank), Open Items row and owed design row, each PMBook's path
   appended to run-state's `orchestratorFiles`. A Bug whose `Built by` names an item gets its `Mismatch`
   row per **Pipeline Telemetry** (`Mismatches reported after hand-over`; the event time is the intake's),
   except from a `-run-` file: those are minor gaps the run itself deferred, not misses after hand-over.
8. **Mark the file consumed:** `Status: consumed <yyyy-mm-dd> by run <run id>`, and each `Intake:` line
   (`logged as <ID>`, `design row <row ID>`, `planned: <ID>`). Change nothing else in it. Add it to
   `orchestratorFiles` so the commit step commits it with the rows.
9. **Then:**
   - **Bugs picked to fix** join the queue as Bug Fix Intake items (Step 0.1b from item 3 on, and its
     mid-run intake rule), reusing the row's ID and size. Phase 1 starts as in Bug Fix Mode.
   - **None picked:** no Phase 1 or 2 and no Finalizers. Show the diff of the written files and a
     draft commit (`docs(<component>): log disparity findings from <file>`); commit as the commit step
     does, push only on a go. Then the Close-out.
