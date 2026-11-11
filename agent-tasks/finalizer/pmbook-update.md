# Finalizer Task: PMBook Update

Read by `orchestrated-finalizer` when it is given this Task. Every rule in the agent file (Constraints,
Parallel-Safety, Git Restrictions, Output Template) still applies.

Given the Features Completed list and the PMBook path:
- Set each completed feature's Status to `Done`. This is the only place a feature becomes `Done` (the
  Orchestrator writes nothing to the PMBook before Integration has passed, except Step 0.1's Size cells), and it is written once. Take
  each item's final status from the prompt's `## Final Status per Item` section, never a guess from other
  docs, then fill the row's other fields (phase, provenance, Fixed In).
- Mark the current phase `Done` if every feature in it is now `Done`.
- Resolve any open items the completed features addressed.
- **Tranche-boundary check**: if marking this phase `Done` means *every* phase in the PMBook's Phases &
  Milestones table is now `Done`, do not archive or restructure anything yourself — that lifecycle
  belongs to the triage skill's Tranche Closeout (`idea-triage`, or `plugin-idea-triage` in a plugin
  repo). Record it plainly under Notes instead, so the Orchestrator can tell the user.
- **Bug Log**: for each item in the Bugs Fixed list, write a row to `## Bug Log`
  (`ID | Size | Description | Reported | Status | Fixed In`), creating the section after `## Feature Backlog`
  if it doesn't exist yet. If the bug already has a row (it was logged `Open` before it was fixed),
  update that row in place — never add a second one. Write the bug's given `Size` in the Size column; a
  table without one gets the column, `—` on rows already there that have no size. Write the bug's given `Regression test: <path>`
  into the row's Description, and its `Verified with: <measurements>` line, when given, word for word. A verified fixed bug's `Status` is `Fixed`, except a P0 fast-lane bug (see below). If
  the section keeps a "next ID" line, move it on past the highest ID now used. `Fixed In` is exactly the `Release label:` the prompt gives; never pick
  a version yourself.
- **Flaky tests**: for each test named in the Task-Specific Inputs' flaky-test list, add, or update the
  existing, `## Open Items` row — `Owner: unassigned | Item: Investigate flaky test <name>` — creating the section
  if needed.
- **Version Pointer Sweep**: only when your Task-Specific Inputs say this run bumped a `> Version:`
  header, carry out the sweep exactly as the orchestrator's prompt describes it (repointing
  `built against vN` header lines, and in a plugin repo the sideways sweep across other components).
  This Task owns it because it already owns the PMBook; no other parallel Finalizer touches those
  headers.
- **New ADR**: for each line handed to you as `<adr-directory>/ADR-<NNN>-<slug>.md — new file — …`,
  write that file. Copy the form of the folder's newest ADR (its headings, header lines and order) and
  fill it from the line's title, decision, context and status; use exactly the number and file name
  given — never pick, change or renumber one. If the folder has an index or README listing its ADRs,
  add the new one there in the same form. Never edit an existing ADR, except to set its status to
  `Superseded by ADR-<NNN>` when the line says `supersedes:` it. A number already taken, or no folder:
  write nothing and report it under Notes.
- **Deferred Integration — new P0 hotfix**: if your Task-Specific Inputs include a P0 Bug just fast-laned
  through its own Finalization, write its `## Bug Log` row with `Status: Hotfixed — Integration Pending`,
  and add, or update the existing, `## Deferred Integration` row (`Bug ID | Hotfixed On | Status: Pending`) that also
  carries its given `Regression test: <path>`, as it does in the Bug Log row. Create the `##
  Deferred Integration` section if it doesn't yet exist.
- **Deferred Integration — resolution**: if your Task-Specific Inputs include an Integration Agent Output
  that reports which Deferred Integration Bug IDs it actually re-validated, flip only those exact rows to
  `Status: Resolved`, and flip each of those bugs' `## Bug Log` rows from `Hotfixed — Integration
  Pending` to `Fixed` (in place). Never flip a row that isn't explicitly named in that list, even if it looks like it
  should logically also be fixed — a blanket resolution would let a hotfix whose changes silently regressed
  read as integration-confirmed when it wasn't actually re-checked.
